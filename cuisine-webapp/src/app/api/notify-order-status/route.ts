import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { verifyAuth } from '@/lib/verifyAuth'
import { emailService, type OrderEmailData } from '@/lib/emailService'

/**
 * Emails a customer that their order has moved on.
 *
 * The admin panel used to show "Customer will be notified" on every status
 * change and send nothing at all. A customer got a confirmation when they
 * ordered and then silence — including when their pickup order was sitting
 * ready on the counter.
 *
 * This cannot reuse /api/send-email: that route refuses to send to anyone but
 * the caller's own address, which is the right guard for a customer-facing
 * endpoint and exactly wrong for an admin emailing someone else. So this route
 * is admin-only instead.
 *
 * Only an order id and status come from the caller. Everything in the email —
 * items, prices, totals, the customer's address — is read from the database,
 * so a compromised admin session cannot send a customer an invented order.
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

    // Scoped to the caller's token so RLS applies. The orders policy is
    // "owner or admin", so the role is checked explicitly too — the owner half
    // would otherwise let a customer trigger emails about their own order.
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

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select(`
        id, order_number, status, order_type, delivery_address,
        subtotal, delivery_fee, tax, total, user_id,
        order_items ( quantity, unit_price, name ),
        profiles!user_id ( name, email )
      `)
      .eq('id', orderId)
      .maybeSingle()

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    const customer = (order as unknown as {
      profiles?: { name?: string; email?: string }
    }).profiles

    if (!customer?.email) {
      // Nothing to fail loudly about: an order can exist without a reachable
      // email. Say so rather than pretending the customer was told.
      return NextResponse.json(
        { error: 'This customer has no email address on file.' },
        { status: 422 }
      )
    }

    const items = ((order as unknown as {
      order_items?: { quantity: number; unit_price: number; name?: string }[]
    }).order_items ?? []).map((i, idx) => ({
      id: String(idx),
      name: i.name ?? 'Item',
      quantity: i.quantity,
      price: Number(i.unit_price)
    }))

    const data: OrderEmailData = {
      customerEmail: customer.email,
      customerName: customer.name || 'there',
      orderNumber: String(order.order_number),
      orderType: order.order_type === 'delivery' ? 'delivery' : 'pickup',
      items,
      subtotal: Number(order.subtotal),
      deliveryFee: Number(order.delivery_fee),
      tax: Number(order.tax),
      total: Number(order.total),
      deliveryAddress: order.delivery_address ?? undefined,
      status: order.status
    }

    const result = await emailService.sendStatusUpdate(data)
    if (!result.success) {
      return NextResponse.json(
        { error: 'The status was saved but the email could not be sent.' },
        { status: 502 }
      )
    }

    return NextResponse.json({
      success: true,
      sentTo: customer.email,
      status: order.status
    })
  } catch (error) {
    console.error('notify-order-status error:', error)
    return NextResponse.json({ error: 'Could not notify the customer' }, { status: 500 })
  }
}
