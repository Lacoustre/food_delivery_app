import { SupabaseClient } from "npm:@supabase/supabase-js@2";

// Whether the restaurant is currently taking ASAP orders.
//
// Both apps show a "closed" banner and push the customer towards scheduling,
// but nothing server-side enforced it — so a client that skipped the banner
// could place an ASAP order at 3am and have it charged and dispatched. This is
// the same reason item prices are re-looked-up rather than trusted.
//
// Scheduled orders are deliberately exempt: booking ahead while closed is the
// feature working, not a bypass.

const RESTAURANT_TZ = "America/New_York";

const DAY_KEYS = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

interface DaySchedule {
  open?: string;
  close?: string;
  closed?: boolean;
}

export interface OpenState {
  open: boolean;
  reason?: string;
}

function minutesOf(hhmm: unknown): number | null {
  if (typeof hhmm !== "string") return null;
  const m = hhmm.match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return null;
  const h = Number(m[1]), min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

// The restaurant's own wall clock, not the server's UTC.
function nowInRestaurantTz(): { dayKey: string; minutes: number } {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: RESTAURANT_TZ,
    weekday: "long",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = Object.fromEntries(
    fmt.formatToParts(new Date()).map((p) => [p.type, p.value]),
  );
  const hour = Number(parts.hour) % 24; // some locales emit "24" at midnight
  return {
    dayKey: String(parts.weekday).toLowerCase(),
    minutes: hour * 60 + Number(parts.minute),
  };
}

export async function getOpenState(
  supabase: SupabaseClient,
): Promise<OpenState> {
  let value: Record<string, unknown> | null = null;
  try {
    const { data } = await supabase
      .from("settings")
      .select("value")
      .eq("key", "restaurant")
      .maybeSingle();
    value = (data?.value as Record<string, unknown>) ?? null;
  } catch {
    // Settings unreachable is not a reason to refuse business.
    return { open: true };
  }
  if (!value) return { open: true };

  // Manual override from the admin panel wins over the schedule.
  if (value.isOpen === false) {
    const msg = typeof value.message === "string" && value.message.trim()
      ? value.message.trim()
      : "The restaurant is currently closed.";
    return { open: false, reason: msg };
  }

  const hours = value.businessHours as Record<string, DaySchedule> | undefined;
  if (!hours) return { open: true };

  const { dayKey, minutes } = nowInRestaurantTz();
  if (!DAY_KEYS.includes(dayKey)) return { open: true };

  const today = hours[dayKey];
  if (!today || today.closed === true) {
    return { open: false, reason: "The restaurant is closed today." };
  }

  const openM = minutesOf(today.open);
  const closeM = minutesOf(today.close);
  if (openM === null || closeM === null) return { open: true };

  // A close time at or before the open time means the day runs past midnight.
  const isOpen = closeM > openM
    ? minutes >= openM && minutes < closeM
    : minutes >= openM || minutes < closeM;

  return isOpen
    ? { open: true }
    : {
      open: false,
      reason: `The restaurant is closed right now. Today's hours are ${today.open}–${today.close}.`,
    };
}
