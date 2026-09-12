/**
 * Pushes a paid website order into the Clover POS so the kitchen works from
 * one screen.
 *
 * One way only. Clover's orders carry open/locked/paid — a payment lifecycle
 * with no notion of food being ready — so there is nothing useful to read back
 * and customer notifications stay in the admin panel.
 *
 * Tickets do not print by themselves. That was assumed when this was written —
 * on the basis that orders from Clover's own hosted ordering page print with
 * nobody tapping anything — and it is wrong for orders created through the
 * API. They appear on the Clover screen and sit there. A print event has to be
 * asked for explicitly, which is what printCloverOrder does.
 *
 * Never throws. A POS that is unreachable must not fail an order the customer
 * has already paid for — the order exists in Supabase either way, and the
 * admin panel still shows it.
 */

const BASE = 'https://api.clover.com/v3/merchants'

// From the online-ordering set rather than the POS-native one: website orders
// then look like the cloveronline orders staff already handle, and these
// accept orders at any hour, which matters because the site takes scheduled
// orders while the restaurant is closed.
const ORDER_TYPE = {
  delivery: 'F8FDVGPEPQNY4',
  pickup: 'AGY2RMBBEFD3T'
} as const

// Already enabled on the merchant. Marks an order paid without the money
// passing through Clover, since Stripe has already taken it.
const EXTERNAL_PAYMENT = 'com.clover.tender.external_payment'

export interface CloverLineItem {
  name: string
  quantity: number
  /** Dollars. Converted to cents here. */
  unitPrice: number
}

export interface CloverOrderInput {
  orderNumber: string
  orderType: 'delivery' | 'pickup'
  items: CloverLineItem[]
  /** Dollars, including tax and any delivery fee. */
  total: number
  /** Card orders are already paid. Cash pickup orders are not. */
  paid: boolean
  customerName?: string
  customerPhone?: string
  deliveryAddress?: string
  note?: string
}

/**
 * Clover rate-limits aggressively. A 429 partway through a push leaves a
 * ticket missing dishes, or — worse — created but not marked paid, so staff
 * ask a customer for money Stripe already took. Retry with backoff.
 */
async function cloverFetch(
  url: string,
  init: RequestInit,
  attempts = 4
): Promise<Response> {
  let res = await fetch(url, init)
  for (let i = 1; i < attempts && res.status === 429; i++) {
    await new Promise(r => setTimeout(r, 500 * 2 ** i))
    res = await fetch(url, init)
  }
  return res
}

// Inventory and tenders change rarely but were fetched on every single order —
// 500 items each time, most of the rate budget spent before the order is even
// created. Cached per warm instance.
const CACHE_TTL_MS = 10 * 60 * 1000
let inventoryCache: { at: number; map: Map<string, string> } | null = null
let tenderCache: { at: number; id: string | null } | null = null

function config() {
  const merchantId = process.env.CLOVER_MERCHANT_ID
  const token = process.env.CLOVER_API_TOKEN
  if (!merchantId || !token) return null
  return {
    url: `${BASE}/${merchantId}`,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  }
}

/**
 * Clover's inventory names differ from ours — it appends "Item" and marks
 * vegetarian "(Veg)" — so names are normalised before comparing. About three
 * quarters match; the rest are sent as ad-hoc line items, which print
 * correctly but are not attributed to an inventory item in Clover's reports.
 */
function normalise(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s*\(veg(etarian)?\)\s*/g, ' vegetarian ')
    .replace(/\s+item\s*$/, ' ')
    .replace(/\s+item\s/g, ' ')
    .replace(/&/g, 'and')
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/**
 * The payments API wants the tender's id, not its labelKey. Looked up rather
 * than hardcoded so it survives the tender being recreated.
 */
async function externalPaymentTenderId(
  cfg: NonNullable<ReturnType<typeof config>>
): Promise<string | null> {
  if (tenderCache && Date.now() - tenderCache.at < CACHE_TTL_MS) return tenderCache.id
  try {
    const res = await cloverFetch(`${cfg.url}/tenders`, { headers: cfg.headers })
    if (!res.ok) return null
    const body = await res.json()
    const tender = (body.elements ?? []).find(
      (t: { labelKey?: string; enabled?: boolean }) =>
        t.labelKey === EXTERNAL_PAYMENT && t.enabled !== false
    )
    tenderCache = { at: Date.now(), id: tender?.id ?? null }
    return tenderCache.id
  } catch {
    return null
  }
}

