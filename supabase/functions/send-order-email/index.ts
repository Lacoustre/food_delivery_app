// Order confirmation/status emails via Resend — replaces the Firebase
// sendOrderConfirmationEmail / sendOrderCompletionEmail callables.
// Secrets: RESEND_API_KEY, FROM_EMAIL (optional, has a default).
//
// FROM_EMAIL must be on a domain verified in Resend. Until a domain is
// verified, Resend only accepts its own sandbox sender.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface OrderItem {
  name: string;
  quantity: number;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { type, orderId, customerEmail, customerName, items, total, deliveryMethod, status } =
      await req.json();

    if (!orderId || !customerEmail || !customerName || !type) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const apiKey = Deno.env.get("RESEND_API_KEY");
    if (!apiKey) throw new Error("RESEND_API_KEY not configured");
    const fromEmail = Deno.env.get("FROM_EMAIL") ||
      "Taste of African Cuisine <orders@tasteofafricancuisine.com>";

    let subject: string;
    let htmlContent: string;

    if (type === "confirmation") {
      const itemsList = ((items ?? []) as OrderItem[])
        .map((item) => `${item.name} x${item.quantity}`)
        .join(", ");
      subject = `Order Confirmation #${orderId}`;
      htmlContent = `
        <h2>Order Confirmation</h2>
        <p>Hi ${customerName},</p>
        <p>Thank you for your order! Here are the details:</p>
        <div style="border: 1px solid #ddd; padding: 15px; margin: 20px 0;">
          <h3>Order #${orderId}</h3>
          <p><strong>Items:</strong> ${itemsList}</p>
          <p><strong>Total:</strong> $${Number(total ?? 0).toFixed(2)}</p>
          <p><strong>Method:</strong> ${deliveryMethod ?? ""}</p>
        </div>
        <p>We'll notify you when your order is ready!</p>
      `;
    } else {
      const statusMessages: Record<string, string> = {
        "delivered": "Your order has been delivered! Enjoy your meal!",
        "picked up": "Thank you for picking up your order! Enjoy!",
        "cancelled": "Your order has been cancelled. If you paid by card, the refund has been issued and usually reaches your bank within 5-10 days.",
      };
      const message = statusMessages[status as string] || `Your order status: ${status}`;
      subject = `Order Update #${orderId}`;
      htmlContent = `
        <h2>Order Update</h2>
        <p>Hi ${customerName},</p>
        <p>${message}</p>
        <p><strong>Order #${orderId}</strong></p>
        <p>Thank you for choosing Taste of African Cuisine!</p>
      `;
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [customerEmail],
        subject,
        html: htmlContent,
      }),
    });
    if (!res.ok) {
      // Resend puts the reason in the body — log it, since a rejected sender
      // domain and a bad key look identical from the status code alone.
      console.error("Resend error:", res.status, await res.text());
      throw new Error("Resend request failed");
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("send-order-email error:", error);
    return new Response(JSON.stringify({ error: "Failed to send email" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
