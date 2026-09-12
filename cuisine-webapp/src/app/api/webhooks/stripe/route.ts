import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import Stripe from 'stripe'
import { pushOrderToClover } from '@/lib/clover'

/**
 * Creates the order when the browser could not.
 *
 * Checkout confirms the card and then calls /api/create-order. If the browser
 * dies in between — closed tab, dead battery, tunnel — the customer is charged
 * and no order exists. The kitchen never sees it, nobody is told, and the
 * first anyone hears is a chargeback.
 *
 * This is a backstop, not the main path. It only acts when no order already
 * carries the PaymentIntent, so a browser that finished the job wins and this
 * does nothing.
 *
 * Everything it writes comes from pending_orders, recorded by
 * create-payment-intent after the server priced the items, validated the promo
 * and quoted Uber. Nothing here is derived from the client.
 */

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-12-15.clover'
})

// A webhook has no user session at all, so RLS cannot apply.
function adminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  )
}

export async function POST(request: NextRequest) {
  const signature = request.headers.get('stripe-signature')
  const secret = process.env.STRIPE_WEBHOOK_SECRET

  if (!secret) {
    console.error('STRIPE_WEBHOOK_SECRET is not set — refusing to trust this request')
    return NextResponse.json({ error: 'Webhook not configured' }, { status: 500 })
  }
  if (!signature) {
    return NextResponse.json({ error: 'Missing signature' }, { status: 400 })
  }

  // The raw body is required: Stripe signs the exact bytes, so parsing first
  // and re-serialising would never verify.
  const raw = await request.text()

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(raw, signature, secret)
  } catch (err) {
    // Anyone can POST here. Without a valid signature this is not Stripe.
    console.error('Webhook signature verification failed:', err)
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  if (event.type !== 'payment_intent.succeeded') {
    // Acknowledge everything else so Stripe stops retrying it.
    return NextResponse.json({ received: true, ignored: event.type })
  }

  const intent = event.data.object as Stripe.PaymentIntent

  try {
    const supabase = adminClient()

    // Did the browser already do it? This is the normal case.
    const { data: existing } = await supabase
      .from('orders')
      .select('id, order_number')
      .eq('payment_intent_id', intent.id)
      .maybeSingle()

    if (existing) {
      return NextResponse.json({
        received: true,
        action: 'none',
        reason: 'order already exists',
        orderNumber: existing.order_number
      })
    }

    const { data: pending } = await supabase
      .from('pending_orders')
      .select('user_id, payload')
      .eq('payment_intent_id', intent.id)
      .maybeSingle()

    if (!pending) {
      // Charged, no order, and nothing to rebuild it from. Loud, because this
      // is money taken for food nobody knows about.
      console.error(
        `ORPHANED PAYMENT ${intent.id}: charged ${intent.amount / 100} with no order and no pending record`
      )
      return NextResponse.json(
        { received: true, action: 'none', reason: 'no pending order found' },
        { status: 200 }
      )
    }

    const p = pending.payload as {
      items: { id: string; quantity: number }[]
      orderType: 'delivery' | 'pickup'
      deliveryAddress: string | null
      scheduledFor: string | null
      subtotal: number
      deliveryFee: number
      promoDiscount: number
      total: number
      uberQuoteId: string | null
      customerInfo: { name?: string; email?: string; phone?: string } | null
    }

    // The payment intent is created before the customer finishes typing their
    // details, so what was captured may be blank. The profile is the better
    // source anyway — it is what they registered with.
    const { data: profile } = await supabase
      .from('profiles')
      .select('name, email, phone')
      .eq('id', pending.user_id)
      .maybeSingle()

    const tax = Number((p.total - p.subtotal - p.deliveryFee + p.promoDiscount).toFixed(2))

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        user_id: pending.user_id,
        status: 'confirmed',
        order_type: p.orderType,
        payment_method: 'card',
        payment_intent_id: intent.id,
        delivery_address: p.deliveryAddress,
        scheduled_for: p.scheduledFor,
        subtotal: p.subtotal,
        delivery_fee: p.deliveryFee,
        uber_quote_id: p.uberQuoteId,
        tax,
        total: p.total
      })
      .select()
      .single()

    if (orderError || !order) {
      // 23505: the browser's create-order got there between our check above and
      // this insert. That is the normal path winning the race, which is the
      // outcome we want — acknowledge it so Stripe stops retrying. The check
      // above cannot prevent this on its own; the unique index added in
      // migration 64 is what actually makes one payment mean one order.
      if (orderError?.code === '23505') {
        console.log(`Webhook lost the race for ${intent.id}; the browser had already created the order`)
        return NextResponse.json({ received: true, action: 'none', reason: 'created by the browser first' })
      }

      console.error(`Webhook could not create order for ${intent.id}:`, orderError)
      // 500 so Stripe retries — better than losing it silently.
      return NextResponse.json({ error: 'Order creation failed' }, { status: 500 })
    }

    // Line items, priced from the meals table rather than the payload, so the
    // order history shows what the kitchen should make.
    const { data: meals } = await supabase
      .from('meals')
      .select('id, name, price')
      .in('id', p.items.map(i => i.id))

    if (meals?.length) {
      const byId = new Map(meals.map(m => [m.id, m]))
      // Columns are unit_price and name, matching create-order. An earlier
      // version wrote `price`, which does not exist — it failed silently and
      // left the order with no line items at all.
      const { error: itemsError } = await supabase.from('order_items').insert(
        p.items
          .filter(i => byId.has(i.id))
          .map(i => ({
            order_id: order.id,
            meal_id: i.id,
            name: byId.get(i.id)!.name,
            quantity: i.quantity,
            unit_price: byId.get(i.id)!.price
          }))
      )
      if (itemsError) {
        // The order exists and the customer has paid; losing the lines means
        // the kitchen sees an order with nothing in it.
        console.error(
          `Webhook created order ${order.order_number} but its items failed:`,
          itemsError
        )
      }
    }

    // A rescued order still needs to reach the kitchen — arguably more so,
    // since nobody was watching a browser when it came in.
    if (meals?.length) {
      const byId = new Map(meals.map(m => [m.id, m]))
      const result = await pushOrderToClover({
        orderNumber: String(order.order_number),
        orderType: p.orderType,
        items: p.items
          .filter(i => byId.has(i.id))
          .map(i => ({
            name: byId.get(i.id)!.name,
            quantity: i.quantity,
            unitPrice: byId.get(i.id)!.price
          })),
        total: p.total,
        paid: true,
        customerName: profile?.name ?? p.customerInfo?.name ?? undefined,
        customerPhone: profile?.phone ?? p.customerInfo?.phone ?? undefined,
        deliveryAddress: p.deliveryAddress ?? undefined,
        note: 'Recovered by webhook'
      })
      if (!result.ok) {
        console.error(`Clover push failed for rescued order ${order.order_number}: ${result.error}`)
      }
    }

    await supabase.from('pending_orders').delete().eq('payment_intent_id', intent.id)

    console.warn(
      `Webhook rescued order ${order.order_number} for ${intent.id} — the browser never called create-order`
    )

    return NextResponse.json({
      received: true,
      action: 'created',
      orderNumber: order.order_number,
      customer: profile?.email ?? p.customerInfo?.email ?? null
    })
  } catch (err) {
    console.error('Stripe webhook error:', err)
    return NextResponse.json({ error: 'Webhook handler failed' }, { status: 500 })
  }
}
