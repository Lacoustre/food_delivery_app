import type { MetadataRoute } from 'next'
import { SITE_URL } from './robots'
import { mealImageSrc } from '@/lib/mealImage'

/**
 * Small on purpose. The menu lives on the homepage rather than at its own URL,
 * and individual dishes are addressed as /meal?id=… — a query string, which
 * Google treats as one page rather than many. Giving dishes real paths would
 * be the single biggest structural SEO change available here.
 *
 * The homepage entry lists every dish photo. The menu is drawn by JavaScript,
 * so the first HTML Google receives contains no dish photos at all; this is
 * how it learns they exist and that they belong to this site. Cached for an
 * hour, so a newly uploaded photo is announced without a deploy.
 */
async function dishPhotos(): Promise<string[]> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return []
  try {
    const res = await fetch(`${url}/rest/v1/meals?select=image_url&active=eq.true`, {
      headers: { apikey: key, Authorization: `Bearer ${key}` },
      next: { revalidate: 3600 },
    })
    if (!res.ok) return []
    const rows: { image_url: string | null }[] = await res.json()
    const own = rows
      .map(r => mealImageSrc(r.image_url))
      .filter(src => src.startsWith('/menu-images/'))
      .map(src => `${SITE_URL}${src}`)
    return [...new Set(own)]
  } catch {
    return []
  }
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date()
  return [
    { url: `${SITE_URL}/`, lastModified: now, changeFrequency: 'weekly', priority: 1, images: await dishPhotos() },
    { url: `${SITE_URL}/terms`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
    { url: `${SITE_URL}/privacy`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
    { url: `${SITE_URL}/refunds`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 }
  ]
}
