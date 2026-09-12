import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { verifyAuth } from '@/lib/verifyAuth'
import Stripe from 'stripe'
import { supabase } from '@/lib/supabase'
import { computeOrderTotals } from '@/lib/pricing'
import { promotionsService } from '@/lib/promotionsService'
import { getUberQuote } from '@/lib/uberDirect'
import { getOpenState } from '@/lib/hours'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-12-15.clover'
})

interface CartItemInput {
  id: string
  quantity: number
}

export async function POST(request: NextRequest) {
  try {
    // Authenticated now. The route records who the order is for so the Stripe
    // webhook can create it if the browser never calls create-order — and an
    // open endpoint let anyone mint payment intents and live Uber quotes.
    const caller = await verifyAuth(request)
    if (!caller) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const {
      items,
      orderType,
      deliveryAddress,
      scheduledFor,
      promoCode,
      currency = 'usd',
      customerInfo,
      // The intent this checkout already prepared, if any, so a changed total
      // reprices it rather than abandoning it and making another.
      existingIntentId
    }: {
      items: CartItemInput[]
      orderType: 'delivery' | 'pickup'
      deliveryAddress?: string
      scheduledFor?: string
      promoCode?: string
      currency?: string
      customerInfo?: { name?: string; email?: string; phone?: string }
      existingIntentId?: string
    } = await request.json()

    if (!Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 })
    }

    // Refuse before taking money. Scheduled orders are exempt.
    if (!scheduledFor) {
      const state = await getOpenState()
      if (!state.open) {
        return NextResponse.json(
          { error: state.reason || 'The restaurant is closed.' },
          { status: 409 }
        )
      }
    }
    if (orderType !== 'delivery' && orderType !== 'pickup') {
      return NextResponse.json({ error: 'Invalid order type' }, { status: 400 })
    }

    // Never trust a client-supplied price. Look up each item's authoritative
    // price from Supabase and recompute the subtotal server-side — this is
    // what actually gets charged, regardless of what the client displayed.
    let subtotal = 0
    for (const item of items) {
      if (!item.id || !Number.isInteger(item.quantity) || item.quantity <= 0) {
        return NextResponse.json({ error: 'Invalid cart item' }, { status: 400 })
      }

      const { data: meal, error: mealError } = await supabase
        .from('meals')
        .select('price, active, available')
        .eq('id', item.id)
        .single()
      if (mealError || !meal) {
        return NextResponse.json({ error: `Meal not found: ${item.id}` }, { status: 400 })
      }
      if (!meal.active || !meal.available) {
        return NextResponse.json({ error: `Meal unavailable: ${item.id}` }, { status: 400 })
      }

      subtotal += meal.price * item.quantity
    }

    // Never trust a client-supplied discount either — validate the promo
    // code server-side and derive the real discount from it.
    let promoDiscount = 0
    if (promoCode) {
      const promoResult = await promotionsService.validatePromoCode(promoCode, subtotal)
      if (!promoResult.valid) {
        return NextResponse.json({ error: promoResult.error || 'Invalid promo code' }, { status: 400 })
      }
      promoDiscount = promoResult.discount || 0
    }

    // Delivery is priced by Uber. Re-quote here rather than trusting whatever
    // the checkout page displayed — and never fall back to an estimate, since
    // a guessed fee is charged as if it were real.
    let deliveryFee = 0
    // Kept for pending_orders: the webhook reuses this quote rather than
    // re-quoting, which would return a different fee minutes later.
    let uberQuoteId: string | null = null
    if (orderType === 'delivery') {
      if (!deliveryAddress) {
        return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
      }
      try {
        const quote = await getUberQuote({
          dropoffAddress: deliveryAddress,
          pickupReadyDt: scheduledFor,
          manifestTotalValue: Math.round(subtotal * 100)
        })
        deliveryFee = quote.fee
        uberQuoteId = quote.quoteId ?? null
      } catch (quoteError) {
        console.error('Uber quote failed:', quoteError)
        return NextResponse.json(
          { error: 'Check the address includes a street number, town and ZIP. We deliver up to about 10 miles from Vernon.' },
          { status: 422 }
        )
      }
    }

    const { total } = computeOrderTotals({
      subtotal,
      orderType,
      deliveryFee,
      promoDiscount
    })

    // Reuse the intent this checkout already has, if it has one.
    //
    // The client prepares a payment whenever the total, address or order type
    // changes — a delivery quote arriving is enough. Creating a fresh intent
    // each time left nine abandoned shells in Stripe for a single order, and a
    // pending_orders row behind each of them. Stripe lets an unconfirmed
    // intent be repriced, which is all that is actually needed.
    let paymentIntent: Stripe.PaymentIntent | null = null

    if (existingIntentId) {
      try {
        const existing = await stripe.paymentIntents.retrieve(existingIntentId)
        const reusable =
          existing.status === 'requires_payment_method' ||
          existing.status === 'requires_confirmation'

        // Only this customer's own intent, so a guessed id cannot be repriced.
        if (reusable && existing.metadata?.supabase_user_id === caller.uid) {
          paymentIntent = await stripe.paymentIntents.update(existing.id, {
            amount: Math.round(total * 100),
            metadata: { supabase_user_id: caller.uid }
          })
        }
      } catch {
        // Gone, or never ours. Fall through and make a new one.
      }
    }

    if (!paymentIntent) {
      paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(total * 100),
        currency,
        automatic_payment_methods: {
          enabled: true
        },
        metadata: { supabase_user_id: caller.uid }
      })
    }

    // Record what this order would be, keyed by the intent. If the browser
    // dies between confirming the card and calling create-order, the Stripe
    // webhook builds the order from this instead of the customer being
    // charged for nothing. Everything stored here is already server-validated
    // — prices looked up, promo checked, Uber quoted — so the webhook trusts
    // it without re-deriving anything from the client.
    try {
      const admin = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
        { auth: { persistSession: false } }
      )
      await admin.from('pending_orders').upsert({
        payment_intent_id: paymentIntent.id,
        user_id: caller.uid,
        payload: {
          items: items.map(i => ({ id: i.id, quantity: i.quantity })),
          orderType,
          deliveryAddress: orderType === 'delivery' ? deliveryAddress : null,
          scheduledFor: scheduledFor ?? null,
          promoCode: promoCode ?? null,
          customerInfo: customerInfo ?? null,
          subtotal,
          deliveryFee,
          promoDiscount,
          total,
          uberQuoteId: uberQuoteId ?? null
        }
      }, { onConflict: 'payment_intent_id' })
    } catch (pendingError) {
      // Losing the backstop must not stop the customer paying. It only means
      // this one order depends on the browser finishing the job, which is what
      // happened for every order before this existed.
      console.error('pending_orders write failed:', pendingError)
    }

    // Return the quoted fee so checkout can reconcile its display with what
    // is actually being charged.
    return NextResponse.json({
      clientSecret: paymentIntent.client_secret,
      // So the next call for this checkout reprices this intent rather than
      // abandoning it and creating another.
      paymentIntentId: paymentIntent.id,
      total,
      deliveryFee
    })
  } catch (error) {
    console.error('Error creating payment intent:', error)
    return NextResponse.json({ error: 'Payment failed' }, { status: 500 })
  }
}
