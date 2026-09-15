import { ImageResponse } from 'next/og'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'

/**
 * The card that appears when someone shares the link — in Messages, WhatsApp,
 * Facebook, Slack. Without one, those all show a bare URL, which looks like
 * spam and gets clicked less.
 *
 * The logo on the site's cream background. It was a solid kente-green card,
 * which the restaurant didn't like — the same reaction as to the green banner
 * the legal pages used to carry — and the logo is what people recognise.
 * Drawn at 1200x630, because anything smaller is shown as a small square
 * thumbnail instead of a banner.
 */
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'
export const alt = 'Taste of African Cuisine — Authentic African cooking in Vernon, Connecticut'

export default async function OpengraphImage() {
  const logo = await readFile(join(process.cwd(), 'public/assets/images/logo.png'))
  const logoSrc = `data:image/png;base64,${logo.toString('base64')}`

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#FAF7F2',
          fontFamily: 'sans-serif',
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={logoSrc} width={280} height={280} alt="" />

        <div style={{ fontSize: 64, fontWeight: 700, color: '#1A1512', marginTop: 28, letterSpacing: -1 }}>
          Taste of African Cuisine
        </div>

        <div style={{ width: 140, height: 4, background: '#C9982E', marginTop: 22, marginBottom: 22 }} />

        <div style={{ fontSize: 30, color: '#6B6257' }}>
          Vernon, Connecticut · Pickup &amp; delivery
        </div>
      </div>
    ),
    size
  )
}
