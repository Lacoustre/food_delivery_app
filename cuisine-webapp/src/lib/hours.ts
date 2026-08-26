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
function nowInRestaurantTz(): { dayKey: string; minutes: number } {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: RESTAURANT_TZ,
      weekday: 'long',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).formatToParts(new Date()).map(p => [p.type, p.value])
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

  // Manual override from the admin panel wins over the schedule.
  if (value.isOpen === false) {
    const msg = typeof value.message === 'string' && value.message.trim()
      ? value.message.trim()
      : 'The restaurant is currently closed.'
    return { open: false, reason: msg }
  }

  const hours = value.businessHours as Record<string, DaySchedule> | undefined
  if (!hours) return { open: true }

  const { dayKey, minutes } = nowInRestaurantTz()
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
