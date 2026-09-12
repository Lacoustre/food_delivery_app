'use client'

import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { authService } from '@/lib/auth'
import { Mail, ArrowRight } from 'lucide-react'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [sentTo, setSentTo] = useState<string | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await authService.requestPasswordReset(email)
      setSentTo(email)
    } catch (err: any) {
      // Only genuine failures land here — a wrong address is not one of them,
      // because Supabase deliberately does not say whether an account exists.
      setError(err?.message || 'Could not send the link. Please try again.')
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
            If there&rsquo;s an account for
          </p>
          <p className="font-semibold text-ink break-all mb-5">{sentTo}</p>
          <p className="text-sand-700 text-sm leading-relaxed mb-6">
            we&rsquo;ve sent it a link to set a new password. If it isn&rsquo;t
            there in a minute, check your spam folder.
          </p>
          <Link
            href="/login"
            className="inline-block w-full bg-gold text-white py-3.5 rounded-control font-semibold hover:bg-gold-600 transition-colors"
          >
            Back to sign in
          </Link>
          <p className="text-sand-500 text-xs mt-5">
            Wrong address?{' '}
            <button onClick={() => setSentTo(null)} className="text-clay underline">
              Try another
            </button>
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-sand-100 flex items-center justify-center px-4 py-10">
      <div className="relative max-w-md w-full">
        <div className="bg-white/80 backdrop-blur-lg rounded-card shadow-2xl p-8 border border-white/20">
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
            <h1 className="font-display text-3xl text-ink mb-2">Forgot your password?</h1>
            <p className="text-sand-700">
              Enter your email and we&rsquo;ll send you a link to set a new one.
            </p>
          </div>

          {error && (
            <div className="mb-6 p-4 bg-clay-50 border border-clay-50 text-clay rounded-xl">
              {error}
            </div>
          )}

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
                  className="w-full pl-12 pr-4 py-4 text-base border border-sand-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none transition-all bg-white backdrop-blur text-ink placeholder-gray-500"
                  placeholder="Enter your email"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gold text-white py-4 rounded-xl font-semibold hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <>
                  Send reset link
                  <ArrowRight className="w-5 h-5" />
                </>
              )}
            </button>
          </form>

          <div className="text-center mt-8">
            <Link
              href="/login"
              className="text-gold-600 hover:text-gold-600 font-semibold transition-colors"
            >
              Back to sign in
            </Link>
          </div>
        </div>
      </div>
    </div>
  )
}
