import Link from 'next/link'
import Image from 'next/image'
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
      {/* Plain, on the page's own background. It was a solid green banner,
          which read as heavier than pages meant simply to be read. The header
          now shares the text column's width, so the title lines up with the
          text beneath it instead of starting further left. */}
      <header className="border-b border-sand-200">
        <div className="page-shell-narrow py-10">
          {/* The logo carries the brand the green banner used to, and takes you
              home the way the logo does everywhere else on the site. */}
          <Link href="/" className="group inline-flex items-center gap-3" aria-label="Taste of African Cuisine — home">
            <Image
              src="/assets/images/logo.png"
              alt=""
              width={48}
              height={48}
              className="object-contain"
              unoptimized
            />
            <span className="font-display text-lg text-ink leading-tight group-hover:text-gold-600 transition-colors">
              Taste of African Cuisine
            </span>
          </Link>
          <h1 className="font-display text-4xl sm:text-5xl text-ink mt-6">{title}</h1>
          <p className="text-sand-500 text-sm mt-2">Last updated {updated}</p>
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
