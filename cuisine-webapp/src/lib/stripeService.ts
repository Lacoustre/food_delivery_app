import { loadStripe } from '@stripe/stripe-js'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

interface CreatePaymentIntentParams {
  items: { id: string; quantity: number }[]
  orderType: 'delivery' | 'pickup'
  deliveryAddress?: string
  scheduledFor?: string
  promoCode?: string
  currency?: string
}

// The server recomputes the charge amount from authoritative meal prices
// and re-validates the promo code itself — it never trusts a dollar amount
// or discount value from the client. This just describes what is in the
// cart; the returned `total` is the number actually charged.
export const createPaymentIntent = async ({
  items,
  orderType,
  deliveryAddress,
  scheduledFor,
  promoCode,
  currency = 'usd'
}: CreatePaymentIntentParams) => {
  const response = await fetch('/api/create-payment-intent', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ items, orderType, deliveryAddress, scheduledFor, promoCode, currency })
  })
  return response.json()
}

export { stripePromise }