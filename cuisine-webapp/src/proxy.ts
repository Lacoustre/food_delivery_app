import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

/**
 * Lets the admin panel talk to this site's API.
 *
 * Next 16 renamed this file convention from middleware to proxy; the job is
 * the same.
 *
 * The panel is a separate deployment on its own origin, so every call it makes
 * here is cross-origin and the browser demands a CORS preflight first. Nothing
 * answered one: OPTIONS returned 204 with no Access-Control headers, so the
 * browser refused to send the request at all and the panel reported "could not
 * reach the site".
 *
 * That silently disabled every admin action that needs this side — status
 * emails, refunds, and clearing a cancelled order's Clover ticket. The refund
 * one mattered most: cancelling an order appeared to work while the customer's
 * card stayed charged.
 *
 * This is not the security boundary. Each route verifies a Supabase access
 * token and checks the caller is an admin; CORS only decides which page a
 * browser will let make the call. The allowlist is here so an arbitrary site
 * cannot make a logged-in admin's browser act on their behalf.
 */
const ALLOWED_ORIGINS = new Set([
  'https://admin-nine-delta-37.vercel.app',
  'http://localhost:5173',
  'http://localhost:4173'
])

function corsHeaders(origin: string) {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Max-Age': '86400',
    // Caches must not serve one origin's response to another.
    Vary: 'Origin'
  }
}

export default function proxy(request: NextRequest) {
  const origin = request.headers.get('origin')
  if (!origin || !ALLOWED_ORIGINS.has(origin)) {
    return NextResponse.next()
  }

  if (request.method === 'OPTIONS') {
    return new NextResponse(null, { status: 204, headers: corsHeaders(origin) })
  }

  const response = NextResponse.next()
  for (const [k, v] of Object.entries(corsHeaders(origin))) {
    response.headers.set(k, v)
  }
  return response
}

export const config = {
  // Only the routes the admin panel calls. The Stripe webhook is server to
  // server and has no origin, so it is untouched either way.
  matcher: [
    '/api/notify-order-status',
    '/api/refund',
    '/api/cancel-clover-order',
    '/api/dispatch-delivery'
  ]
}
