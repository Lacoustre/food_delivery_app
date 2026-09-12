# Hosting the admin panel

The admin panel has never been deployed — it has only ever run on a laptop with
`npm run dev`. That means the restaurant cannot take an order on a phone, and
the password reset link has nowhere to land.

It is a Vite single-page app, so it builds to static files. Put it on Vercel
alongside the customer site: same repo, same dashboard, same bill.

## Creating the project

Vercel → Add New → Project → import `Lacoustre/food_delivery_app` (the same
repo the customer site already uses; importing it twice is normal).

Then, before deploying:

| Setting | Value |
| --- | --- |
| Root Directory | `admin-panel` |
| Framework Preset | Vite |
| Build Command | `npm run build` (already in `vercel.json`) |
| Output Directory | `dist` (already in `vercel.json`) |

**Root Directory is the one that matters.** Leave it at the repo root and
Vercel builds the Flutter app's folder and fails.

## Environment variables

Three, and only three. Everything else in `.env.local` is unused by this app.

| Name | Value |
| --- | --- |
| `VITE_SUPABASE_URL` | `https://peimbksjyjcxmurwwmnn.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | the anon key, same one the customer site uses |
| `VITE_WEBAPP_URL` | `https://tasteofafricancuisine.com` |

`VITE_WEBAPP_URL` is where refunds are issued — the admin panel cannot do them
itself, because only the customer site holds the Stripe secret key. It is
currently pointed at the old preview URL, which will keep working but should be
the real domain.

Every `VITE_` variable is compiled into the JavaScript the browser downloads.
Nothing secret can go here. The anon key is designed for that and is safe; a
service role key never would be.

## Why `vercel.json` exists

Two things a plain static deploy gets wrong:

**The SPA fallback.** React Router handles `/orders`, `/reset-password` and the
rest in the browser. A static host asked for `/reset-password` looks for a file
of that name, finds none, and returns 404 — so the emailed reset link would
break on arrival. The rewrite serves `index.html` for any path that is not a
real file, and the router takes it from there.

**Search engines.** `X-Robots-Tag: noindex` keeps the dashboard out of Google.
It is not a security measure — the Supabase role check is — but there is no
reason for it to be findable.

## Pointing a domain at it

Optional, and nicer than a `.vercel.app` address: `admin.tasteofafricancuisine.com`.

In Vercel → the admin project → Settings → Domains, add that subdomain. Vercel
gives you a CNAME to create at Wix. A CNAME on a subdomain is something Wix can
do — unlike MX records, which is why Resend is verified over CNAME instead.

## After it is live

Add the panel's URL to Supabase → Authentication → URL Configuration →
Redirect URLs, with `/**` on the end. Until that is there, an admin password
reset lands on the customer site rather than the panel. See
[supabase-auth-emails.md](./supabase-auth-emails.md).

Then check, on a phone: sign in, open an order, and use the reset link from the
sign-in form to confirm it lands on a form rather than a 404.
