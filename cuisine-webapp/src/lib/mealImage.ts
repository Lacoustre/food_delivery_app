/**
 * The address a dish photo is shown at: our own /menu-images/ route rather
 * than Supabase directly, because Supabase marks every file noindex. See
 * src/app/menu-images/[file]/route.ts.
 */
const BUCKET_PREFIX = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/meals/`

export function mealImageSrc(url: string | null | undefined): string {
  if (!url) return '/assets/images/logo.png'
  if (url.startsWith(BUCKET_PREFIX)) return `/menu-images/${url.slice(BUCKET_PREFIX.length)}`
  return url
}
