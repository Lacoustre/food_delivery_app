# Email — Resend on tasteofafricancuisine.com

**Status: working.** Verified 2026-09-11, test message delivered.

## What is in DNS

Added in **Wix → Domains → tasteofafricancuisine.com → Manage DNS Records**.
Wix is both registrar and DNS host, so this is the only place these live.

| Type | Name | Value |
|---|---|---|
| TXT | `@` | `resend-domain-verification=8a8d28399312df8a77a74dea3b02498f` |
| TXT | `resend._domainkey` | the DKIM public key (`p=MIGfMA0GCSqG…RJBiPNQIDAQAB`) |
| CNAME | `rsend` | `rsend.forge.rmta.net` |
| CNAME | `send` | `send.forge.rmta.net` |

## Why there is no MX record

Resend's default setup wants an MX record on `send` for bounce feedback.
**Wix does not support MX records on subdomains**, and Resend detects this: it
refuses to verify and tells you to re-add the domain to get a CNAME-based set
instead. That second set is what is in the table above.

Re-adding must be done in the Resend **dashboard**, not the API — the API
issues the MX variant regardless, because the CNAME alternative is offered
only once Resend has detected the DNS provider.

## Do not touch — the restaurant's own email

Mail for the business runs on Zoho and is unrelated to the website. Deleting
any of these stops it immediately:

| Type | Name | Value |
|---|---|---|
| MX | `@` | `mx.zoho.com` (10), `mx2.zoho.com` (20), `mx3.zoho.com` (30) |
| TXT | `@` | `v=spf1 include:zohomail.com ~all` |
| TXT | `@` | `zoho-verification=zb31447644.zmverify.zoho.com` |
| TXT | `zmail._domainkey` | `v=DKIM1; k=rsa; p=…` |
| TXT | `_dmarc` | `v=DMARC1; p=none;` |

Every Resend record sits on a subdomain, so the two never collide.

**Enable Receiving must stay OFF in Resend.** Turning it on would demand MX
records pointing at Resend, which would fight the Zoho MX records above.

## Two Resend accounts

There are two Resend teams. The domain is verified in the one reachable in the
browser; the other holds an older, failed copy of the same domain.
`RESEND_API_KEY` in `.env.local` must be a key from the team where the domain
shows **Verified**, or every send returns 403. The key currently in use is
sending-access only, which is why it cannot list domains or read delivery
status — that is deliberate, not a fault.

## Leftovers worth deleting

Three CNAMEs from the retired SendGrid setup still sit in the zone and do
nothing: `s1._domainkey`, `s2._domainkey`, `em1315` — all pointing at
`sendgrid.net` under user `u54268192`. Safe to remove now that email is
verified. The SendGrid key they belonged to is one of the credentials exposed
in git history.

## Website records (separate job)

The apex still points at Wix and serves a 404, since that subscription was
cancelled. Change these at deploy time, never before — deleting them early
leaves the domain resolving nowhere.

| Type | Name | Current | Becomes |
|---|---|---|---|
| A ×3 | `@` | `185.230.63.107 / .186 / .171` | Vercel's IP |
| CNAME | `www` | `cdn1.wixdns.net` | `cname.vercel-dns.com` |

---

# Stripe webhook

Two environment variables are needed, in `.env.local` and in Vercel:

    STRIPE_WEBHOOK_SECRET=whsec_...      # Stripe dashboard, see below
    SUPABASE_SERVICE_ROLE_KEY=eyJ...     # Supabase > Project Settings > API

The service role key is unavoidable here: a webhook arrives with no user
session, so row-level security has nothing to apply.

## Adding the endpoint

1. Stripe dashboard > **Developers > Webhooks > Add endpoint**
2. URL: `https://<your-site>/api/webhooks/stripe`
3. Event: **`payment_intent.succeeded`** — that one alone
4. Copy the **signing secret** it shows and set `STRIPE_WEBHOOK_SECRET`

Make sure the dashboard is in **live** mode. A test-mode endpoint produces a
different signing secret and live payments will never reach it.

## What it does

Checkout confirms the card and then calls `/api/create-order`. If the browser
dies in between, the customer is charged and no order exists — the kitchen
never sees it and the first anyone hears is a chargeback.

The webhook is the backstop. It acts only when no order already carries the
PaymentIntent, so a browser that finished the job wins and the webhook does
nothing. What it writes comes from `pending_orders`, recorded by
create-payment-intent after the server priced the items, validated the promo
and quoted Uber — nothing is taken from the client.

If a payment arrives with no order *and* no pending record, it logs
`ORPHANED PAYMENT <id>` and returns 200. Worth searching the Vercel logs for
occasionally; it means somebody paid for food nobody knows about.

`scripts/reconcile-payments.mjs` still earns its place as a daily check,
because it catches anything the webhook itself missed.
