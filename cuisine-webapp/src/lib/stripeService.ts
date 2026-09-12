import { loadStripe } from '@stripe/stripe-js'
import { getAuthHeaders } from './authHeaders'

const stripePromise = loadStripe(process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!)

interface CreatePaymentIntentParams {
  items: { id: string; quantity: number }[]
  orderType: 'delivery' | 'pickup'
  deliveryAddress?: string
  scheduledFor?: string
  promoCode?: string
  currency?: string
  customerInfo?: { name: string; email: string; phone: string }
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
  currency = 'usd',
  customerInfo
}: CreatePaymentIntentParams) => {
  const response = await fetch('/api/create-payment-intent', {
    method: 'POST',
    // Authenticated now: the route records who the order is for, so the
    // Stripe webhook can create it if this browser never gets as far as
    // calling create-order. It also stops strangers minting payment intents
    // and live Uber quotes on the account.
    headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
    body: JSON.stringify({ items, orderType, deliveryAddress, scheduledFor, promoCode, currency, customerInfo })
  })

  const data = await response.json().catch(() => null)

  // fetch only rejects on a network failure, so a 409 (closed) or 422 (address
  // Uber won't quote) used to resolve with { error } and no clientSecret —
  // which left the checkout spinner running forever with nothing explaining it.
  if (!response.ok) {
    throw new Error(data?.error || 'Could not start payment. Please try again.')
  }
  if (!data?.clientSecret) {
    throw new Error('Payment could not be started. Please try again.')
  }
  return data as { clientSecret: string; total: number; deliveryFee?: number }
}

export { stripePromise }