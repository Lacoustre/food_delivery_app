import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { verifyAuth } from '@/lib/verifyAuth'
import { createUberDelivery } from '@/lib/uberDirect'

/**
 * Sends a courier, once the food is actually ready.
 *
 * Checkout used to dispatch Uber the moment the customer paid. On order #1008
 * the courier arrived while the kitchen was still cooking, and the delivery
 * had to be cancelled and the fee refunded. A driver should be called when
 * there is something to collect, which only the restaurant knows.
 *
 * Admin only, checked the same way as the refund route: the Supabase client is
 * scoped to the caller's token so RLS applies, and the role is checked
 * explicitly because the orders policy is "owner or admin" and the owner half
 * would let a customer summon their own courier.
 */
export async function POST(request: NextRequest) {
  try {
    const caller = await verifyAuth(request)
    if (!caller) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { orderId }: { orderId: string } = await request.json()
    if (!orderId) {
      return NextResponse.json({ error: 'orderId is required' }, { status: 400 })
    }

    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: request.headers.get('authorization')! } } }
    )

    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', caller.uid)
      .maybeSingle()

    if (profile?.role !== 'admin') {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    // Cast through unknown: the select is assembled by concatenation, so
    // supabase-js cannot infer the row shape from the string literal.
    const { data: orderRow, error: orderError } = await supabase
      .from('orders')
      .select(
        'id, order_number, order_type, delivery_address, uber_delivery_id, ' +
        'order_items(name, quantity), profiles!user_id(name, phone)'
      )
      .eq('id', orderId)
      .maybeSingle()

    const order = orderRow as unknown as {
      id: string
      order_number: string | null
      order_type: 'delivery' | 'pickup' | null
      delivery_address: string | null
      uber_delivery_id: string | null
      order_items: { name: string | null; quantity: number }[] | null
      profiles: { name?: string; phone?: string } | { name?: string; phone?: string }[] | null
    } | null

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    if (order.order_type !== 'delivery') {
      return NextResponse.json(
        { ok: true, dispatched: false, reason: 'this is a pickup order' }
      )
    }

    // Already sent. Not an error — marking an order ready twice must not put
    // two couriers on the same food.
    if (order.uber_delivery_id) {
      return NextResponse.json({
        ok: true,
        dispatched: false,
        reason: 'a courier is already on this order',
        deliveryId: order.uber_delivery_id
      })
    }

    if (!order.delivery_address) {
      return NextResponse.json(
        { error: 'This order has no delivery address.' },
        { status: 422 }
      )
    }

    const customer = Array.isArray(order.profiles) ? order.profiles[0] : order.profiles

    try {
      const uber = await createUberDelivery({
        orderNumber: String(order.order_number),
        dropoffAddress: order.delivery_address,
        dropoffName: customer?.name || 'Customer',
        dropoffPhone: customer?.phone || null,
        items: (order.order_items ?? []).map(i => ({
          name: i.name ?? 'Item',
          quantity: i.quantity
        }))
      })

      const { error: updateError } = await supabase
        .from('orders')
        .update({
          delivery_provider: 'uber_direct',
          uber_delivery_id: uber.deliveryId,
          uber_tracking_url: uber.trackingUrl,
          uber_delivery_status: uber.status,
          uber_fee: uber.fee
        })
        .eq('id', order.id)

      if (updateError) {
        // The courier is coming either way. Say so loudly rather than letting
        // the panel report a failure that would tempt someone to dispatch a
        // second one.
        console.error(`Courier dispatched for ${order.id} but not recorded:`, updateError)
      }

      return NextResponse.json({
        ok: true,
        dispatched: true,
        trackingUrl: uber.trackingUrl,
        fee: uber.fee
      })
    } catch (uberError) {
      const message = uberError instanceof Error ? uberError.message : 'Uber refused the delivery'
      console.error(`Uber dispatch failed for order ${order.id}:`, uberError)
      return NextResponse.json({ error: message }, { status: 502 })
    }
  } catch (error) {
    console.error('Dispatch route failed:', error)
    return NextResponse.json({ error: 'Failed to dispatch a courier' }, { status: 500 })
  }
}
