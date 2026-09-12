import { supabase } from './supabase'
import { getAuthHeaders } from './authHeaders'

// Auth is Supabase-only now. AppUser keeps the legacy `uid` field name so
// existing call sites (user.uid) don't need to change.
export interface AppUser {
  uid: string
  email: string | null
}

export interface UserProfile {
  uid: string
  email: string
  name: string
  phone?: string
  address?: string
  photoURL?: string
  role?: 'admin' | 'user'
  createdAt: Date
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function rowToProfile(row: any): UserProfile {
  return {
    uid: row.id,
    email: row.email ?? '',
    name: row.name ?? '',
    phone: row.phone ?? undefined,
    address: row.address ?? undefined,
    photoURL: row.avatar_url ?? undefined,
    role: row.role === 'admin' ? 'admin' : 'user',
    createdAt: row.created_at ? new Date(row.created_at) : new Date(),
  }
}

/**
 * Welcome email. Only ever call this with a live session: /api/send-email
 * verifies a Supabase access token, so calling it unauthenticated is a
 * guaranteed 401 rather than a delivery failure worth retrying.
 */
async function sendWelcomeEmail(email: string, name: string): Promise<void> {
  try {
    const headers = await getAuthHeaders()
    if (!('Authorization' in headers)) return

    const response = await fetch('/api/send-email', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: JSON.stringify({
        type: 'welcome',
        welcomeData: { customerEmail: email, customerName: name },
      }),
    })
    if (!response.ok) {
      console.error('Welcome email failed:', response.status, await response.json().catch(() => null))
    }
  } catch (error) {
    console.error('Welcome email failed:', error)
  }
}

export const authService = {
  // Sign up new user
  async signUp(email: string, password: string, name: string): Promise<UserProfile> {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        // Without this Supabase uses the project's Site URL for the
        // confirmation link, which was still pointing at a development
        // address — every customer clicking it got "server can't be reached".
        // window.location.origin means the link comes back to wherever they
        // actually signed up.
        emailRedirectTo:
          typeof window !== 'undefined'
            ? `${window.location.origin}/login?confirmed=1`
            : undefined,
        // The name has to live here to survive confirmation. With email
        // confirmation on, signup returns no session, so the profile row
        // cannot be written yet and the name was simply lost — the welcome
        // email then greeted people by the part of their address before the @.
        data: { name }
      }
    })
    if (error) throw error
    const user = data.user
    if (!user) throw new Error('Signup failed')

    // Profile row needs a session (RLS); with email confirmation enabled
    // the row gets created on first sign-in instead.
    if (data.session) {
      await supabase.from('profiles').upsert({
        id: user.id,
        name,
        email,
        role: 'customer',
      })
    }

    // Only when signup returned a session. With email confirmation enabled it
    // does not, and first sign-in sends the welcome instead.
    if (data.session) {
      await sendWelcomeEmail(email, name)
    }

    return {
      uid: user.id,
      email,
      name,
      role: 'user',
      createdAt: new Date(),
    }
  },

  // Sign in existing user
  async signIn(email: string, password: string): Promise<AppUser> {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    const user = data.user
    if (!user) throw new Error('Login failed')

    // Ensure the profile row exists — covers accounts whose email was
    // confirmed after signup (signup couldn't create it without a session).
    try {
      const { data: existing } = await supabase
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle()
      if (!existing) {
        // The name was stashed in auth metadata at signup precisely so it
        // would still be here.
        const name =
          (user.user_metadata?.name as string | undefined)?.trim() ||
          email.split('@')[0]
        await supabase.from('profiles').upsert({ id: user.id, name, email, role: 'customer' })
        // First confirmed sign-in — the signup call had no session to send with.
        await sendWelcomeEmail(email, name)
      }
    } catch (e) {
      console.error('Profile ensure failed:', e)
    }

    return { uid: user.id, email: user.email ?? null }
  },

  // Sign out
  async signOut(): Promise<void> {
    await supabase.auth.signOut()
  },

  // Get user profile
  async getUserProfile(uid: string): Promise<UserProfile | null> {
    try {
      const { data } = await supabase.from('profiles').select('*').eq('id', uid).maybeSingle()
      return data ? rowToProfile(data) : null
    } catch (error) {
      console.error('Error fetching user profile:', error)
      return null
    }
  },

  // Update the signed-in user's profile fields
  async updateProfile(fields: { name?: string; phone?: string; address?: string; photoURL?: string }): Promise<void> {
    const { data: userData } = await supabase.auth.getUser()
    if (!userData?.user) throw new Error('Not signed in')
    const { error } = await supabase
      .from('profiles')
      .update({
        ...(fields.name !== undefined && { name: fields.name }),
        ...(fields.phone !== undefined && { phone: fields.phone || null }),
        ...(fields.address !== undefined && { address: fields.address || null }),
        ...(fields.photoURL !== undefined && { avatar_url: fields.photoURL }),
      })
      .eq('id', userData.user.id)
    if (error) throw error
  },

  // Upload a profile photo to the Supabase avatars bucket, returning its URL
  async uploadAvatar(file: File): Promise<string> {
    const { data: userData } = await supabase.auth.getUser()
    if (!userData?.user) throw new Error('Not signed in')
    const path = `${userData.user.id}/profile.jpg`
    const { error } = await supabase.storage.from('avatars').upload(path, file, {
      contentType: file.type || 'image/jpeg',
      upsert: true,
    })
    if (error) throw error
    const { data } = supabase.storage.from('avatars').getPublicUrl(path)
    return `${data.publicUrl}?v=${Date.now()}`
  },

  // Auth state listener
  onAuthStateChange(callback: (user: AppUser | null) => void) {
    const { data } = supabase.auth.onAuthStateChange((_event, session) => {
      callback(session?.user ? { uid: session.user.id, email: session.user.email ?? null } : null)
    })
    return () => data.subscription.unsubscribe()
  }
}
