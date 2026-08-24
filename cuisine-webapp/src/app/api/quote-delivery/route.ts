import { NextRequest, NextResponse } from 'next/server'
import { getUberQuote } from '@/lib/uberDirect'

/**
 * Delivery fee for display at checkout, straight from Uber.
 *
 * Display only — create-payment-intent re-quotes before charging, so a
 * tampered response here cannot change what the customer actually pays.
 */
export async function POST(request: NextRequest) {
  try {
    const { deliveryAddress, scheduledFor, subtotal } = await request.json()

    if (typeof deliveryAddress !== 'string' || !deliveryAddress.trim()) {
      return NextResponse.json({ error: 'Delivery address is required' }, { status: 400 })
    }

    const quote = await getUberQuote({
      dropoffAddress: deliveryAddress.trim(),
      pickupReadyDt: typeof scheduledFor === 'string' ? scheduledFor : undefined,
      manifestTotalValue: typeof subtotal === 'number' ? Math.round(subtotal * 100) : undefined
    })

    return NextResponse.json({
      fee: quote.fee,
      currency: quote.currency,
      durationMinutes: quote.durationMinutes,
      quoteId: quote.quoteId
    })
  } catch (error) {
    // Uber declining is a real answer — out of range, or an address it can't
    // resolve. Surface it rather than inventing a fee.
    console.error('quote-delivery failed:', error)
    return NextResponse.json(
      { error: 'Delivery is not available to that address right now.' },
      { status: 422 }
    )
  }
}
