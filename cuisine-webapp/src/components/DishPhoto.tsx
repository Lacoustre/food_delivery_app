import Image from 'next/image'
import type { ReactEventHandler } from 'react'

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
  return (
    <>
      <Image
        src={src}
        alt=""
        aria-hidden
        fill
        unoptimized
        className="object-cover scale-110 blur-2xl opacity-60 pointer-events-none select-none"
      />
      <Image src={src} alt={alt} fill unoptimized className="object-contain" onError={onError} />
    </>
  )
}
