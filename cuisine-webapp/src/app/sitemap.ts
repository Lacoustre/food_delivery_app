import type { MetadataRoute } from 'next'
import { SITE_URL } from './robots'

/**
 * Small on purpose. The menu lives on the homepage rather than at its own URL,
 * and individual dishes are addressed as /meal?id=… — a query string, which
 * Google treats as one page rather than many. Giving dishes real paths would
 * be the single biggest structural SEO change available here.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date()
  return [
    { url: `${SITE_URL}/`, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${SITE_URL}/terms`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
    { url: `${SITE_URL}/privacy`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
    { url: `${SITE_URL}/refunds`, lastModified: now, changeFrequency: 'yearly', priority: 0.3 }
  ]
}
