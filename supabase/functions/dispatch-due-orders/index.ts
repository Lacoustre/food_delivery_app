import { createClient } from "npm:@supabase/supabase-js@2";
import { createUberDelivery } from "../_shared/uberDirect.ts";

// Invoked by Supabase Cron every few minutes. Two jobs:
//  1. Scheduled delivery orders (scheduled_for set): dispatch to Uber once
//     the scheduled time is within DISPATCH_LEAD_MINUTES, and flip
//     still-pending ones to confirmed so the kitchen flow starts.
//  2. Failed ASAP dispatches (create-order logged the error and moved on):
//     retry any recent undispatched delivery order.
// Both are guarded by uber_delivery_id being null, so a dispatched order is
// never sent twice; runs are idempotent.

const DISPATCH_LEAD_MINUTES = 30; // courier request lands this far before scheduled_for
const RETRY_WINDOW_HOURS = 24; // don't resurrect stale orders

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const leadCutoff = new Date(Date.now() + DISPATCH_LEAD_MINUTES * 60_000).toISOString();
  const retryCutoff = new Date(Date.now() - RETRY_WINDOW_HOURS * 3600_000).toISOString();

  // Due scheduled orders + recent undispatched ASAP orders, in one query.
  const { data: due, error } = await supabase
    .from("orders")
    .select("id, order_number, user_id, status, delivery_address, scheduled_for, created_at, order_items(name, quantity)")
    .eq("order_type", "delivery")
    .is("uber_delivery_id", null)
    .in("status", ["pending", "confirmed", "preparing"])
    .or(`scheduled_for.lte.${leadCutoff},and(scheduled_for.is.null,created_at.gte.${retryCutoff})`)
    .limit(20);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const results: { orderId: string; ok: boolean; detail: string }[] = [];

  for (const order of due ?? []) {
    // A pending order with no scheduled_for is awaiting something else
    // (e.g. payment) — only scheduled orders auto-confirm here.
    if (order.status === "pending" && !order.scheduled_for) continue;
    if (!order.delivery_address) continue;

    try {
      const { data: profile } = await supabase
        .from("profiles")
        .select("name, phone")
        .eq("id", order.user_id)
        .single();

      const uber = await createUberDelivery({
        orderNumber: order.order_number ?? order.id,
        dropoffAddress: order.delivery_address,
        dropoffName: profile?.name || "Customer",
        dropoffPhone: profile?.phone || null,
        items: (order.order_items ?? []).map((i: { name: string | null; quantity: number }) => ({
          name: i.name ?? "Item",
          quantity: i.quantity,
        })),
      });

      const update: Record<string, unknown> = {
        delivery_provider: "uber_direct",
        uber_delivery_id: uber.deliveryId,
        uber_tracking_url: uber.trackingUrl,
        uber_delivery_status: uber.status,
        uber_fee: uber.fee,
      };
      if (order.status === "pending") update.status = "confirmed";

      const { error: updateError } = await supabase
        .from("orders")
        .update(update)
        .eq("id", order.id);
      if (updateError) throw new Error(updateError.message);

      results.push({ orderId: order.id, ok: true, detail: uber.deliveryId });
    } catch (e) {
      console.error(`dispatch-due-orders: failed for ${order.id}:`, e);
      results.push({ orderId: order.id, ok: false, detail: String((e as Error).message) });
    }
  }

  return new Response(
    JSON.stringify({ checked: due?.length ?? 0, dispatched: results.filter((r) => r.ok).length, results }),
    { headers: { "Content-Type": "application/json" } },
  );
});
