import { 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword, 
  signOut, 
  onAuthStateChanged,
  User
} from 'firebase/auth'
import { doc, setDoc, getDoc } from 'firebase/firestore'
import { auth, db } from './firebase'
import { getAuthHeaders } from './authHeaders'
import { supabase } from './supabase'

export interface UserProfile {
  uid: string
  email: string
  name: string
  phone?: string
  address?: string
  role?: 'admin' | 'user'
  createdAt: Date
}

export const authService = {
  // Sign up new user
  async signUp(email: string, password: string, name: string): Promise<UserProfile> {
    const userCredential = await createUserWithEmailAndPassword(auth, email, password)
    const user = userCredential.user
    
    const userProfile: UserProfile = {
      uid: user.uid,
      email: user.email!,
      name,
      role: 'user', // Default role
      createdAt: new Date()
    }
    
    await setDoc(doc(db, 'users', user.uid), userProfile)

    // Supabase migration: also create the account + profile row on
    // Supabase, alongside the existing Firebase account. Best-effort so a
    // Supabase hiccup never blocks signup while the rest of the app is
    // still Firebase-backed.
    try {
      const { data: supabaseData } = await supabase.auth.signUp({ email, password })
      if (supabaseData.user) {
        await supabase.from('profiles').upsert({
          id: supabaseData.user.id,
          name,
          email,
          role: 'customer'
        })
      }
    } catch (error) {
      console.error('Supabase signup mirror failed:', error)
    }

    // Send welcome email
    try {
      console.log('Attempting to send welcome email to:', email)
      const response = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
        body: JSON.stringify({
          type: 'welcome',
          welcomeData: {
            customerEmail: email,
            customerName: name
          }
        })
      })
      
      const result = await response.json()
      if (response.ok) {
        console.log('Welcome email sent successfully to:', email)
      } else {
        console.error('Welcome email API error:', result)
      }
    } catch (error) {
      console.error('Failed to send welcome email:', error)
    }
    
    return userProfile
  },

  // Sign in existing user
  async signIn(email: string, password: string): Promise<User> {
    const userCredential = await signInWithEmailAndPassword(auth, email, password)

    // Supabase migration: mirror the session. Best-effort — a Supabase
    // hiccup should never block login on the still-Firebase-backed app.
    try {
      await supabase.auth.signInWithPassword({ email, password })
    } catch (error) {
      console.error('Supabase login mirror failed:', error)
    }

    return userCredential.user
  },

  // Sign out
  async signOut(): Promise<void> {
    await signOut(auth)
    try {
      await supabase.auth.signOut()
    } catch (error) {
      console.error('Supabase sign-out mirror failed:', error)
    }
  },

  // Get user profile
  async getUserProfile(uid: string): Promise<UserProfile | null> {
    try {
      const docRef = doc(db, 'users', uid)
      const docSnap = await getDoc(docRef)
      
      if (docSnap.exists()) {
        return docSnap.data() as UserProfile
      }
      return null
    } catch (error) {
      console.error('Error fetching user profile:', error)
      return null
    }
  },

  // Auth state listener
  onAuthStateChange(callback: (user: User | null) => void) {
    return onAuthStateChanged(auth, callback)
  }
}