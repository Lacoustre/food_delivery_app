'use client'

import { createContext, useContext, useEffect, useState } from 'react'
import { User } from 'firebase/auth'
import { authService, UserProfile } from '@/lib/auth'

interface AuthContextType {
  user: User | null
  userProfile: UserProfile | null
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string, name: string) => Promise<void>
  signOut: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const unsubscribe = authService.onAuthStateChange(async (user) => {
      setUser(user)
      
      if (user) {
        try {
          // Store auth token for session recovery
          localStorage.setItem('authToken', 'authenticated')
          const profile = await authService.getUserProfile(user.uid)
          setUserProfile(profile)
          
          // Handle checkout redirect after login
          const checkoutRedirect = localStorage.getItem('checkoutRedirect')
          if (checkoutRedirect === 'true') {
            localStorage.removeItem('checkoutRedirect')
            // Small delay to ensure auth state is fully set
            setTimeout(() => {
              window.location.href = '/checkout'
            }, 100)
          }
        } catch (error) {
          console.error('Error loading user profile:', error)
          // Continue with null profile if there's an error
          setUserProfile(null)
        }
      } else {
        // Clear auth token on sign out
        localStorage.removeItem('authToken')
        setUserProfile(null)
      }
      
      setLoading(false)
    })

    return unsubscribe
  }, [])

  const signIn = async (email: string, password: string) => {
    await authService.signIn(email, password)
  }

  const signUp = async (email: string, password: string, name: string) => {
    await authService.signUp(email, password, name)
  }

  const signOut = async () => {
    await authService.signOut()
  }

  return (
    <AuthContext.Provider value={{
      user,
      userProfile,
      loading,
      signIn,
      signUp,
      signOut
    }}>
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}