# Clover integration — findings and design

Discovery done 2026-09-11. **No integration code exists yet.** This records
what was established so it does not have to be rediscovered.

## Goal

Website orders push into Clover so the kitchen works from one screen. Payment
stays with Stripe; Clover receives the ticket and the till entry. In-store,
phone and counter payments stay entirely on the Clover POS and do not involve
the website.

## Credentials

In `cuisine-webapp/.env.local`, never committed:

    CLOVER_MERCHANT_ID=08DMZSYQYW6H1
    CLOVER_API_TOKEN=<token named "Website Orders">

Token permissions: Inventory R/W, Merchant R, Orders R/W, Payments R/W.
Payments write is needed to record the external payment, and also allows
refunds — revoke from Settings > API tokens if it ever leaks.

**Two different things are called "Merchant ID".** The API needs the 13-char
alphanumeric one from the dashboard URL (`/m/08DMZSYQYW6H1/`). The 12-digit
number under Settings > Business information is the payment-processing MID and
returns 401 against the API.

Environment: production, `https://api.clover.com`. Verified — the merchant
reads back as Taste of African Cuisine, 200 Hartford Turnpike, Vernon.

## Order types

Six exist, in two sets:

| Label | Id | Source |
|---|---|---|
| Delivery | `F8FDVGPEPQNY4` | online ordering, `hoursAvailable=ALL` |
| In-store Pickup | `AGY2RMBBEFD3T` | online ordering, `hoursAvailable=ALL` |
| Curbside Pickup | `51JVEZVDGBVNE` | online ordering, `hoursAvailable=ALL` |
| Dine In | `FJNJBQ73M6WBW` | online ordering, `hoursAvailable=ALL` |
| TAKE OUT | `1YD3CXV2209MM` | POS native, `BUSINESS` hours, **default** |
| Dine In | `446FPGNN72XCC` | POS native, `BUSINESS` hours |

The two "Dine In" entries are not duplicates — one per set. Do not delete
either.

**Use the online-ordering set.** Website orders then look like the
cloveronline.com orders staff already handle, and `hoursAvailable=ALL` matters
because the site accepts scheduled orders while the restaurant is closed. A
`BUSINESS`-hours type risks rejecting those.

    delivery -> F8FDVGPEPQNY4
    pickup   -> AGY2RMBBEFD3T

Still worth confirming with whoever works the POS that In-store Pickup tickets
land where they will be seen.

## Payment status — the part that must not be got wrong

Website orders are not all paid. Pushing everything as paid is the simple
version and it gives food away:

| Website order | Push as |
|---|---|
| Card (paid via Stripe) | **paid**, tender `com.clover.tender.external_payment` |
| Cash on pickup | **open/unpaid** — staff collect at the counter |

If a cash-pickup order arrives marked paid, the ticket tells staff it is
settled, the food goes over the counter, and no money is taken. Nobody is
stealing; the POS said it was paid.

Cash on delivery does not exist — the site blocks it, because Uber couriers do
not collect cash.

The `External Payment` tender already exists and is enabled on this account.
Using it means Stripe's fee applies instead of Clover's, not that fees vanish.
Check the Fiserv agreement for minimum volume commitments before shifting
volume away from Clover processing.

## Menu

131 items in Clover against 119 unique names on the site. **Zero price
mismatches** where names match.

Most differences are naming, not different food: Clover appends `Item`
(`Fufu Ball Item`) and marks vegetarian variants `(Veg)`. Clover has **no
modifier groups** — each protein variant is its own item, the same shape as
the `base_slug` model, so mapping is one-to-one rather than item-plus-modifier.

An explicit mapping table from meal id to Clover item id will be needed. Draft
it by name similarity, then review by hand — an earlier automatic photo matcher
on this project paired Rice Ball with fried rice.

Two dishes removed from the site are still orderable on Clover:
**Alvaro (Malt Drink)** $3.99 and **Fried Plantain & Tomato Stew (Veg)** $24.99.

