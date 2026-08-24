import { createClient } from "npm:@supabase/supabase-js@2";
import Stripe from "npm:stripe@18";
import { computeValidatedTotals } from "../_shared/pricing.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-06-20",
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
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
      tipAmount = 0,
      orderId,
      customerName,
      deliveryAddress,
      scheduledFor,
      currency = "usd",
    } = await req.json();

    if (!orderId || typeof orderId !== "string") {
      throw new Error("Invalid orderId");
    }

    const safeTip = typeof tipAmount === "number" && tipAmount >= 0 ? tipAmount : 0;
    const { subtotal, deliveryFee, tax, validatedItems } = await computeValidatedTotals(supabase, {
      items,
      orderType,
      deliveryAddress,
      scheduledFor,
    });
    const total = subtotal + deliveryFee + tax + safeTip;
    const amountInCents = Math.round(total * 100);

    if (amountInCents < 50) {
      throw new Error(`Minimum amount is $0.50, got $${total}`);
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInCents,
      currency: currency.toLowerCase(),
      payment_method_types: ["card"],
      metadata: {
        orderId: orderId.trim(),
        customerName: (customerName || "Customer").trim(),
        userId: userData.user.id,
        timestamp: new Date().toISOString(),
      },
      description: `Payment for order ${orderId}`,
      receipt_email: userData.user.email,
    });

    return new Response(
      JSON.stringify({
        client_secret: paymentIntent.client_secret,
        orderId,
        subtotal,
        deliveryFee,
        tax,
        tip: safeTip,
        total,
        items: validatedItems,
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
