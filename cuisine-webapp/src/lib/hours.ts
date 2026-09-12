import { supabase } from '@/lib/supabase'

/**
 * Whether the restaurant is currently taking ASAP orders.
 *
 * Node/Next twin of supabase/functions/_shared/hours.ts, which serves the
 * mobile app — the webapp runs its own API routes and can't import the Deno
 * module. Keep the two in step.
 *
 * Both apps show a "closed" banner, but that's presentation. This is the check
 * that holds, for the same reason item prices are re-looked-up server-side
 * rather than trusted from the client.
 *
 * Scheduled orders are exempt: booking ahead while closed is the feature.
 */

const RESTAURANT_TZ = 'America/New_York'

const DAY_KEYS = [
  'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
]

interface DaySchedule {
  open?: string
  close?: string
  closed?: boolean
}

export interface OpenState {
  open: boolean
  reason?: string
}

function minutesOf(hhmm: unknown): number | null {
  if (typeof hhmm !== 'string') return null
  const m = hhmm.match(/^(\d{1,2}):(\d{2})$/)
  if (!m) return null
  const h = Number(m[1]), min = Number(m[2])
  if (h > 23 || min > 59) return null
  return h * 60 + min
}

// The restaurant's own wall clock, not the server's UTC.
function inRestaurantTz(when: Date): { dayKey: string; minutes: number } {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: RESTAURANT_TZ,
      weekday: 'long',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(when).map(p => [p.type, p.value])
  )
  const hour = Number(parts.hour) % 24 // some locales emit "24" at midnight
  return {
    dayKey: String(parts.weekday).toLowerCase(),
    minutes: hour * 60 + Number(parts.minute)
  }
}

export async function getOpenState(): Promise<OpenState> {
  let value: Record<string, unknown> | null = null
  try {
    const { data } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'restaurant')
      .maybeSingle()
    value = (data?.value as Record<string, unknown>) ?? null
  } catch {
    // Settings unreachable is not a reason to refuse business.
    return { open: true }
  }
  if (!value) return { open: true }

  // An explicit "closed today" switch. Deliberately not `isOpen`: that field
  // is derived from businessHours by the mobile app and written back, so it is
  // a cache of this same schedule rather than a decision, and it goes stale as
  // soon as no admin has the app open.
  if (value.manuallyClosed === true) {
    const msg = typeof value.message === 'string' && value.message.trim()
      ? value.message.trim()
      : 'The restaurant is closed right now.'
    return { open: false, reason: msg }
  }

  const hours = value.businessHours as Record<string, DaySchedule> | undefined
  if (!hours) return { open: true }

  const { dayKey, minutes } = inRestaurantTz(new Date())
  if (!DAY_KEYS.includes(dayKey)) return { open: true }

  const today = hours[dayKey]
  if (!today || today.closed === true) {
    return { open: false, reason: 'The restaurant is closed today.' }
  }

  const openM = minutesOf(today.open)
  const closeM = minutesOf(today.close)
  if (openM === null || closeM === null) return { open: true }

  // A close time at or before the open time means the day runs past midnight.
  const isOpen = closeM > openM
    ? minutes >= openM && minutes < closeM
    : minutes >= openM || minutes < closeM

  return isOpen
    ? { open: true }
    : {
      open: false,
      reason: `The restaurant is closed right now. Today's hours are ${today.open}–${today.close}.`
    }
}


/**
 * Whether the restaurant will be open at a given moment.
 *
 * Scheduled orders skipped the open check entirely, which is right for the
 * "we are shut right now" case — booking ahead while closed is the feature —
 * but wrong for the schedule itself. A customer could pick "in 2 hours" on a
 * Sunday, or at 8pm on a Saturday, and the order was accepted and charged for
 * a moment when the kitchen is closed and nobody would cook it.
 *
 * Deliberately ignores `manuallyClosed`: that is a switch about now, and
 * scheduling past it is exactly what a customer is trying to do. This checks
 * the published schedule only.
 */
export async function getScheduleStateAt(when: Date): Promise<OpenState> {
  let value: Record<string, unknown> | null = null
  try {
    const { data } = await supabase
      .from('settings')
      .select('value')
      .eq('key', 'restaurant')
      .maybeSingle()
    value = (data?.value as Record<string, unknown>) ?? null
  } catch {
    return { open: true }
  }
  if (!value) return { open: true }

  const hours = value.businessHours as Record<string, DaySchedule> | undefined
  if (!hours) return { open: true }

  const { dayKey, minutes } = inRestaurantTz(when)
  if (!DAY_KEYS.includes(dayKey)) return { open: true }

  const day = hours[dayKey]
  const label = dayKey.charAt(0).toUpperCase() + dayKey.slice(1)

  if (!day || day.closed === true) {
    return { open: false, reason: `We are closed on ${label}s. Please choose another time.` }
  }

  const openM = minutesOf(day.open)
  const closeM = minutesOf(day.close)
  if (openM === null || closeM === null) return { open: true }

  const open = closeM > openM
    ? minutes >= openM && minutes < closeM
    : minutes >= openM || minutes < closeM

  return open
    ? { open: true }
    : {
      open: false,
      reason: `We close at ${day.close} on ${label}s, so we cannot have that ready in time.`
    }
}
