/**
 * What a customer actually paid, once refunds are taken off.
 *
 * Every revenue figure in this panel summed `total`, so a refunded order still
 * counted at its full price: order #1008 read $63.79 after $7.99 had been
 * given back. The order list was the visible symptom; the damage was in the
 * revenue lines on the dashboard, analytics, the customer "total spent"
 * figures and the monthly PDF, all of which overstated takings by the value of
 * every refund ever issued.
 *
 * One function so the next page that reads an order total cannot get it wrong
 * in a seventh way.
 */
export function netPaid(order: { total?: number | null; refund_amount?: number | null }): number {
  return Math.max(0, Number(order.total ?? 0) - Number(order.refund_amount ?? 0))
}

/** True when any money has gone back, so the UI can say so. */
export function wasRefunded(order: { refund_amount?: number | null }): boolean {
  return Number(order.refund_amount ?? 0) > 0
}