## Printing — answered

**Orders print automatically.** Staff confirmed that online orders from
tasteofafrican.cloveronline.com produce a kitchen ticket with nobody tapping
anything. Orders pushed through the API arrive by the same path, so they will
print too. This was the make-or-break question and it came back green.

## Order status — answered, and the answer is no

**Clover has no "ready for pickup" state.** Querying the merchant's real
orders returns only `open` and `locked` — Clover's payment lifecycle, not a
kitchen one. There is nothing for staff to tap when food is ready, which is
why asking them produced no answer.

Consequences:

- Nothing can be read back from Clover to tell a customer their order is ready.
- Customer notifications have to be driven from the admin panel, where someone
  marks the order. The two-way sync described below is not buildable.
- The integration is therefore one-way: orders out to Clover, nothing back.

## Old notes on printing

One printer, type `MY_LOCAL`: the receipt printer built into the Clover
terminal. No separate networked kitchen printer. One routing tag,
`Device Printer`.

Whether an API-created order prints by itself is unverified. The cheap way to
find out: ask whether orders from tasteofafrican.cloveronline.com print
automatically today. Those arrive remotely by the same path, so if they print,
API orders very likely will. If they do not, that is an existing gap affecting
orders already being taken.

This matters because auto-printing is most of the benefit. Without it the
kitchen still has to watch a screen.

## API shape

    POST /v3/merchants/{mId}/orders                    create, with orderType
    POST /v3/merchants/{mId}/orders/{id}/line_items    one per dish
    POST /v3/merchants/{mId}/orders/{id}/payments      only when already paid

Rate limits bite: bulk reads returned 429 during discovery. Back off and retry.

## Where this hangs

The push belongs wherever the Stripe webhook lands — both trigger on "payment
definitely succeeded". Build them together. Nothing here touches the existing
payment path.

---

# Built, and what testing taught us

`cuisine-webapp/src/lib/clover.ts` pushes paid orders into the POS. Called from
`create-order` and from the Stripe webhook, so a rescued order reaches the
kitchen too. It never throws: a POS that is down must not fail an order the
customer has already paid for.

Set `CLOVER_MERCHANT_ID` and `CLOVER_API_TOKEN` in Vercel to switch it on.
Without them it returns "not configured" and does nothing.

## Four things only a real test would have found

**Quantity is one line item per unit.** `unitQty` is for goods sold by weight.
Sending `unitQty: 3` put a single item on the ticket, so a customer ordering
three jollof would have had one made.

**Clover does not recompute the order total** when line items are added through
the API. It stayed at $0.00 while the lines summed correctly, which would have
shown every website order as zero in the POS reports. The total is now set
explicitly — and ours is the authoritative figure anyway, since it includes tax
and delivery, neither of which Clover knows about.

**Rate limits bite immediately.** The first test got a 429 while marking the
order paid, which would have left staff asking a customer for money Stripe had
already taken. Inventory and tenders are now cached for ten minutes and every
call retries with backoff.

**The payments API wants the tender's id, not its labelKey.** Looked up rather
than hardcoded, so it survives the tender being recreated.

## Item matching

About three quarters of the menu matches Clover's inventory by name once
"Item" and "(Veg)" are normalised away, and every match has an identical price.
Unmatched dishes are sent as ad-hoc line items: they print correctly but are
not attributed to an inventory item in Clover's reports. Nothing breaks as the
menus drift.

## Order state

Reaches `locked` once paid, but not instantly — a read immediately after the
push can still say `open`. Do not treat that as a failure.

## Test orders to void

Three test orders are on the POS from building this, each $30 marked paid by
External Payment, all noted TEST-DELETE-ME:

    Y8VNYP6V8F1CY
    7Y8X0T4VEYRDA
    GQ6T7YJKW4DWW

The API cannot delete a paid order. **Void them on the POS**, or they will
count as $90 of revenue that never happened.
