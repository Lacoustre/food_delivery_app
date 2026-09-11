#!/usr/bin/env node
/**
 * Finds Stripe payments that have no matching order in Supabase.
 *
 * Why this exists: the browser confirms the card and THEN calls
 * /api/create-order. If it dies in between — closed tab, dead battery, tunnel —
 * the customer is charged and no order is ever created. The kitchen never sees
 * it and the customer gets nothing. There is no Stripe webhook yet to catch it.
 *
 * Run it at close of business:
 *     node scripts/reconcile-payments.mjs           # last 24h
 *     node scripts/reconcile-payments.mjs --hours 72
 *
 * There is no payment_intent_id column on orders, so matching is by amount and
 * proximity in time rather than a direct join. That is good enough to surface
 * an orphan; it is not an accounting ledger.
 */
import fs from 'node:fs'
import path from 'node:path'

const ROOT = path.resolve(import.meta.dirname, '..')
const ENV = path.join(ROOT, 'cuisine-webapp', '.env.local')

function loadEnv (file) {
  const out = {}
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const m = line.match(/^([A-Z0-9_]+)=(.*)$/)
    if (m) out[m[1]] = m[2].trim()
  }
  return out
}

const hoursArg = process.argv.indexOf('--hours')
const HOURS = hoursArg > -1 ? Number(process.argv[hoursArg + 1]) : 24
// A charge and its order are written seconds apart; 15 minutes is slack enough
// to absorb clock skew without pairing two genuinely different orders.
const WINDOW_MS = 15 * 60 * 1000

const env = loadEnv(ENV)
const since = Math.floor((Date.now() - HOURS * 3600_000) / 1000)

const sk = env.STRIPE_SECRET_KEY
const mode = sk?.startsWith('sk_live') ? 'LIVE' : 'TEST'

const payments = []
let starting_after
do {
  const qs = new URLSearchParams({ limit: '100', 'created[gte]': String(since) })
  if (starting_after) qs.set('starting_after', starting_after)
  const r = await fetch('https://api.stripe.com/v1/payment_intents?' + qs, {
    headers: { Authorization: 'Bearer ' + sk }
  })
  const j = await r.json()
  if (!r.ok) { console.error('Stripe error:', j.error?.message); process.exit(1) }
  payments.push(...j.data.filter(p => p.status === 'succeeded'))
  starting_after = j.has_more ? j.data.at(-1).id : null
} while (starting_after)

const sinceIso = new Date(since * 1000).toISOString()
if (!env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error(`
Missing SUPABASE_SERVICE_ROLE_KEY in cuisine-webapp/.env.local

Reading every order requires the service role key; the anon key is blocked by
row-level security, which is working as intended. Add the line:

    SUPABASE_SERVICE_ROLE_KEY=eyJ...

.env.local is gitignored, so it stays out of the repo. Use the CURRENT key —
if you have rotated it, the old one will fail here too.
`)
  process.exit(1)
}
const H = { apikey: env.SUPABASE_SERVICE_ROLE_KEY, Authorization: 'Bearer ' + env.SUPABASE_SERVICE_ROLE_KEY }
const r = await fetch(
  `${env.NEXT_PUBLIC_SUPABASE_URL}/rest/v1/orders?select=id,order_number,total,created_at,status&created_at=gte.${sinceIso}&limit=1000`,
  { headers: H }
)
if (!r.ok) { console.error('Supabase error:', r.status, (await r.text()).slice(0, 200)); process.exit(1) }
const orders = await r.json()

const used = new Set()
const orphans = []
for (const p of payments) {
  const cents = p.amount
  const at = p.created * 1000
  const hit = orders.find((o, i) =>
    !used.has(i) &&
    Math.round(Number(o.total) * 100) === cents &&
    Math.abs(new Date(o.created_at).getTime() - at) < WINDOW_MS &&
    (used.add(i) || true)
  )
  if (!hit) orphans.push(p)
}

const money = c => '$' + (c / 100).toFixed(2)
console.log(`\nStripe mode: ${mode}   window: last ${HOURS}h`)
console.log(`succeeded payments: ${payments.length}    orders in Supabase: ${orders.length}\n`)

if (!orphans.length) {
  console.log('✓ Every payment has a matching order.\n')
} else {
  console.log(`⚠  ${orphans.length} payment(s) CHARGED WITH NO ORDER:\n`)
  for (const p of orphans) {
    console.log(`   ${money(p.amount)}  ${new Date(p.created * 1000).toISOString()}`)
    console.log(`     ${p.id}`)
    console.log(`     receipt email: ${p.receipt_email || '(none)'}`)
    console.log(`     https://dashboard.stripe.com/${mode === 'TEST' ? 'test/' : ''}payments/${p.id}\n`)
  }
  console.log('   Each of these is a customer who paid and got nothing.')
  console.log('   Refund from the dashboard, or call them and enter the order manually.\n')
  process.exitCode = 1
}
