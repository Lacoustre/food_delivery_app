import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'
import { verifyAuth } from '@/lib/verifyAuth'

/**
 * Refunds an order's Stripe payment.
 *
 * Before this existed, cancelling an order set a status and nothing else — the
 * customer was emailed "you will receive a refund shortly" and their card
 * stayed charged until somebody remembered to refund it by hand in Stripe.
 *
 * Admin only, and checked twice over. The Supabase client is scoped to the
 * caller's own token, so row-level security applies rather than this route
 * holding a service role key that bypasses every policy. But the orders policy
 * is `auth.uid() = user_id or is_admin()` — the owner half would let a
 * customer refund their own order — so the role is checked explicitly as well.
 */

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-12-15.clover'
})

export async function POST(request: NextRequest) {
  try {
    const caller = await verifyAuth(request)
    if (!caller) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { orderId, amount }: { orderId: string; amount?: number } =
      await request.json()

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
      // Same shape as the unauthenticated case on purpose: a customer probing
      // this endpoint learns nothing about whether the order exists.
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
    }

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('id, order_number, total, payment_method, payment_intent_id, refund_id, refund_amount')
      .eq('id', orderId)
      .maybeSingle()

    if (orderError || !order) {
      return NextResponse.json({ error: 'Order not found' }, { status: 404 })
    }

    if (order.refund_id) {
      // Already done. 409 rather than refunding again — a double click on
      // Cancel must not send the money twice.
      return NextResponse.json(
        {
          error: 'This order has already been refunded.',
          refundId: order.refund_id,
          refundAmount: order.refund_amount
        },
        { status: 409 }
      )
    }

    if (order.payment_method === 'cash') {
      return NextResponse.json(
        { error: 'This was a cash order — there is no payment to refund.' },
        { status: 400 }
      )
    }

    if (!order.payment_intent_id) {
      // Orders placed before payment_intent_id was recorded, or a card order
      // whose browser died before create-order ran.
      return NextResponse.json(
        {
          error:
            'No payment is linked to this order. Refund it from the Stripe dashboard, then cancel it here.'
        },
        { status: 422 }
      )
    }

    // Partial refunds are allowed, but never more than was charged.
    const charged = Number(order.total)
    const refundAmount = amount == null ? charged : Number(amount)
    if (!Number.isFinite(refundAmount) || refundAmount <= 0 || refundAmount > charged) {
      return NextResponse.json(
        { error: `Refund must be between $0.01 and $${charged.toFixed(2)}.` },
        { status: 400 }
      )
    }

    let refund
    try {
      refund = await stripe.refunds.create(
        {
          payment_intent: order.payment_intent_id,
          amount: Math.round(refundAmount * 100),
          metadata: { order_id: order.id, order_number: String(order.order_number) }
        },
        // Stripe will not create a second refund under the same key, so a
        // retry after a timeout cannot double-refund even before our row is set.
        { idempotencyKey: `refund_order_${order.id}` }
      )
    } catch (stripeError) {
      const message =
        stripeError instanceof Stripe.errors.StripeError
          ? stripeError.message
          : 'Stripe refused the refund.'
      console.error('Refund failed:', stripeError)
      return NextResponse.json({ error: message }, { status: 502 })
    }

    const { error: updateError } = await supabase
      .from('orders')
      .update({
        refund_id: refund.id,
        refund_amount: refundAmount,
        refunded_at: new Date().toISOString()
      })
      .eq('id', order.id)

    if (updateError) {
      // The money has already moved. Say so loudly rather than reporting a
      // failure the customer's bank statement will contradict.
      console.error(
        `Refund ${refund.id} succeeded but order ${order.id} was not updated:`,
        updateError
      )
      return NextResponse.json(
        {
          error:
            'The refund went through, but recording it failed. Do not retry — check the order in Stripe.',
          refundId: refund.id
        },
        { status: 500 }
      )
    }

    return NextResponse.json({
      success: true,
      refundId: refund.id,
      refundAmount,
      status: refund.status
    })
  } catch (error) {
    console.error('Refund route error:', error)
    return NextResponse.json({ error: 'Refund failed' }, { status: 500 })
  }
}
