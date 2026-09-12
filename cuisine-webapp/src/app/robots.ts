import type { MetadataRoute } from 'next'

export const SITE_URL = 'https://tasteofafricancuisine.com'

/**
 * There was no robots.txt at all, which is not fatal — Google crawls without
 * one — but it is also where the sitemap gets announced, and there was no
 * sitemap either.
 *
 * The disallowed paths are not secrets; they are pages that would waste crawl
 * budget and could show up in results as dead ends. A signed-out crawler
 * hitting /checkout sees an empty cart.
 */
export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: [
        '/cart',
        '/checkout',
        '/orders',
        '/order-confirmation',
        '/profile',
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/api/'
      ]
    },
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL
  }
}
