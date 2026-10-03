// Connecticut prepared-meals rate. Fallback only — the authoritative rate
// lives in settings/restaurant.taxRate and is applied server-side.
export const DEFAULT_TAX_RATE = 0.0735

const round2 = (n: number) => Math.round(n * 100) / 100

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
  // Tax applies to the food only — never the delivery fee — and to what the
  // customer actually pays for it. A discount the restaurant gives itself
  // reduces the taxable amount, so taxing the pre-discount subtotal charged
  // too much: 81 cents on a $54.97 order with the 20% opening discount.
  //
  // _shared/pricing.ts prices the mobile app and has no discounts of its
  // own; with no discount the two agree exactly.
  const taxable = Math.max(0, subtotal - promoDiscount)
  const tax = round2(taxable * taxRate)
  const total = round2(taxable + deliveryFee + tax)
  return { subtotal, deliveryFee, tax, total }
}
