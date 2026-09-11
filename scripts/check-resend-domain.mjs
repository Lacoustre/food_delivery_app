#!/usr/bin/env node
/**
 * Polls Resend until the domain verifies, and shows which records are still
 * missing. Saves refreshing the dashboard while DNS propagates.
 */
import fs from 'node:fs'
import path from 'node:path'

const ENV = path.join(path.resolve(import.meta.dirname, '..'), 'cuisine-webapp', '.env.local')
const env = {}
for (const line of fs.readFileSync(ENV, 'utf8').split('\n')) {
  const m = line.match(/^([A-Z0-9_]+)=(.*)$/)
  if (m) env[m[1]] = m[2].trim()
}

const H = { Authorization: 'Bearer ' + env.RESEND_API_KEY }
const list = await (await fetch('https://api.resend.com/domains', { headers: H })).json()
const domain = list.data?.find(d => d.name === 'tasteofafricancuisine.com')
if (!domain) {
  console.error('tasteofafricancuisine.com is not in this Resend account.')
  process.exit(1)
}

// Ask Resend to re-check DNS now rather than waiting for its own schedule.
await fetch(`https://api.resend.com/domains/${domain.id}/verify`, { method: 'POST', headers: H })
const d = await (await fetch(`https://api.resend.com/domains/${domain.id}`, { headers: H })).json()

console.log(`\n${d.name} — status: ${d.status}\n`)
for (const r of d.records || []) {
  const ok = r.status === 'verified'
  console.log(`  ${ok ? '✓' : '·'} ${String(r.record).padEnd(6)} ${(r.name || '@').padEnd(22)} ${r.status}`)
}

if (d.status === 'verified') {
  console.log('\n✓ Verified. Order confirmation emails will now send.\n')
} else {
  console.log('\nStill pending. DNS usually takes 10-30 minutes; re-run this to check.')
  console.log('Records are listed in docs/resend-dns-setup.md\n')
  process.exitCode = 1
}
