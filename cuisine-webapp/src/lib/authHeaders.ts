import { supabase } from './supabase'

/**
 * Auth header for calling our own API routes that verify a Supabase access
 * token server-side (see verifyAuth.ts). Empty object if signed out — the
 * route will reject with 401 in that case.
 */
export async function getAuthHeaders(): Promise<Record<string, string>> {
  const { data } = await supabase.auth.getSession()
  const token = data.session?.access_token
  return token ? { Authorization: `Bearer ${token}` } : {}
}
