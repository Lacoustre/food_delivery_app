/**
 * Whether the restaurant is taking orders right now.
 *
 * The Settings page showed the stored `isOpen` flag, which is a cache the
 * mobile app writes back rather than a decision — so at ten to ten on a
 * Saturday the panel said "Open for Orders" while the website, which derives
 * the answer from the schedule, correctly said closed. Staff had no way to
 * tell which was true.
 *
 * This mirrors cuisine-webapp/src/lib/hours.ts, which is what the checkout
 * actually enforces. Keep the two in step.
 */
const RESTAURANT_TZ = "America/New_York";

export interface DaySchedule {
  open?: string;
  close?: string;
  closed?: boolean;
}

function minutesOf(hhmm: unknown): number | null {
  if (typeof hhmm !== "string") return null;
  const m = hhmm.match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const h = Number(m[1]), min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

function nowInRestaurantTz(): { dayKey: string; minutes: number } {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone: RESTAURANT_TZ,
      weekday: "long",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    })
      .formatToParts(new Date())
      .map((p) => [p.type, p.value])
  );
  const hour = Number(parts.hour) % 24; // some locales emit "24" at midnight
  return {
    dayKey: String(parts.weekday).toLowerCase(),
    minutes: hour * 60 + Number(parts.minute),
  };
}

export function openRightNow(
  businessHours: Record<string, DaySchedule> | undefined,
  manuallyClosed?: boolean
): { open: boolean; reason: string } {
  if (manuallyClosed === true) {
    return { open: false, reason: "Closed by hand — customers cannot order" };
  }
  if (!businessHours) return { open: true, reason: "No schedule set" };

  const { dayKey, minutes } = nowInRestaurantTz();
  const today = businessHours[dayKey];
  const label = dayKey.charAt(0).toUpperCase() + dayKey.slice(1);

  if (!today || today.closed === true) {
    return { open: false, reason: `Closed on ${label}s` };
  }

  const openM = minutesOf(today.open);
  const closeM = minutesOf(today.close);
  if (openM === null || closeM === null) return { open: true, reason: "Hours not set for today" };

  // A close at or before the open means the day runs past midnight.
  const open =
    closeM > openM ? minutes >= openM && minutes < closeM : minutes >= openM || minutes < closeM;

  return open
    ? { open: true, reason: `${label} hours ${today.open}–${today.close}` }
    : { open: false, reason: `Outside ${label} hours (${today.open}–${today.close})` };
}
