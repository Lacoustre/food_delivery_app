'use client'

import { useState, useEffect, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { useAuth } from '@/lib/AuthContext'
import { Eye, EyeOff, Mail, Lock, ArrowRight } from 'lucide-react'

function LoginContent() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  
  const { signIn } = useAuth()
  const router = useRouter()
  const searchParams = useSearchParams()
  const redirectTo = searchParams.get('redirect')
  // Arriving from the confirmation link. Without this the customer clicks the
  // link, lands on a plain sign-in form, and has no idea whether it worked.
  const justConfirmed = searchParams.get('confirmed') === '1'

  useEffect(() => {
    // Store redirect info for after login
    if (redirectTo === 'checkout') {
      localStorage.setItem('checkoutRedirect', 'true')
    }
  }, [redirectTo])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await signIn(email, password)
      
      // Redirect based on parameter or default to home
      if (redirectTo === 'checkout') {
        // AuthContext will handle the redirect
        return
      } else {
        router.push('/')
      }
    } catch (error: any) {
      setError(error.message || 'Failed to sign in')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-sand-100 flex items-center justify-center px-4">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-5">
      </div>

      <div className="relative max-w-md w-full">
        {/* Main Card */}
        <div className="bg-white/80 backdrop-blur-lg rounded-card shadow-2xl p-8 border border-white/20">
          {/* Logo & Header */}
          <div className="text-center mb-8">
            <div className="relative mx-auto w-20 h-20 mb-6">
              <Image
                src="/assets/images/logo.png"
                alt="Logo"
                fill
                className="object-contain"
                unoptimized
              />
            </div>
            <h1 className="font-display text-3xl text-ink mb-2">Welcome Back!</h1>
            <p className="text-sand-700">Sign in to order delicious African cuisine</p>
          </div>

          {justConfirmed && !error && (
            <div className="mb-6 p-4 bg-sand-100 border border-kente/20 text-kente rounded-xl text-sm">
              Your email is confirmed. Sign in and you can order.
            </div>
          )}

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 bg-clay-50 border border-clay-50 text-clay rounded-xl">
              {error}
            </div>
          )}

          {/* Login Form */}
          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-semibold text-sand-700 mb-3">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gold" />
                <input
                  type="email"
                  inputMode="email"
                  autoComplete="email"
                  autoCapitalize="none"
                  autoCorrect="off"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full pl-12 pr-4 py-5 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Enter your email"
                />
              </div>
            </div>

            <div>
              <div className="flex items-baseline justify-between mb-3">
                <label className="block text-sm font-semibold text-sand-700">
                  Password
                </label>
                <Link
                  href="/forgot-password"
                  className="text-sm text-clay hover:underline"
                >
                  Forgot?
                </Link>
              </div>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gold" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full pl-12 pr-12 py-5 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Enter your password"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-1/2 transform -translate-y-1/2 text-sand-500 hover:text-sand-700 transition-colors"
                >
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gold text-white py-4 rounded-xl font-semibold hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  Sign In
                  <ArrowRight className="w-5 h-5" />
                </>
              )}
            </button>
          </form>

          {/* Divider */}
          <div className="my-8 flex items-center">
            <div className="flex-1 border-t border-sand-200"></div>
            <span className="px-4 text-sm text-sand-500 bg-white rounded-full">or</span>
            <div className="flex-1 border-t border-sand-200"></div>
          </div>

          {/* Sign Up Link */}
          <div className="text-center">
            <p className="text-sand-700 mb-4">
              Don't have an account?
            </p>
            <Link
              href="/register"
              className="inline-flex items-center gap-2 text-gold-600 hover:text-gold-600 font-semibold transition-colors"
            >
              Create Account
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
        </div>

        {/* Back to Home */}
        <div className="mt-6 text-center">
          <Link href="/" className="text-sand-500 hover:text-sand-700 text-sm transition-colors">
            ← Back to Home
          </Link>
        </div>
      </div>
    </div>
  )
}

export default function LoginPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-sand-50 flex items-center justify-center">
          <div className="w-8 h-8 border-2 border-sand-300 border-t-gold rounded-full animate-spin" />
        </div>
      }
    >
      <LoginContent />
    </Suspense>
  )
}
