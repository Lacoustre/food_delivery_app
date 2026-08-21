import { createClient } from "npm:@supabase/supabase-js@2";

// Receives Uber Direct delivery-status webhooks and mirrors them onto the
// order row, so the customer app's realtime order subscription picks up
// courier progress without polling Uber.
//
// Deployed with --no-verify-jwt (Uber can't send a Supabase JWT); requests
// are authenticated instead by verifying Uber's HMAC-SHA256 signature with
// the shared UBER_DIRECT_WEBHOOK_SECRET (Uber dashboard → webhook signing
// key). NOTE: header name + payload shape follow Uber's documented webhook
// format; verify against developer.uber.com before relying on it.

// Uber delivery statuses → the app's order-status vocabulary. Statuses not
// listed (pending, pickup, canceled, returned) don't change the order's own
// status — the kitchen flow or the restaurant owns those — but every event
// still updates uber_delivery_status.
const ORDER_STATUS_FOR: Record<string, string> = {
  pickup_complete: "on the way",
  dropoff: "on the way",
  delivered: "delivered",
};

async function verifySignature(rawBody: string, signature: string | null): Promise<boolean> {
  const secret = Deno.env.get("UBER_DIRECT_WEBHOOK_SECRET");
  if (!secret) return false; // unset secret = reject everything, never open
  if (!signature) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // constant-time comparison
  const given = signature.trim().toLowerCase();
  if (given.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ given.charCodeAt(i);
  }
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const rawBody = await req.text();
  const signature = req.headers.get("x-postmates-signature") ??
    req.headers.get("x-uber-signature");
  if (!(await verifySignature(rawBody, signature))) {
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const event = JSON.parse(rawBody);
    // Uber nests the delivery under `data`; fall back to top-level fields
    // so a shape drift degrades to a logged no-op instead of an error.
    const delivery = event.data ?? event;
    const deliveryId: string | undefined = delivery.id ?? delivery.delivery_id;
    // Refund requests carry no delivery status — surface them on the order
    // as a distinct uber_delivery_status so the admin panel flags them.
    const isRefund = typeof event.kind === "string" && event.kind.includes("refund");
    const uberStatus: string | undefined = isRefund
      ? "refund_requested"
      : (delivery.status ?? event.status);
    if (isRefund) console.warn(`uber-webhook: refund requested for delivery ${deliveryId}`, rawBody.slice(0, 500));

    if (!deliveryId || !uberStatus) {
      console.warn("uber-webhook: event missing delivery id or status", event.kind ?? "");
      return new Response(JSON.stringify({ ok: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // Service role: this update comes from Uber, not a user session, and
    // must bypass RLS. Safe here because the function only ever writes the
    // uber_* mirror fields + mapped status, keyed by our stored delivery id.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const update: Record<string, unknown> = { uber_delivery_status: uberStatus };
    const mappedStatus = ORDER_STATUS_FOR[uberStatus];
    if (mappedStatus) update.status = mappedStatus;
    if (delivery.tracking_url) update.uber_tracking_url = delivery.tracking_url;

    const { data: updated, error } = await supabase
      .from("orders")
      .update(update)
      .eq("uber_delivery_id", deliveryId)
      .select("id");

    if (error) throw new Error(error.message);
    if (!updated?.length) {
      console.warn(`uber-webhook: no order found for delivery ${deliveryId}`);
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("uber-webhook error:", error);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
