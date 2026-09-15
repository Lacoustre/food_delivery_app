/**
 * What the customer chose for one dish, as one line under it:
 * "Extra Shito, No Coleslaw · Note: well done". Empty when they chose nothing.
 */
export function itemDetail(item: {
  modifiers?: { name: string }[] | null;
  notes?: string | null;
}): string {
  return [
    (item.modifiers ?? []).map((m) => m.name).join(", "),
    item.notes ? `Note: ${item.notes}` : "",
  ]
    .filter(Boolean)
    .join(" · ");
}
