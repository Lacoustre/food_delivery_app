import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { verifyAuth } from '@/lib/verifyAuth'
import { cancelCloverOrder } from '@/lib/clover'

/**
 * Removes a cancelled order's ticket from the POS.
 *
 * Cancelling in the admin panel used to set a status and issue the refund, but
 * told Clover nothing — so the kitchen ticket stayed open and staff could cook
 * food for an order that no longer existed.
 *
 * Admin only, checked the same way as the refund route: the Supabase client is
 * scoped to the caller's own token so RLS applies, and the role is checked
 * explicitly because the orders policy is "owner or admin" and the owner half
 * would otherwise let a customer cancel their own ticket off the POS.
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

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, order_number, clover_order_id')
      .eq('id', orderId)
      .maybeSingle()

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    // Nothing to do: the push failed, Clover is not configured, or the order
    // predates the id being recorded. Not an error — the caller only wants the
    // ticket gone, and there is no ticket.
    if (!order.clover_order_id) {
      return NextResponse.json({ ok: true, cleared: false, reason: 'no Clover ticket recorded' })
    }

    const result = await cancelCloverOrder(order.clover_order_id)

    if (!result.ok) {
      // 409 rather than 500 for the paid case: nothing is broken, a human just
      // has to void it on the terminal. The admin panel says so.
      return NextResponse.json(
        {
          error: result.error ?? 'Could not cancel the Clover ticket',
          needsManualVoid: result.needsManualVoid ?? false,
          cloverOrderId: order.clover_order_id
        },
        { status: result.needsManualVoid ? 409 : 502 }
      )
    }

    // Cleared, so a later cancel does not try again against a dead id.
    await supabase
      .from('orders')
      .update({ clover_order_id: null })
      .eq('id', order.id)

    return NextResponse.json({ ok: true, cleared: true })
  } catch (error) {
    console.error('Clover cancel route failed:', error)
    return NextResponse.json({ error: 'Failed to cancel the Clover ticket' }, { status: 500 })
  }
}
