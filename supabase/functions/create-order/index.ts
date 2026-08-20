import { createClient } from "npm:@supabase/supabase-js@2";
import { computeValidatedTotals } from "../_shared/pricing.ts";
import { createUberDelivery } from "../_shared/uberDirect.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Scoped to the caller's own access token so Postgres RLS
    // (orders_owner_insert: auth.uid() = user_id) applies for real — this
    // is what actually enforces ownership, not application code.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
    );

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const {
      items,
      orderType,
      distanceMiles = 0,
      tipAmount = 0,
      deliveryAddress,
      scheduledFor,
      paymentMethod = "card",
    } = await req.json();

    // Never trust client-supplied items/pricing — same authoritative
    // lookup used for the payment intent, so the order that gets
    // fulfilled always matches what was actually charged.
    const { subtotal, deliveryFee, tax, validatedItems } = await computeValidatedTotals(supabase, {
      items,
      orderType,
      distanceMiles,
    });
    const safeTip = typeof tipAmount === "number" && tipAmount >= 0 ? tipAmount : 0;
    const total = subtotal + deliveryFee + tax + safeTip;
    const orderNumber = String(Math.floor(Math.random() * 10000) + 1000);

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .insert({
        user_id: userData.user.id,
        status: scheduledFor ? "pending" : "confirmed",
        order_number: orderNumber,
        order_type: orderType,
        payment_method: paymentMethod,
        delivery_address: orderType === "delivery" ? deliveryAddress : null,
        scheduled_for: scheduledFor || null,
        subtotal,
        delivery_fee: deliveryFee,
        tax,
        tip: safeTip,
        total,
      })
      .select()
      .single();

    if (orderError || !order) {
      throw new Error(orderError?.message || "Failed to create order");
    }

    const { error: itemsError } = await supabase.from("order_items").insert(
      validatedItems.map((item) => ({
        order_id: order.id,
        meal_id: item.id,
        name: item.name,
        quantity: item.quantity,
        unit_price: item.price,
        notes: item.notes || null,
      })),
    );

    if (itemsError) {
      throw new Error(itemsError.message);
    }

    // Dispatch confirmed (non-scheduled) delivery orders to Uber Direct.
    // A dispatch failure must not fail the order — it's already created and
    // paid for — so it's caught and the order is left for manual dispatch.
    let uberTrackingUrl: string | null = null;
    if (orderType === "delivery" && order.status === "confirmed") {
      try {
        const { data: profile } = await supabase
          .from("profiles")
          .select("name, phone")
          .eq("id", userData.user.id)
          .single();

        const uber = await createUberDelivery({
          orderNumber,
          dropoffAddress: deliveryAddress,
          dropoffName: profile?.name || "Customer",
          dropoffPhone: profile?.phone || null,
          items: validatedItems.map((i) => ({ name: i.name, quantity: i.quantity })),
        });

        uberTrackingUrl = uber.trackingUrl;
        await supabase
          .from("orders")
          .update({
            delivery_provider: "uber_direct",
            uber_delivery_id: uber.deliveryId,
            uber_tracking_url: uber.trackingUrl,
            uber_delivery_status: uber.status,
            uber_fee: uber.fee,
          })
          .eq("id", order.id);
      } catch (uberError) {
        console.error(`Uber dispatch failed for order ${order.id}:`, uberError);
      }
    }

    return new Response(
      JSON.stringify({
        orderId: order.id,
        orderNumber,
        items: validatedItems,
        subtotal,
        deliveryFee,
        tax,
        tip: safeTip,
        total,
        uberTrackingUrl,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
