'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'
import { authService } from '@/lib/auth'
import { supabase } from '@/lib/supabase'
import { Eye, EyeOff, Lock, CheckCircle2, ArrowRight } from 'lucide-react'

/**
 * Where the emailed reset link lands.
 *
 * The link arrives carrying tokens in the URL fragment. supabase-js reads them
 * on load, turns them into a real session and strips the fragment, which is
 * what lets updateUser change the password without the old one. That happens
 * asynchronously and may well finish before this component mounts, so the
 * session is looked for in two ways — asked for directly, and waited for — and
 * only declared missing after both have had a chance.
 */
type Phase = 'checking' | 'ready' | 'invalid' | 'done'

// Expired and already-used links come back as an error in the same fragment,
// so read it before supabase-js clears it.
function fragmentError(): string | null {
  if (typeof window === 'undefined') return null
  const params = new URLSearchParams(window.location.hash.replace(/^#/, ''))
  if (!params.get('error')) return null
  return params.get('error_code') === 'otp_expired'
    ? 'That link has expired. Reset links are only good for a short while.'
    : params.get('error_description')?.replace(/\+/g, ' ') ||
        'That link is no longer valid.'
}

export default function ResetPasswordPage() {
  const [phase, setPhase] = useState<Phase>('checking')
  const [linkError, setLinkError] = useState<string | null>(null)
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const router = useRouter()
  const settled = useRef(false)

  useEffect(() => {
    const fromFragment = fragmentError()
    if (fromFragment) {
      settled.current = true
      setLinkError(fromFragment)
      setPhase('invalid')
      return
    }

    const ready = () => {
      if (settled.current) return
      settled.current = true
      setPhase('ready')
    }

    supabase.auth.getSession().then(({ data }) => {
      if (data.session) ready()
    })

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) ready()
    })

    // Nothing arrived: the link was opened twice, has expired, or somebody
    // reached this page without one. Say so rather than showing a form that
    // cannot work.
    const timer = setTimeout(() => {
      if (!settled.current) {
        settled.current = true
        setPhase('invalid')
      }
    }, 4000)

    return () => {
      clearTimeout(timer)
      listener.subscription.unsubscribe()
    }
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')

    if (password.length < 6) {
      setError('Password must be at least 6 characters')
      return
    }

    setSaving(true)
    try {
      await authService.updatePassword(password)
      setPhase('done')
    } catch (err: any) {
      setError(err?.message || 'Could not set your password. Please try again.')
    } finally {
      setSaving(false)
    }
  }

  const shell = (inner: React.ReactNode) => (
    <div className="min-h-screen bg-sand-100 flex items-center justify-center px-4 py-10">
      <div className="relative max-w-md w-full">
        <div className="bg-white/80 backdrop-blur-lg rounded-card shadow-2xl p-8 border border-white/20">
          {inner}
        </div>
      </div>
    </div>
  )

  if (phase === 'checking') {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-sand-300 border-t-gold rounded-full animate-spin" />
      </div>
    )
  }

  if (phase === 'invalid') {
    return shell(
      <div className="text-center">
        <h1 className="font-display text-2xl text-ink mb-3">This link has expired</h1>
        <p className="text-sand-700 leading-relaxed mb-6">
          {linkError ||
            'Reset links can only be used once, and not long after they are sent. Ask for a fresh one and it will work.'}
        </p>
        <Link
          href="/forgot-password"
          className="inline-block w-full bg-gold text-white py-3.5 rounded-control font-semibold hover:bg-gold-600 transition-colors"
        >
          Send a new link
        </Link>
        <p className="text-sand-500 text-sm mt-5">
          <Link href="/login" className="text-clay underline">
            Back to sign in
          </Link>
        </p>
      </div>
    )
  }

  if (phase === 'done') {
    return shell(
      <div className="text-center">
        <CheckCircle2 className="w-10 h-10 text-kente mx-auto mb-4" />
        <h1 className="font-display text-2xl text-ink mb-3">Password changed</h1>
        <p className="text-sand-700 leading-relaxed mb-6">
          You&rsquo;re signed in and ready to order.
        </p>
        <button
          onClick={() => router.push('/')}
          className="w-full bg-gold text-white py-3.5 rounded-control font-semibold hover:bg-gold-600 transition-colors"
        >
          Start ordering
        </button>
      </div>
    )
  }

  return shell(
    <>
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
        <h1 className="font-display text-3xl text-ink mb-2">Set a new password</h1>
        <p className="text-sand-700">Choose something you&rsquo;ll remember.</p>
      </div>

      {error && (
        <div className="mb-6 p-4 bg-clay-50 border border-clay-50 text-clay rounded-xl">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label className="block text-sm font-semibold text-sand-700 mb-3">
            New Password
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
              placeholder="At least 6 characters"
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
          disabled={saving}
          className="w-full bg-gold text-white py-4 rounded-xl font-semibold hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
        >
          {saving ? (
            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
          ) : (
            <>
              Save password
              <ArrowRight className="w-5 h-5" />
            </>
          )}
        </button>
      </form>
    </>
  )
}
