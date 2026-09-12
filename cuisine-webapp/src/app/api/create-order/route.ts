import { NextRequest, NextResponse, after } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { computeOrderTotals } from '@/lib/pricing'
import { getUberQuote } from '@/lib/uberDirect'
import { getOpenState, getScheduleStateAt } from '@/lib/hours'
import { promotionsService } from '@/lib/promotionsService'
import { verifyAuth } from '@/lib/verifyAuth'
import { createUberDelivery } from '@/lib/uberDirect'
import { pushOrderToClover } from '@/lib/clover'
import { emailService } from '@/lib/emailService'

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
      promoCode,
      customerInfo,
      deliveryAddress,
      deliveryTime,
      paymentMethod,
      paymentIntentId
    }: {
      items: CartItemInput[]
      orderType: 'delivery' | 'pickup'
      promoCode?: string
      customerInfo: { name: string; email: string; phone: string }
      deliveryAddress?: string
      deliveryTime?: string
      paymentMethod: 'card' | 'cash'
      paymentIntentId?: string
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
    // Deliveries go out with an Uber Direct courier, and couriers do not
    // collect cash. A cash delivery order would be cooked, dispatched and
    // handed over with nobody ever taking the money. Checkout hides the
    // option, but that is presentation — this is the check that holds.
    if (orderType === 'delivery' && paymentMethod === 'cash') {
      return NextResponse.json(
        { error: 'Delivery orders must be paid by card. Choose pickup to pay cash.' },
        { status: 400 }
      )
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

    // Persist delayed delivery-time choices so the dispatch-due-orders cron
    // can send them to Uber at the right time — previously "1hour" etc. was
    // only echoed back to the client and lost.
    const DELAY_HOURS: Record<string, number> = { '30mins': 0.5, '1hour': 1, '2hours': 2, '3hours': 3 }
    const delayHours = deliveryTime ? DELAY_HOURS[deliveryTime] : undefined
    const scheduledFor = delayHours
      ? new Date(Date.now() + delayHours * 3600_000).toISOString()
      : null

    // Closed means closed — the banner on the site is presentation, this holds.
    if (!scheduledFor) {
      const state = await getOpenState()
      if (!state.open) {
        return NextResponse.json(
          { error: state.reason || 'The restaurant is closed.' },
          { status: 409 }
        )
      }
    } else {
      // A scheduled order still has to land on a day and time the kitchen is
      // actually working. Booking ahead while shut is the feature; booking for
      // a Sunday, or for 10pm on a Saturday, is an order nobody will cook —
      // and it was being accepted and charged for.
      const state = await getScheduleStateAt(new Date(scheduledFor))
      if (!state.open) {
        return NextResponse.json(
          { error: state.reason || 'We are closed at that time.' },
          { status: 409 }
        )
      }
    }

    // Uber prices the delivery; quote it here so the stored order matches what
    // the payment intent charged.
    let deliveryFee = 0
    let uberQuoteId: string | null = null
    if (orderType === 'delivery') {
      if (!deliveryAddress) {
        return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
      }
      try {
        const quote = await getUberQuote({
          dropoffAddress: deliveryAddress,
          pickupReadyDt: scheduledFor ?? undefined,
          manifestTotalValue: Math.round(subtotal * 100)
        })
        deliveryFee = quote.fee
        uberQuoteId = quote.quoteId
      } catch (quoteError) {
        console.error('Uber quote failed:', quoteError)
        return NextResponse.json(
          { error: 'Check the address includes a street number, town and ZIP. We deliver up to about 10 miles from Vernon.' },
          { status: 422 }
        )
      }
    }

    const totals = computeOrderTotals({ subtotal, orderType, deliveryFee, promoDiscount })

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        user_id: decodedToken.uid,
        status: 'confirmed',
        order_type: orderType,
        payment_method: paymentMethod,
        // The handle on the Stripe charge. Without it stored here, nothing can
        // find the payment later to refund it. Cash orders have none.
        payment_intent_id: paymentMethod === 'card' ? (paymentIntentId ?? null) : null,
        delivery_address: orderType === 'delivery' ? deliveryAddress : null,
        scheduled_for: scheduledFor,
        subtotal: totals.subtotal,
        delivery_fee: totals.deliveryFee,
        uber_quote_id: uberQuoteId,
        tax: totals.tax,
        total: totals.total
      })
      .select()
      .single()

    if (orderError || !order) {
      console.error('Order insert failed:', orderError)
      return NextResponse.json({ error: 'Failed to create order' }, { status: 500 })
    }

    // Assigned by Postgres via order_number_seq, not by this route. Read it
    // back rather than generating one — a random number with no unique
    // constraint collided 39% of the time by the hundredth order.
    const orderNumber: string = order.order_number

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

    // The ticket has to say when the food is wanted. A scheduled order printed
    // the moment it is placed looks exactly like an ASAP one, so an order
    // booked for this afternoon could be cooked now and sit for hours.
    //
    // Written in the restaurant's own wall clock, not UTC, because that is the
    // clock the person reading the ticket is working to.
    const cloverNoteParts: string[] = []
    if (scheduledFor) {
      const when = new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/New_York',
        weekday: 'short',
        hour: 'numeric',
        minute: '2-digit'
      }).format(new Date(scheduledFor))
      cloverNoteParts.push(`SCHEDULED FOR ${when}`)
    }
    // Clover shows the order as open when it is unpaid, but the amount still
    // to collect is worth spelling out on the ticket.
    if (paymentMethod === 'cash') {
      cloverNoteParts.push(`COLLECT $${totals.total.toFixed(2)} CASH`)
    }
    const cloverNote = cloverNoteParts.length ? cloverNoteParts.join(' · ') : undefined

    // Dispatch ASAP delivery orders to Uber Direct. Delayed options
    // ("1hour"/"2hours"/"3hours") skip auto-dispatch — a courier shouldn't
    // arrive before the food is wanted; those are handled manually until
    // scheduled dispatch lands. A dispatch failure must not fail the order —
    // it's already created — so it's caught and logged instead.
    // Put the ticket in front of the kitchen. Never throws, and a failure is
    // logged rather than surfaced: the customer has paid and the order exists
    // in Supabase, so a POS that is down must not fail their checkout.
    // Tell the restaurant. The Clover ticket is the primary signal; this is
    // the one that still arrives when the POS is offline or the printer is
    // out of paper — which is how order #1006 came in with nobody notified.
    //
    // The address comes from the settings row so it can be changed from the
    // admin panel without a deploy.
    after((async () => {
      try {
        const { data: settingsRow } = await supabase
          .from('settings')
          .select('value')
          .eq('key', 'restaurant')
          .maybeSingle()

        const to = settingsRow?.value?.email || process.env.RESTAURANT_ALERT_EMAIL
        if (!to) {
          console.error(`No restaurant address configured — order #${orderNumber} not announced`)
          return
        }

        const result = await emailService.sendNewOrderAlert(
          {
            customerEmail: customerInfo?.email ?? '',
            customerName: customerInfo?.name || 'Customer',
            customerPhone: customerInfo?.phone ?? undefined,
            orderNumber,
            orderType,
            items: validatedItems.map(i => ({
              id: i.id,
              name: i.name,
              quantity: i.quantity,
              price: i.price
            })),
            subtotal: totals.subtotal,
            deliveryFee: totals.deliveryFee,
            tax: totals.tax,
            total: totals.total,
            deliveryAddress: orderType === 'delivery' ? deliveryAddress ?? undefined : undefined,
            status: 'confirmed',
            scheduledFor,
            paymentMethod
          },
          to
        )
        if (!result.success) {
          console.error(`Restaurant alert failed for order #${orderNumber}`)
        }
      } catch (err) {
        // Never fail an order over a notification.
        console.error(`Restaurant alert threw for order #${orderNumber}:`, err)
      }
    })())

    // after() keeps the function alive until this finishes. Previously this
    // was fire-and-forget, and the platform froze the instance the moment the
    // response was returned — so the push died partway through. Order #1006
    // reached Clover with one of its four dishes, no total and no payment,
    // because the remaining requests were never allowed to run.
    after(pushOrderToClover({
      orderNumber,
      orderType,
      items: validatedItems.map(i => ({
        name: i.name,
        quantity: i.quantity,
        unitPrice: i.price
      })),
      total: totals.total,
      paid: paymentMethod === 'card',
      customerName: customerInfo?.name,
      customerPhone: customerInfo?.phone,
      deliveryAddress: orderType === 'delivery' ? deliveryAddress : undefined,
      note: cloverNote
    }).then(result => {
      if (!result.ok) {
        console.error(`Clover push failed for order ${orderNumber}: ${result.error}`)
      } else if (result.error) {
        console.error(`Clover order ${result.cloverOrderId}: ${result.error}`)
      } else {
        console.log(
          `Clover order ${result.cloverOrderId} created for #${orderNumber}: ` +
          `${result.matchedItems}/${result.totalItems} items matched to inventory`
        )
      }
    }))

    let uberTrackingUrl: string | null = null
    if (orderType === 'delivery' && (!deliveryTime || deliveryTime === 'asap')) {
      try {
        const uber = await createUberDelivery({
          orderNumber,
          dropoffAddress: deliveryAddress!,
          dropoffName: customerInfo?.name || 'Customer',
          dropoffPhone: customerInfo?.phone || null,
          items: validatedItems.map(i => ({ name: i.name, quantity: i.quantity }))
        })

        uberTrackingUrl = uber.trackingUrl
        const { error: uberUpdateError } = await supabase
          .from('orders')
          .update({
            delivery_provider: 'uber_direct',
            uber_delivery_id: uber.deliveryId,
            uber_tracking_url: uber.trackingUrl,
            uber_delivery_status: uber.status,
            uber_fee: uber.fee
          })
          .eq('id', order.id)
        if (uberUpdateError) {
          console.error(`Uber dispatch record failed for order ${order.id}:`, uberUpdateError)
        }
      } catch (uberError) {
        console.error(`Uber dispatch failed for order ${order.id}:`, uberError)
      }
    }

    return NextResponse.json({
      orderId: order.id,
      orderNumber,
      items: validatedItems,
      customerInfo,
      deliveryTime,
      uberTrackingUrl,
      ...totals
    })
  } catch (error) {
    console.error('Error creating order:', error)
    return NextResponse.json({ error: 'Failed to create order' }, { status: 500 })
  }
}
