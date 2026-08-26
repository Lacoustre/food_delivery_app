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
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  
  const { signUp } = useAuth()
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    if (password !== confirmPassword) {
      setError('Passwords do not match')
      setLoading(false)
      return
    }

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      setLoading(false)
      return
    }

    try {
      await signUp(email, password, name)
      router.push('/')
    } catch (error: any) {
      setError(error.message || 'Failed to create account')
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
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                  className="w-full pl-12 pr-4 py-5 border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
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
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full pl-12 pr-4 py-5 border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
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
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full pl-12 pr-12 py-5 border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
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

            <div>
              <label className="block text-sm font-semibold text-sand-700 mb-3">
                Confirm Password
              </label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gold" />
                <input
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  className="w-full pl-12 pr-4 py-5 border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Confirm your password"
                />
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