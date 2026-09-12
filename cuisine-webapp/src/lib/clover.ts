/**
 * Pushes a paid website order into the Clover POS so the kitchen works from
 * one screen.
 *
 * One way only. Clover's orders carry open/locked/paid — a payment lifecycle
 * with no notion of food being ready — so there is nothing useful to read back
 * and customer notifications stay in the admin panel.
 *
 * Tickets print by themselves: staff confirmed that orders arriving from the
 * hosted ordering page produce a kitchen ticket with nobody tapping anything,
 * and these arrive by the same path.
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

async function inventoryByName(
  cfg: NonNullable<ReturnType<typeof config>>
): Promise<Map<string, string>> {
  const map = new Map<string, string>()
  try {
    const res = await fetch(`${cfg.url}/items?limit=500`, { headers: cfg.headers })
    if (!res.ok) return map
    const body = await res.json()
    for (const item of body.elements ?? []) {
      const key = normalise(item.name ?? '')
      if (key && !map.has(key)) map.set(key, item.id)
    }
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

    const createRes = await fetch(`${cfg.url}/orders`, {
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

    // Sequential on purpose: Clover rate-limits hard, and a 429 halfway
    // through would leave a ticket missing dishes.
    for (const line of order.items) {
      const itemId = inventory.get(normalise(line.name))
      if (itemId) matched++

      const body = itemId
        ? { item: { id: itemId }, unitQty: line.quantity }
        : {
            name: line.name,
            price: Math.round(line.unitPrice * 100),
            unitQty: line.quantity
          }

      const lineRes = await fetch(`${cfg.url}/orders/${cloverOrder.id}/line_items`, {
        method: 'POST',
        headers: cfg.headers,
        body: JSON.stringify(body)
      })

      if (!lineRes.ok) {
        console.error(
          `Clover line item failed for "${line.name}" on ${cloverOrder.id}: ${lineRes.status}`
        )
      }
    }

    // Mark it paid, so nobody at the counter tries to collect money Stripe
    // already took. A cash pickup order is deliberately left open.
    if (order.paid) {
      const payRes = await fetch(`${cfg.url}/orders/${cloverOrder.id}/payments`, {
        method: 'POST',
        headers: cfg.headers,
        body: JSON.stringify({
          amount: Math.round(order.total * 100),
          tender: { labelKey: EXTERNAL_PAYMENT },
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

    return {
      ok: true,
      cloverOrderId: cloverOrder.id,
      matchedItems: matched,
      totalItems: order.items.length
    }
  } catch (err) {
    return {
      ok: false,
      error: err instanceof Error ? err.message : 'Clover push failed'
    }
  }
}