async function inventoryByName(
  cfg: NonNullable<ReturnType<typeof config>>
): Promise<Map<string, string>> {
  if (inventoryCache && Date.now() - inventoryCache.at < CACHE_TTL_MS) {
    return inventoryCache.map
  }
  const map = new Map<string, string>()
  try {
    const res = await cloverFetch(`${cfg.url}/items?limit=500`, { headers: cfg.headers })
    if (!res.ok) return map
    const body = await res.json()
    for (const item of body.elements ?? []) {
      const key = normalise(item.name ?? '')
      if (key && !map.has(key)) map.set(key, item.id)
    }
    inventoryCache = { at: Date.now(), map }
  } catch {
    // An empty map just means every line is sent ad-hoc.
  }
  return map
}

export interface CloverPushResult {
  ok: boolean
  cloverOrderId?: string
  matchedItems?: number
  totalItems?: number
  /** Whether a print event was accepted. The ticket is on screen either way. */
  printed?: boolean
  error?: string
}

export async function pushOrderToClover(
  order: CloverOrderInput
): Promise<CloverPushResult> {
  const cfg = config()
  if (!cfg) {
    return { ok: false, error: 'Clover is not configured' }
  }

  try {
    const inventory = await inventoryByName(cfg)

    const noteParts = [
      `Website order #${order.orderNumber}`,
      order.customerName,
      order.customerPhone,
      order.deliveryAddress,
      order.note
    ].filter(Boolean)

    const createRes = await cloverFetch(`${cfg.url}/orders`, {
      method: 'POST',
      headers: cfg.headers,
      body: JSON.stringify({
        state: 'open',
        orderType: { id: ORDER_TYPE[order.orderType] },
        // Everything the counter needs is here, because a Clover order has no
        // field for a delivery address or a customer phone number.
        note: noteParts.join(' · ')
      })
    })

    if (!createRes.ok) {
      return {
        ok: false,
        error: `Clover order create failed: ${createRes.status} ${(await createRes.text()).slice(0, 200)}`
      }
    }

    const cloverOrder = await createRes.json()
    let matched = 0

    // Clover expresses quantity as one line item per unit — unitQty is for
    // goods sold by weight. Sending unitQty: 3 put a single item on the ticket
    // and the kitchen would have made one of three.
    //
    // Sequential on purpose: Clover rate-limits hard, and a 429 halfway
    // through would leave a ticket missing dishes.
    for (const line of order.items) {
      const itemId = inventory.get(normalise(line.name))
      if (itemId) matched++

      // The price is always sent, including for matched inventory items. If
      // Clover's price has drifted from ours, the customer pays what our site
      // quoted, not what the POS happens to hold.
      const body = itemId
        ? { item: { id: itemId }, price: Math.round(line.unitPrice * 100) }
        : { name: line.name, price: Math.round(line.unitPrice * 100) }

      for (let n = 0; n < line.quantity; n++) {
        const lineRes = await cloverFetch(`${cfg.url}/orders/${cloverOrder.id}/line_items`, {
          method: 'POST',
          headers: cfg.headers,
          body: JSON.stringify(body)
        })

        if (!lineRes.ok) {
          console.error(
            `Clover line item failed for "${line.name}" (${n + 1} of ${line.quantity}) on ${cloverOrder.id}: ${lineRes.status}`
          )
        }
      }
    }

    // Clover does not recompute an order's total when line items are added
    // through the API — it stayed at $0.00 while the lines summed correctly,
    // which would have shown every website order as zero in the POS reports.
    // Our total is the authoritative one anyway: it includes tax and any
    // delivery fee, neither of which Clover knows about.
    const totalRes = await cloverFetch(`${cfg.url}/orders/${cloverOrder.id}`, {
      method: 'POST',
      headers: cfg.headers,
      body: JSON.stringify({ total: Math.round(order.total * 100) })
    })
    if (!totalRes.ok) {
      console.error(
        `Clover order ${cloverOrder.id} total not set: ${totalRes.status} — it will report as $0`
      )
    }

    // Mark it paid, so nobody at the counter tries to collect money Stripe
    // already took. A cash pickup order is deliberately left open.
    if (order.paid) {
      const tenderId = await externalPaymentTenderId(cfg)
      const payRes = await cloverFetch(`${cfg.url}/orders/${cloverOrder.id}/payments`, {
        method: 'POST',
        headers: cfg.headers,
        body: JSON.stringify({
          amount: Math.round(order.total * 100),
          tender: tenderId ? { id: tenderId } : { labelKey: EXTERNAL_PAYMENT },
          externalPaymentId: `web-${order.orderNumber}`
        })
      })

      if (!payRes.ok) {
        // The ticket is in the kitchen, which is the important half. Say
        // loudly that it shows as unpaid, because staff will ask for money.
        console.error(
          `Clover order ${cloverOrder.id} created but NOT marked paid: ${payRes.status} ${(await payRes.text()).slice(0, 200)}`
        )
        return {
          ok: true,
          cloverOrderId: cloverOrder.id,
          matchedItems: matched,
          totalItems: order.items.length,
          error: 'created but not marked paid'
        }
      }
    }

    // Last, so the ticket that prints is the finished one: all line items, the
    // total set, and the payment recorded. Printing earlier would put a
    // half-built order in the kitchen's hands.
    const printed = await printCloverOrder(cloverOrder.id)
    if (!printed.ok) {
      console.error(`Clover order ${cloverOrder.id} did not print: ${printed.error}`)
    }

    return {
      ok: true,
      cloverOrderId: cloverOrder.id,
      matchedItems: matched,
      totalItems: order.items.length,
      printed: printed.ok
    }
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : 'Clover push failed'
    }
  }
}


