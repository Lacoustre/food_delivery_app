import { SupabaseClient } from "npm:@supabase/supabase-js@2";

// Mobile's own tax rate (Connecticut) — kept as-is; note this differs from
// the webapp's 7.35%, a pre-existing cross-app inconsistency, not fixed
// here since it's a business/pricing question, not a security one.
export const TAX_RATE = 0.0635;

export function calculateDeliveryFee(distanceMiles: number): number {
  const baseFee = 3.99;
  const baseTierMaxDistance = 3.0;
  const midTierMaxDistance = 10.0;
  const midTierRatePerMile = 0.5;
  const extendedTierBase = 7.49;
  const extendedTierRatePerMile = 0.75;

  if (distanceMiles <= baseTierMaxDistance) return baseFee;
  if (distanceMiles <= midTierMaxDistance) {
    return baseFee + (distanceMiles - baseTierMaxDistance) * midTierRatePerMile;
  }
  return extendedTierBase + (distanceMiles - midTierMaxDistance) * extendedTierRatePerMile;
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
}

// Never trust client-supplied item prices — look up each item's
// authoritative price from Supabase (by id when available, falling back to
// name for carts persisted before id tracking was added) and recompute
// subtotal/delivery fee/tax server-side.
export async function computeValidatedTotals(
  supabase: SupabaseClient,
  { items, orderType, distanceMiles }: {
    items: CartItemInput[];
    orderType: "delivery" | "pickup";
    distanceMiles: number;
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

  const deliveryFee = orderType === "delivery" ? calculateDeliveryFee(distanceMiles || 0) : 0;
  const tax = subtotal * TAX_RATE;

  return { subtotal, deliveryFee, tax, validatedItems };
}
