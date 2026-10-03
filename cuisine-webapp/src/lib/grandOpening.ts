/**
 * The grand opening offer: 20% off every dish on one day.
 *
 * The code itself lives in the promotions table, which is what the server
 * validates against — this is only what the site shows and when. The day is
 * measured in the restaurant's own time zone, not the customer's, so someone
 * ordering from another state sees the offer on the same day the restaurant
 * is running it.
 */
export const GRAND_OPENING = {
  code: 'OPENING20',
  percent: 20,
  day: '2026-10-03',
} as const

const vernonDay = (now: Date) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/New_York',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now)

export function openingState(now: Date = new Date()): 'before' | 'today' | 'over' {
  const today = vernonDay(now)
  if (today < GRAND_OPENING.day) return 'before'
  if (today === GRAND_OPENING.day) return 'today'
  return 'over'
}