/**
 * Removes a ticket from the POS when the order is cancelled.
 *
 * Without this, cancelling in the admin panel left the ticket open on Clover
 * and staff could still cook food that nobody was going to collect or pay for.
 *
 * Clover will delete an order that has no payment against it. One that has
 * been marked paid cannot be deleted through the API — the money has to be
 * reversed on the POS — so those are left alone and reported, rather than
 * failing silently and letting the admin panel claim success.
 */
export async function cancelCloverOrder(
  cloverOrderId: string
): Promise<{ ok: boolean; error?: string; needsManualVoid?: boolean }> {
  const cfg = config()
  if (!cfg) return { ok: false, error: 'Clover is not configured' }

  try {
    const res = await cloverFetch(`${cfg.url}/orders/${cloverOrderId}`, {
      headers: cfg.headers
    })

    // Already gone. Cancelling twice must not look like a failure.
    if (res.status === 404) return { ok: true }
    if (!res.ok) {
      return { ok: false, error: `Could not read Clover order: ${res.status}` }
    }

    const order = await res.json()
    const payments = (order.payments?.elements ?? order.payments ?? []) as unknown[]
    if (Array.isArray(payments) && payments.length > 0) {
      return {
        ok: false,
        needsManualVoid: true,
        error: 'This ticket has a payment against it and must be voided on the Clover terminal.'
      }
    }

    const del = await cloverFetch(`${cfg.url}/orders/${cloverOrderId}`, {
      method: 'DELETE',
      headers: cfg.headers
    })
    if (!del.ok && del.status !== 404) {
      return { ok: false, error: `Clover delete failed: ${del.status} ${(await del.text()).slice(0, 200)}` }
    }
    return { ok: true }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Clover cancel failed' }
  }
}


/**
 * Asks Clover to print the ticket.
 *
 * An order created through the API shows up on the Clover screen but never
 * reaches the printer on its own, so the kitchen only sees it if somebody is
 * watching the screen. This queues a print event, which the merchant's own
 * printer picks up.
 *
 * Never throws. A printer that is offline or out of paper must not fail an
 * order — the ticket is on screen, the order is in Supabase, and the
 * restaurant also gets an email.
 */
export async function printCloverOrder(
  cloverOrderId: string
): Promise<{ ok: boolean; error?: string }> {
  const cfg = config()
  if (!cfg) return { ok: false, error: 'Clover is not configured' }

  try {
    const res = await cloverFetch(`${cfg.url}/print_event`, {
      method: 'POST',
      headers: cfg.headers,
      body: JSON.stringify({ orderRef: { id: cloverOrderId } })
    })

    if (!res.ok) {
      return {
        ok: false,
        error: `Clover print failed: ${res.status} ${(await res.text()).slice(0, 200)}`
      }
    }
    return { ok: true }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Clover print failed' }
  }
}
