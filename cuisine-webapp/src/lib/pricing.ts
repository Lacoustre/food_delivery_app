// Connecticut prepared-meals rate. Fallback only — the authoritative rate
// lives in settings/restaurant.taxRate and is applied server-side.
export const DEFAULT_TAX_RATE = 0.0735

/**
 * Tiered delivery fee, distance in miles. Single source of truth so the
 * server (payment intent creation) and client (checkout display) never
 * disagree on price.
 */
export function calculateDeliveryFee(distance: number = 3): number {
  const baseFee = 3.99
  const baseTierMaxDistance = 3.0
  const midTierMaxDistance = 10.0
  const midTierRatePerMile = 0.5
  const extendedTierBase = 7.49
  const extendedTierRatePerMile = 0.75

  if (distance <= baseTierMaxDistance) {
    return baseFee
  } else if (distance <= midTierMaxDistance) {
    return baseFee + (distance - baseTierMaxDistance) * midTierRatePerMile
  } else {
    return extendedTierBase + (distance - midTierMaxDistance) * extendedTierRatePerMile
  }
}

export interface OrderTotals {
  subtotal: number
  deliveryFee: number
  tax: number
  total: number
}

export function computeOrderTotals({
  subtotal,
  orderType,
  distanceMiles,
  promoDiscount = 0,
  taxRate = DEFAULT_TAX_RATE,
}: {
  subtotal: number
  orderType: 'delivery' | 'pickup'
  distanceMiles: number
  promoDiscount?: number
  taxRate?: number
}): OrderTotals {
  const deliveryFee = orderType === 'delivery' ? calculateDeliveryFee(distanceMiles) : 0
  // Tax applies to the food subtotal only — not the delivery fee, and not
  // reduced by the promo. Must match _shared/pricing.ts, which is what the
  // customer is actually charged.
  const tax = subtotal * taxRate
  const total = subtotal + deliveryFee + tax - promoDiscount
  return { subtotal, deliveryFee, tax, total }
}
