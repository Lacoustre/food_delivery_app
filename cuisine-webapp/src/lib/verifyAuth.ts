import { NextRequest } from 'next/server'
import { supabase } from './supabase'

/**
 * Verifies the caller's Supabase access token from the Authorization
 * header (Supabase's own auth server validates the JWT signature — no
 * separate service-account secret needed, just the anon key). Returns an
 * object with `.uid`/`.email` (matching the shape callers expect), or null
 * if missing/invalid.
 */
export async function verifyAuth(request: NextRequest) {
  const authHeader = request.headers.get('authorization')
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null
  if (!token) return null

  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null

  return { uid: data.user.id, email: data.user.email }
}
