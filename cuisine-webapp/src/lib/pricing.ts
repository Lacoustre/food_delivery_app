// Connecticut prepared-meals rate. Fallback only — the authoritative rate
// lives in settings/restaurant.taxRate and is applied server-side.
export const DEFAULT_TAX_RATE = 0.0735

export interface OrderTotals {
  subtotal: number
  deliveryFee: number
  tax: number
  total: number
}

/**
 * Delivery is priced by Uber, not by us — pass the quoted fee in. Pickup
 * ignores it. Must stay in step with supabase/functions/_shared/pricing.ts,
 * which prices the mobile app the same way.
 */
export function computeOrderTotals({
  subtotal,
  orderType,
  deliveryFee: quotedDeliveryFee = 0,
  promoDiscount = 0,
  taxRate = DEFAULT_TAX_RATE,
}: {
  subtotal: number
  orderType: 'delivery' | 'pickup'
  deliveryFee?: number
  promoDiscount?: number
  taxRate?: number
}): OrderTotals {
  const deliveryFee = orderType === 'delivery' ? quotedDeliveryFee : 0
  // Tax applies to the food subtotal only — not the delivery fee, and not
  // reduced by the promo. Must match _shared/pricing.ts, which is what the
  // customer is actually charged.
  const tax = subtotal * taxRate
  const total = subtotal + deliveryFee + tax - promoDiscount
  return { subtotal, deliveryFee, tax, total }
}
