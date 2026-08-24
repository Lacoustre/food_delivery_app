import { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { getUberQuote } from "./uberDirect.ts";

// Connecticut prepared-meals rate. This is the fallback only — the live rate
// comes from settings/restaurant.taxRate (a percentage, e.g. 7.35) so the
// admin panel's tax field actually governs what customers are charged.
export const DEFAULT_TAX_RATE = 0.0735;

// Tax applies to the food subtotal only — never the delivery fee.
export async function getTaxRate(supabase: SupabaseClient): Promise<number> {
  try {
    const { data } = await supabase
      .from("settings")
      .select("value")
      .eq("key", "restaurant")
      .maybeSingle();

    const raw = (data?.value as Record<string, unknown> | null)?.taxRate;
    const pct = typeof raw === "number" ? raw : Number(raw);
    // Stored as a percentage; reject nonsense rather than charging 0.
    if (Number.isFinite(pct) && pct > 0 && pct < 100) return pct / 100;
  } catch {
    // fall through to the default
  }
  return DEFAULT_TAX_RATE;
}

export interface CartItemInput {
  id?: string;
  name?: string;
  quantity: number;
  notes?: string;
}

export interface ValidatedItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
  notes?: string;
}

export interface ValidatedTotals {
  subtotal: number;
  deliveryFee: number;
  tax: number;
  validatedItems: ValidatedItem[];
  // Uber quote this fee came from; null for pickup. Recorded on the order so
  // the charged fee can be reconciled against what Uber actually bills.
  uberQuoteId: string | null;
}

// Never trust client-supplied item prices — look up each item's
// authoritative price from Supabase (by id when available, falling back to
// name for carts persisted before id tracking was added) and recompute
// subtotal/delivery fee/tax server-side.
export async function computeValidatedTotals(
  supabase: SupabaseClient,
  { items, orderType, deliveryAddress, deliveryPhone, scheduledFor }: {
    items: CartItemInput[];
    orderType: "delivery" | "pickup";
    deliveryAddress?: string | null;
    deliveryPhone?: string | null;
    scheduledFor?: string | null;
  },
): Promise<ValidatedTotals> {
  if (!Array.isArray(items) || items.length === 0) {
    throw new Error("Cart is empty");
  }
  if (orderType !== "delivery" && orderType !== "pickup") {
    throw new Error("Invalid order type");
  }

  let subtotal = 0;
  const validatedItems: ValidatedItem[] = [];

  for (const item of items) {
    if (!item || (!item.id && !item.name) || !Number.isInteger(item.quantity) || item.quantity <= 0) {
      throw new Error("Invalid cart item");
    }

    let meal: { id: string; name: string; price: number; active: boolean; available: boolean } | null = null;

    if (item.id) {
      const { data } = await supabase
        .from("meals")
        .select("id, name, price, active, available")
        .eq("id", item.id)
        .single();
      meal = data ?? null;
    }
    if (!meal && item.name) {
      const { data } = await supabase
        .from("meals")
        .select("id, name, price, active, available")
        .eq("name", item.name)
        .single();
      meal = data ?? null;
    }
    if (!meal) {
      throw new Error(`Meal not found: ${item.id || item.name}`);
    }
    if (!meal.active || !meal.available) {
      throw new Error(`Meal unavailable: ${meal.name}`);
    }

    subtotal += meal.price * item.quantity;
    validatedItems.push({
      id: meal.id,
      name: meal.name,
      price: meal.price,
      quantity: item.quantity,
      notes: item.notes,
    });
  }

  // Delivery is priced by Uber, not by us: we charge exactly what they quote.
  // A failed quote is a hard error — falling back to an estimate is how you
  // end up silently charging the wrong fee on every order.
  let deliveryFee = 0;
  let uberQuoteId: string | null = null;
  if (orderType === "delivery") {
    if (!deliveryAddress) throw new Error("Delivery address is required");
    const quote = await getUberQuote({
      dropoffAddress: deliveryAddress,
      dropoffPhone: deliveryPhone ?? null,
      pickupReadyDt: scheduledFor ?? undefined,
      manifestTotalValue: Math.round(subtotal * 100),
    });
    deliveryFee = quote.fee;
    uberQuoteId = quote.quoteId;
  }

  const tax = subtotal * (await getTaxRate(supabase));

  return { subtotal, deliveryFee, tax, validatedItems, uberQuoteId };
}
