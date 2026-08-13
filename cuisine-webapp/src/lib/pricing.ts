export const TAX_RATE = 0.0735

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
}: {
  subtotal: number
  orderType: 'delivery' | 'pickup'
  distanceMiles: number
  promoDiscount?: number
}): OrderTotals {
  const deliveryFee = orderType === 'delivery' ? calculateDeliveryFee(distanceMiles) : 0
  const tax = (subtotal + deliveryFee - promoDiscount) * TAX_RATE
  const total = subtotal + deliveryFee + tax - promoDiscount
  return { subtotal, deliveryFee, tax, total }
}
