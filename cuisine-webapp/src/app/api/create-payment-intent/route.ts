import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { supabase } from '@/lib/supabase'
import { computeOrderTotals } from '@/lib/pricing'
import { promotionsService } from '@/lib/promotionsService'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2025-12-15.clover'
})

interface CartItemInput {
  id: string
  quantity: number
}

export async function POST(request: NextRequest) {
  try {
    const {
      items,
      orderType,
      distanceMiles = 3,
      promoCode,
      currency = 'usd'
    }: {
      items: CartItemInput[]
      orderType: 'delivery' | 'pickup'
      distanceMiles?: number
      promoCode?: string
      currency?: string
    } = await request.json()

    if (!Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 })
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

    const { total } = computeOrderTotals({
      subtotal,
      orderType,
      distanceMiles,
      promoDiscount
    })

    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(total * 100),
      currency,
      automatic_payment_methods: {
        enabled: true
      }
    })

    return NextResponse.json({ clientSecret: paymentIntent.client_secret, total })
  } catch (error) {
    console.error('Error creating payment intent:', error)
    return NextResponse.json({ error: 'Payment failed' }, { status: 500 })
  }
}
