import { createClient } from "npm:@supabase/supabase-js@2";
import { getUberQuote } from "../_shared/uberDirect.ts";

// Delivery fee for display at checkout, straight from Uber. Replaces
// get-driving-distance: we no longer estimate a distance and price it against
// a tier table — Uber quotes the delivery and we charge exactly that.
//
// This is display only. create-payment-intent re-quotes server-side, so a
// tampered client can't influence what is actually charged.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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

    const { dropoffAddress, dropoffPhone, scheduledFor, subtotal } = await req.json();
    if (typeof dropoffAddress !== "string" || !dropoffAddress.trim()) {
      return new Response(
        JSON.stringify({ error: "dropoffAddress is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const quote = await getUberQuote({
      dropoffAddress: dropoffAddress.trim(),
      dropoffPhone: typeof dropoffPhone === "string" ? dropoffPhone : null,
      pickupReadyDt: typeof scheduledFor === "string" ? scheduledFor : undefined,
      manifestTotalValue: typeof subtotal === "number" ? Math.round(subtotal * 100) : undefined,
    });

    return new Response(
      JSON.stringify({
        fee: quote.fee,
        currency: quote.currency,
        durationMinutes: quote.durationMinutes,
        quoteId: quote.quoteId,
        expires: quote.expires,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    // Uber declining to quote is a real answer: usually out of range, or an
    // address it can't resolve. Surface it rather than inventing a fee.
    const message = error instanceof Error ? error.message : "Quote failed";
    console.error("quote-delivery failed:", message);
    return new Response(
      JSON.stringify({ error: "We could not quote delivery to that address. Check it includes the street, city and ZIP — we deliver within about 10 miles of Vernon." }),
      { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
