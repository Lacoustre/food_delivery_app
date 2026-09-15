'use client'

import Image from 'next/image'
import { useState, type ReactEventHandler } from 'react'

/**
 * A dish photo shown whole.
 *
 * The restaurant's photos come in every shape — square, 4:3, 3:4, 16:9, tall
 * 9:16 phone shots — so any fixed card shape crops most of them. Square cards
 * were already the least bad and still cut away about a fifth of the average
 * photo; 37 of 62 lost more than 20%, and the tall ones 44%.
 *
 * So the photo is never cropped. It sits whole in the card, and the space
 * around a photo that isn't the card's shape is filled with a soft, blurred
 * copy of the same photo instead of empty bands. Both layers use the same URL,
 * so the browser downloads it once.
 *
 * Until it arrives the box shimmers, and the photo fades in rather than
 * popping. "Loaded" is tracked per src, so choosing another option in the
 * sheet shimmers again for the new photo. A photo can also finish loading
 * before this component hydrates — the About image is in the server HTML — and
 * then onLoad never fires, so the ref checks `complete` as well; otherwise
 * that photo would stay invisible.
 *
 * Renders into its parent, which must be `relative` and `overflow-hidden` —
 * the blur spreads past the photo's edges and would otherwise bleed into
 * whatever sits below.
 */
export function DishPhoto({
  src,
  alt,
  onError,
}: {
  src: string
  alt: string
  onError?: ReactEventHandler<HTMLImageElement>
}) {
  const [loadedSrc, setLoadedSrc] = useState<string | null>(null)
  const loaded = loadedSrc === src

  return (
    <>
      {!loaded && <div aria-hidden className="absolute inset-0 photo-shimmer" />}
      <Image
        src={src}
        alt=""
        aria-hidden
        fill
        unoptimized
        className={`object-cover scale-110 blur-2xl pointer-events-none select-none transition-opacity duration-500 ${
          loaded ? 'opacity-60' : 'opacity-0'
        }`}
      />
      <Image
        src={src}
        alt={alt}
        fill
        unoptimized
        ref={(el) => { if (el && el.complete && el.naturalWidth > 0) setLoadedSrc(src) }}
        onLoad={() => setLoadedSrc(src)}
        onError={(e) => { setLoadedSrc(src); onError?.(e) }}
        className={`object-contain transition-opacity duration-500 ${loaded ? 'opacity-100' : 'opacity-0'}`}
      />
    </>
  )
}
