# Resend email — DNS records for tasteofafricancuisine.com

Added to Resend on 2026-09-11. Domain id `55f4edf2-3c14-47ce-9026-feacb20e7de4`.

Add these in **Wix → Domains → tasteofafricancuisine.com → DNS Records**.
Wix is both the registrar and the DNS host, so this is the only place they go.

> Resend's dashboard labels all four of these "SPF". That is wrong. Wix asks
> for the record **type**, so use the types in this table, not Resend's labels.

| Type | Name / Host | Value | Priority |
|---|---|---|---|
| TXT | `resend._domainkey` | `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDCa0hs4Qxze/NsG2zdPHBJtVlLWMv+qmpEoom2gDvZZUmbah26h8ViMY9pwh3yTPrHWz1KgfHGDMb42SgttAYvTs/iwMi5s6cDj+5fuwpvHqA1iTsA9XDaNxqmflcncR991ps5mpGRN8EttmN7rcBdDKmO3QVidb4jaUc0XGBOzwIDAQAB` | — |
| MX | `send` | `feedback-smtp.us-east-1.amazonses.com` | 10 |
| TXT | `send` | `v=spf1 include:amazonses.com ~all` | — |
| CNAME | `rsend` | `send.forge.rmta.net` | — |

## Do not touch these

The restaurant's email runs on Zoho and is unrelated to the website. Deleting
any of these stops mail to the business immediately:

| Type | Name | Value |
|---|---|---|
| MX | `@` | `mx.zoho.com` (10), `mx2.zoho.com` (20), `mx3.zoho.com` (30) |
| TXT | `@` | `v=spf1 include:zohomail.com ~all` |
| TXT | `@` | `zoho-verification=zb31447644.zmverify.zoho.com` |

Every Resend record sits on a subdomain (`send`, `rsend`,
`resend._domainkey`), so the two systems do not collide.

## Website records (separate job, for Vercel)

| Type | Name | Value |
|---|---|---|
| A | `@` | Vercel's IP — take the exact value from the Vercel dashboard |
| CNAME | `www` | `cname.vercel-dns.com` |

The apex currently points at Wix (`185.230.63.x`) and serves a 404, since the
Wix subscription was cancelled. Changing it breaks nothing.

## After adding the records

    node scripts/check-resend-domain.mjs

Propagation is usually 10-30 minutes. Once verified, `FROM_EMAIL` in
`cuisine-webapp/.env.local` already reads
`Taste of African Cuisine <orders@tasteofafricancuisine.com>` and will start
working with no code change.
