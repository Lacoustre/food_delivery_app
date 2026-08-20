// Uber Direct (Deliveries API) client for dispatching confirmed delivery
// orders to Uber's courier network — replaces the in-house driver system.
//
// Requires these secrets (Dashboard → Edge Functions → Secrets):
//   UBER_DIRECT_CLIENT_ID
//   UBER_DIRECT_CLIENT_SECRET
//   UBER_DIRECT_CUSTOMER_ID
//
// NOTE: endpoint/field names follow Uber's documented Direct API; verify
// against developer.uber.com docs before first production dispatch.

const UBER_AUTH_URL = "https://auth.uber.com/oauth/v2/token";
const UBER_API_BASE = "https://api.uber.com/v1/customers";

// Single-location restaurant; used as the pickup point for every delivery.
export const RESTAURANT_PICKUP = {
  name: "Taste of African Cuisine",
  address: "200 Hartford Turnpike, Vernon, CT 06066",
  phone: "+18608055121",
  lat: 41.82457,
  lng: -72.4978,
};

export interface UberDispatchResult {
  deliveryId: string;
  trackingUrl: string | null;
  status: string;
  fee: number | null; // dollars
}

async function getAccessToken(): Promise<string> {
  const clientId = Deno.env.get("UBER_DIRECT_CLIENT_ID");
  const clientSecret = Deno.env.get("UBER_DIRECT_CLIENT_SECRET");
  if (!clientId || !clientSecret) {
    throw new Error("Uber Direct credentials not configured");
  }

  const res = await fetch(UBER_AUTH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "client_credentials",
      scope: "eats.deliveries",
    }),
  });
  if (!res.ok) {
    throw new Error(`Uber auth failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  if (!data.access_token) throw new Error("Uber auth response missing access_token");
  return data.access_token;
}

export async function createUberDelivery(order: {
  orderNumber: string;
  dropoffAddress: string;
  dropoffName: string;
  dropoffPhone: string | null;
  items: { name: string; quantity: number }[];
}): Promise<UberDispatchResult> {
  const customerId = Deno.env.get("UBER_DIRECT_CUSTOMER_ID");
  if (!customerId) throw new Error("Uber Direct customer id not configured");

  const token = await getAccessToken();

  const res = await fetch(`${UBER_API_BASE}/${customerId}/deliveries`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      external_id: order.orderNumber,
      pickup_name: RESTAURANT_PICKUP.name,
      pickup_address: RESTAURANT_PICKUP.address,
      pickup_phone_number: RESTAURANT_PICKUP.phone,
      pickup_latitude: RESTAURANT_PICKUP.lat,
      pickup_longitude: RESTAURANT_PICKUP.lng,
      dropoff_name: order.dropoffName,
      dropoff_address: order.dropoffAddress,
      dropoff_phone_number: order.dropoffPhone || RESTAURANT_PICKUP.phone,
      manifest_items: order.items.map((i) => ({
        name: i.name,
        quantity: i.quantity,
      })),
    }),
  });
  if (!res.ok) {
    throw new Error(`Uber delivery create failed: ${res.status} ${await res.text()}`);
  }
  const data = await res.json();
  return {
    deliveryId: data.id,
    trackingUrl: data.tracking_url || null,
    status: data.status || "pending",
    // Uber returns fee in cents
    fee: typeof data.fee === "number" ? data.fee / 100 : null,
  };
}
