'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { useAuth } from '@/lib/AuthContext'
import { Eye, EyeOff, Mail, Lock, User, ArrowRight } from 'lucide-react'

export default function RegisterPage() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  // Signing up used to redirect straight to the homepage, so nobody knew a
  // confirmation email was waiting or that the account was not usable yet.
  const [sentTo, setSentTo] = useState<string | null>(null)
  
  const { signUp } = useAuth()
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      setLoading(false)
      return
    }

    try {
      await signUp(email, password, name)
      setSentTo(email)
    } catch (error: any) {
      setError(error.message || 'Failed to create account')
    } finally {
      setLoading(false)
    }
  }

  if (sentTo) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center px-4 py-10">
        <div className="max-w-md w-full bg-white rounded-card shadow-card border border-sand-200 p-8 text-center">
          <Mail className="w-10 h-10 text-gold mx-auto mb-4" />
          <h1 className="font-display text-2xl text-ink mb-3">Check your email</h1>
          <p className="text-sand-700 leading-relaxed mb-2">
            We&rsquo;ve sent a confirmation link to
          </p>
          <p className="font-semibold text-ink break-all mb-5">{sentTo}</p>
          <p className="text-sand-700 text-sm leading-relaxed mb-6">
            Click it and you can start ordering. If it isn&rsquo;t there in a
            minute, check your spam folder.
          </p>
          <Link
            href="/login"
            className="inline-block w-full bg-gold text-white py-3.5 rounded-control font-semibold hover:bg-gold-600 transition-colors"
          >
            Go to sign in
          </Link>
          <p className="text-sand-500 text-xs mt-5">
            Wrong address?{' '}
            <button onClick={() => setSentTo(null)} className="text-clay underline">
              Sign up again
            </button>
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-sand-100 flex items-center justify-center px-4 py-10">
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
            <h1 className="font-display text-3xl text-ink mb-2">Join Us Today!</h1>
            <p className="text-sand-700">Create your account to start ordering</p>
          </div>

          {/* Error Message */}
          {error && (
            <div className="mb-6 p-4 bg-clay-50 border border-clay-50 text-clay rounded-xl">
              {error}
            </div>
          )}

          {/* Register Form */}
          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-semibold text-sand-700 mb-3">
                Full Name
              </label>
              <div className="relative">
                <User className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gold" />
                <input
                  type="text"
                  autoComplete="name"
                  autoCapitalize="words"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  className="w-full pl-12 pr-4 py-4 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Enter your full name"
                />
              </div>
            </div>

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
                  className="w-full pl-12 pr-4 py-4 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Enter your email"
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-semibold text-sand-700 mb-3">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gold" />
                <input
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="new-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full pl-12 pr-12 py-4 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Create a password"
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
                  Create Account
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

          {/* Sign In Link */}
          <div className="text-center">
            <p className="text-sand-700 mb-4">
              Already have an account?
            </p>
            <Link
              href="/login"
              className="inline-flex items-center gap-2 text-gold-600 hover:text-gold-600 font-semibold transition-colors"
            >
              Sign In
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