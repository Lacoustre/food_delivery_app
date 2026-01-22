import { 
  signInWithEmailAndPassword, 
  createUserWithEmailAndPassword, 
  signOut, 
  onAuthStateChanged,
  User
} from 'firebase/auth'
import { doc, setDoc, getDoc } from 'firebase/firestore'
import { auth, db } from './firebase'

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
    
    // Send welcome email
    try {
      console.log('Attempting to send welcome email to:', email)
      const response = await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
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
    return userCredential.user
  },

  // Sign out
  async signOut(): Promise<void> {
    await signOut(auth)
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