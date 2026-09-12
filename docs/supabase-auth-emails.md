# Supabase auth emails

Three emails come from Supabase rather than from our own code: the signup
confirmation, the customer password reset and the admin password reset. The
last two share one template. Order confirmations and status
updates are ours (`cuisine-webapp/src/lib/emailService.ts`) and are not affected
by anything on this page.

Both of Supabase's are configured in the dashboard, not in this repo. The HTML
lives in `docs/email-templates/` so it is version-controlled and can be pasted
back if the dashboard is ever reset.

## 1. Send them from our own domain first

This matters more than the design.

By default Supabase sends these from `noreply@mail.app.supabase.io`. A customer
who signs up at tasteofafricancuisine.com then gets a mail from a domain they
have never heard of, asking them to click a link — which is what a phishing mail
looks like, and is what spam filters score it as.

There is a second reason. Supabase's built-in sender is rate-limited to a
handful of messages per hour and is explicitly not meant for production. Past
that limit signups silently stop arriving.

Point it at Resend, where `tasteofafricancuisine.com` is already verified:

**Authentication → Emails → SMTP Settings → Enable Custom SMTP**

| Field | Value |
| --- | --- |
| Sender email | `orders@tasteofafricancuisine.com` |
| Sender name | `Taste of African Cuisine` |
| Host | `smtp.resend.com` |
| Port | `465` |
| Username | `resend` |
| Password | a Resend API key |

The username is the literal word `resend` — not an email address. The password
is a Resend API key (`re_…`), which you can make at
resend.com/api-keys with send-only permission. It is the same kind of key the
site already uses; a separate one for Supabase is tidier, because it can be
revoked on its own.

## 2. Paste the templates

**Authentication → Emails → Templates**

| Template | Subject | Body |
| --- | --- | --- |
| Confirm signup | `Confirm your email — Taste of African Cuisine` | `docs/email-templates/confirm-signup.html` |
| Reset password | `Reset your password — Taste of African Cuisine` | `docs/email-templates/reset-password.html` |

Customers and admins both receive the reset template. It is worded so it reads
correctly either way, and the link itself decides where each lands.

Open the file, copy all of it, and paste it over whatever is in the message
body box. Save each one separately.

Leave the other templates (magic link, invite, change email, reauthentication)
alone — nothing in the site or the admin panel triggers them.

### What the templates do

They match the order confirmation emails: the logo on white, the gold rule, the
kente-green heading, the sand footer with the address and phone number. The
palette is copied from `globals.css`, so an email looks like the site the order
came from.

Both use tables and inline styles rather than a stylesheet, because Gmail
strips `<head>`. The logo is hotlinked from Supabase Storage rather than the
site, so it keeps resolving if the domain ever moves.

`{{ .ConfirmationURL }}` is Supabase's — it becomes the real link when the mail
is sent. It appears twice on purpose: once as the button, once as text
underneath, because some mail clients and some corporate scanners will not open
a link that only exists as a button.

## 3. The link has to be allowed to land

Templates are cosmetic. A confirmation link only works if the destination is on
the allow-list:

**Authentication → URL Configuration**

- Site URL: `https://tasteofafricancuisine.com`
- Redirect URLs:
  - `https://tasteofafricancuisine.com/**`
  - `https://www.tasteofafricancuisine.com/**`
  - `https://food-delivery-app-teal-five.vercel.app/**`
  - `https://admin-nine-delta-37.vercel.app/**`

The `/**` matters. The signup code sends people to `/login?confirmed=1` and a
reset sends them to `/reset-password`; without the wildcard Supabase rejects
the path and silently falls back to the Site URL.

**The admin panel's URL has to be on that list too.** Its reset link now points
at its own `/reset-password` page rather than the customer site. Until that
origin is allowed, an admin reset lands back on the customer website instead.

While the Site URL still says `http://localhost:3000`, every confirmation link
sent to a real customer points at their own machine, and their browser says the
server cannot be reached.

## Testing it

Sign up with an address you can read, on the real domain rather than localhost.
Check that the mail arrives from `orders@tasteofafricancuisine.com`, that the
logo loads rather than showing a broken image, and that the button lands on the
login page with the confirmed banner.

Worth doing once from a Gmail address and once from an Outlook or iCloud one —
they render mail differently, and Outlook in particular is the one that breaks
layouts.

Then test a reset from both sides: "Forgot?" on the customer sign-in page, and
the reset link on the admin sign-in form. Each should land on its own
`/reset-password` page with a form, not on a sign-in screen. Clicking the same
link a second time should say the link has expired rather than showing a form
that fails on submit.
