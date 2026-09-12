import { ImageResponse } from 'next/og'

/**
 * The card that appears when someone shares the link — in Messages, WhatsApp,
 * Facebook, Slack. Without one, those all show a bare URL, which looks like
 * spam and gets clicked less.
 *
 * Drawn rather than photographed because every dish photo in the repo is well
 * under the 1200x630 these platforms want, and an undersized image is rendered
 * as a small square thumbnail instead of a banner.
 */
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'
export const alt = 'Taste of African Cuisine — Authentic African cooking in Vernon, Connecticut'

export default function OpengraphImage() {
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
          background: '#14543D',
          color: '#FAF7F2',
          fontFamily: 'sans-serif',
          padding: 64
        }}
      >
        <div
          style={{
            fontSize: 30,
            letterSpacing: 8,
            textTransform: 'uppercase',
            color: '#C9982E',
            marginBottom: 28
          }}
        >
          Vernon, Connecticut
        </div>

        <div
          style={{
            fontSize: 86,
            fontWeight: 700,
            textAlign: 'center',
            lineHeight: 1.1,
            marginBottom: 30
          }}
        >
          Taste of African Cuisine
        </div>

        <div style={{ width: 180, height: 5, background: '#C9982E', marginBottom: 34 }} />

        <div
          style={{
            fontSize: 36,
            textAlign: 'center',
            color: '#E5E0D8',
            lineHeight: 1.4
          }}
        >
          Jollof · Waakye · Banku · Fufu
        </div>

        <div style={{ fontSize: 27, color: '#C9982E', marginTop: 40 }}>
          200 Hartford Turnpike · Pickup &amp; delivery
        </div>
      </div>
    ),
    size
  )
}
