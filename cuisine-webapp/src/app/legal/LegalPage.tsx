import Link from 'next/link'
import type { ReactNode } from 'react'

/**
 * Shared shell for the privacy, terms and refund pages.
 *
 * Deliberately plain: these exist to be read and to satisfy Stripe, not to be
 * designed. Anything that makes them harder to scan makes them worse.
 */
export function LegalPage({
  title,
  updated,
  children
}: {
  title: string
  updated: string
  children: ReactNode
}) {
  return (
    <main className="min-h-screen bg-sand-50">
      <header className="bg-kente text-sand-50">
        <div className="page-shell py-10">
          <Link
            href="/"
            className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-300 hover:text-gold-200"
          >
            &larr; Taste of African Cuisine
          </Link>
          <h1 className="font-display text-4xl sm:text-5xl mt-3">{title}</h1>
          <p className="text-sand-300 text-sm mt-2">Last updated {updated}</p>
        </div>
      </header>

      <div className="page-shell-narrow py-12">
        <div className="legal-body text-ink">{children}</div>

        <div className="mt-14 pt-8 border-t border-sand-200 text-sm text-sand-700">
          <p className="mb-2">
            Questions about any of this? Email{' '}
            <a className="text-clay underline" href="mailto:orders@tasteofafricancuisine.com">
              orders@tasteofafricancuisine.com
            </a>{' '}
            or call{' '}
            <a className="text-clay underline" href="tel:+18608055121">
              (860) 805-5121
            </a>
            .
          </p>
          <p className="flex flex-wrap gap-x-5 gap-y-1 mt-4">
            <Link href="/privacy" className="text-clay underline">Privacy</Link>
            <Link href="/terms" className="text-clay underline">Terms</Link>
            <Link href="/refunds" className="text-clay underline">Refunds &amp; cancellations</Link>
          </p>
        </div>
      </div>
    </main>
  )
}
