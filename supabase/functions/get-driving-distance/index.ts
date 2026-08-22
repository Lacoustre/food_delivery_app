import { createClient } from "npm:@supabase/supabase-js@2";
import { RESTAURANT_PICKUP } from "../_shared/uberDirect.ts";

// Driving distance (miles) from the restaurant to the customer, via the
// Google Routes API — replaces the Firebase getDrivingDistance callable,
// which broke when the apps stopped carrying Firebase Auth tokens.
// Secret: GOOGLE_ROUTES_API_KEY.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Same auth bar as the old callable: any signed-in user.
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

    const { customerLat, customerLon } = await req.json();
    if (typeof customerLat !== "number" || typeof customerLon !== "number") {
      return new Response(
        JSON.stringify({ error: "customerLat and customerLon must be numbers" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const apiKey = Deno.env.get("GOOGLE_ROUTES_API_KEY");
    if (!apiKey) throw new Error("GOOGLE_ROUTES_API_KEY not configured");

    const response = await fetch(
      "https://routes.googleapis.com/directions/v2:computeRoutes",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "routes.distanceMeters",
        },
        body: JSON.stringify({
          origin: {
            location: {
              latLng: { latitude: RESTAURANT_PICKUP.lat, longitude: RESTAURANT_PICKUP.lng },
            },
          },
          destination: {
            location: { latLng: { latitude: customerLat, longitude: customerLon } },
          },
          travelMode: "DRIVE",
          routingPreference: "TRAFFIC_AWARE",
        }),
      },
    );

    if (!response.ok) {
      console.error("Routes API error:", await response.text());
      throw new Error("Routes API request failed");
    }

    const data = await response.json();
    if (!data.routes?.length) throw new Error("No routes returned");

    const miles = data.routes[0].distanceMeters / 1609.34;
    return new Response(JSON.stringify({ distanceMiles: Number(miles.toFixed(2)) }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("get-driving-distance failed:", error);
    return new Response(
      JSON.stringify({ error: "Failed to calculate driving distance" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
