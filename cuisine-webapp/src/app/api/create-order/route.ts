import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { computeOrderTotals } from '@/lib/pricing'
import { promotionsService } from '@/lib/promotionsService'
import { verifyAuth } from '@/lib/verifyAuth'

interface CartItemInput {
  id: string
  quantity: number
}

export async function POST(request: NextRequest) {
  try {
    const decodedToken = await verifyAuth(request)
    if (!decodedToken) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const {
      items,
      orderType,
      distanceMiles = 3,
      promoCode,
      customerInfo,
      deliveryAddress,
      deliveryTime,
      paymentMethod
    }: {
      items: CartItemInput[]
      orderType: 'delivery' | 'pickup'
      distanceMiles?: number
      promoCode?: string
      customerInfo: { name: string; email: string; phone: string }
      deliveryAddress?: string
      deliveryTime?: string
      paymentMethod: 'card' | 'cash'
    } = await request.json()

    if (!Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ error: 'Cart is empty' }, { status: 400 })
    }
    if (orderType !== 'delivery' && orderType !== 'pickup') {
      return NextResponse.json({ error: 'Invalid order type' }, { status: 400 })
    }
    if (paymentMethod !== 'card' && paymentMethod !== 'cash') {
      return NextResponse.json({ error: 'Invalid payment method' }, { status: 400 })
    }

    // Scope this client to the caller's own access token so Postgres RLS
    // (orders_owner_insert: auth.uid() = user_id) applies for real — this
    // is what actually enforces ownership, not application code.
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      { global: { headers: { Authorization: request.headers.get('authorization')! } } }
    )

    // Never trust client-supplied item names/prices — same authoritative
    // lookup used for the payment intent, so the order that gets fulfilled
    // always matches what was actually (or will be) charged.
    let subtotal = 0
    const validatedItems: { id: string; name: string; price: number; quantity: number }[] = []
    for (const item of items) {
      if (!item.id || !Number.isInteger(item.quantity) || item.quantity <= 0) {
        return NextResponse.json({ error: 'Invalid cart item' }, { status: 400 })
      }

      const { data: meal, error: mealError } = await supabase
        .from('meals')
        .select('name, price, active, available')
        .eq('id', item.id)
        .single()
      if (mealError || !meal) {
        return NextResponse.json({ error: `Meal not found: ${item.id}` }, { status: 400 })
      }
      if (!meal.active || !meal.available) {
        return NextResponse.json({ error: `Meal unavailable: ${item.id}` }, { status: 400 })
      }

      subtotal += meal.price * item.quantity
      validatedItems.push({ id: item.id, name: meal.name, price: meal.price, quantity: item.quantity })
    }

    let promoDiscount = 0
    if (promoCode) {
      const promoResult = await promotionsService.validatePromoCode(promoCode, subtotal)
      if (!promoResult.valid) {
        return NextResponse.json({ error: promoResult.error || 'Invalid promo code' }, { status: 400 })
      }
      promoDiscount = promoResult.discount || 0
    }

    const totals = computeOrderTotals({ subtotal, orderType, distanceMiles, promoDiscount })
    const orderNumber = String(Math.floor(Math.random() * 10000) + 1000)

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        user_id: decodedToken.uid,
        status: 'confirmed',
        order_number: orderNumber,
        order_type: orderType,
        payment_method: paymentMethod,
        delivery_address: orderType === 'delivery' ? deliveryAddress : null,
        subtotal: totals.subtotal,
        delivery_fee: totals.deliveryFee,
        tax: totals.tax,
        total: totals.total
      })
      .select()
      .single()

    if (orderError || !order) {
      console.error('Order insert failed:', orderError)
      return NextResponse.json({ error: 'Failed to create order' }, { status: 500 })
    }

    const { error: itemsError } = await supabase.from('order_items').insert(
      validatedItems.map(item => ({
        order_id: order.id,
        meal_id: item.id,
        name: item.name,
        quantity: item.quantity,
        unit_price: item.price
      }))
    )

    if (itemsError) {
      console.error('Order items insert failed:', itemsError)
      return NextResponse.json({ error: 'Failed to create order' }, { status: 500 })
    }

    return NextResponse.json({
      orderId: order.id,
      orderNumber,
      items: validatedItems,
      customerInfo,
      deliveryTime,
      ...totals
    })
  } catch (error) {
    console.error('Error creating order:', error)
    return NextResponse.json({ error: 'Failed to create order' }, { status: 500 })
  }
}
