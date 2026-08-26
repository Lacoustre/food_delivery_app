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
    // Uber returns address_undeliverable for both an address it cannot resolve
    // and one that is genuinely out of range, so the message has to cover both.
    console.error('quote-delivery failed:', error)
    return NextResponse.json(
      { error: 'Check the address includes a street number, town and ZIP. We deliver up to about 10 miles from Vernon.' },
      { status: 422 }
    )
  }
}
