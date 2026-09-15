/**
 * An order status as staff read it.
 *
 * Statuses are stored as written when the system was built, including the
 * British 'cancelled'. That stored value stays — every existing order, the
 * refund logic and the database policies all match on it — but the screens
 * are in American English, so it is shown as "Canceled".
 */
export function statusLabel(status: string | null | undefined): string {
  const s = (status ?? "").trim();
  if (!s) return "Unknown";
  if (s.toLowerCase() === "cancelled") return "Canceled";
  return s.charAt(0).toUpperCase() + s.slice(1);
}
