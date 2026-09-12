import { SITE_URL } from '@/app/robots'

/**
 * Structured data describing the restaurant to search engines.
 *
 * This is what lets Google connect the website to the business it already
 * knows about — the same name, address, phone number and coordinates that
 * appear on the Google Business Profile. Matching them exactly is the point;
 * a different phone number or a slightly different street address reads as a
 * different business.
 *
 * Hours come from the same settings row the admin panel writes, so toggling a
 * day closed in the dashboard eventually changes what Google is told. Cached
 * for an hour: this is a crawler-facing hint, not the check that decides
 * whether an order can be placed (see lib/hours.ts for that).
 */

const FALLBACK_HOURS: Record<string, { open: string; close: string; closed?: boolean }> = {
  sunday: { open: '11:00', close: '21:00', closed: true },
  monday: { open: '11:00', close: '21:00', closed: true },
  tuesday: { open: '11:00', close: '21:00' },
  wednesday: { open: '11:00', close: '21:00' },
  thursday: { open: '11:00', close: '21:00' },
  friday: { open: '11:00', close: '20:00' },
  saturday: { open: '11:00', close: '21:00' }
}

const DAY_SCHEMA: Record<string, string> = {
  sunday: 'Sunday',
  monday: 'Monday',
  tuesday: 'Tuesday',
  wednesday: 'Wednesday',
  thursday: 'Thursday',
  friday: 'Friday',
  saturday: 'Saturday'
}

interface RestaurantSettings {
  businessHours?: Record<string, { open?: string; close?: string; closed?: boolean }>
  latitude?: number
  longitude?: number
  address?: string
}

async function loadSettings(): Promise<RestaurantSettings | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return null

  try {
    const res = await fetch(
      `${url}/rest/v1/settings?key=eq.restaurant&select=value`,
      {
        headers: { apikey: key, Authorization: `Bearer ${key}` },
        next: { revalidate: 3600 }
      }
    )
    if (!res.ok) return null
    const rows = await res.json()
    return rows?.[0]?.value ?? null
  } catch {
    // Falls through to the constants below. A page that renders without
    // structured data is a far smaller problem than one that fails to render.
    return null
  }
}

export async function restaurantSchema() {
  const settings = await loadSettings()
  const hours = settings?.businessHours ?? FALLBACK_HOURS

  const openingHoursSpecification = Object.entries(hours)
    .filter(([day, h]) => DAY_SCHEMA[day] && !h?.closed && h?.open && h?.close)
    .map(([day, h]) => ({
      '@type': 'OpeningHoursSpecification',
      dayOfWeek: `https://schema.org/${DAY_SCHEMA[day]}`,
      opens: h.open,
      closes: h.close
    }))

  return {
    '@context': 'https://schema.org',
    '@type': 'Restaurant',
    '@id': `${SITE_URL}/#restaurant`,
    name: 'Taste of African Cuisine',
    description:
      'Authentic African cooking in Vernon, Connecticut. Jollof rice, waakye, banku, fufu and light soup, made from scratch. Pickup and delivery.',
    url: SITE_URL,
    telephone: '+1-860-805-5121',
    email: 'orders@tasteofafricancuisine.com',
    image: [`${SITE_URL}/assets/images/jollof.png`],
    logo: `${SITE_URL}/icon.png`,
    // Google shows this as the price band on a listing. Most mains sit in the
    // mid-teens to low twenties.
    priceRange: '$$',
    currenciesAccepted: 'USD',
    paymentAccepted: 'Cash, Credit Card',
    // Several terms on purpose: people search "African restaurant",
    // "Ghanaian food" and "West African" for the same thing.
    servesCuisine: ['African', 'West African', 'Ghanaian'],
    address: {
      '@type': 'PostalAddress',
      streetAddress: '200 Hartford Turnpike',
      addressLocality: 'Vernon',
      addressRegion: 'CT',
      postalCode: '06066',
      addressCountry: 'US'
    },
    geo: {
      '@type': 'GeoCoordinates',
      latitude: settings?.latitude ?? 41.82457,
      longitude: settings?.longitude ?? -72.4978
    },
    openingHoursSpecification,
    hasMenu: `${SITE_URL}/#menu`,
    acceptsReservations: false,
    // Delivery is by Uber Direct within roughly ten miles.
    areaServed: {
      '@type': 'GeoCircle',
      geoMidpoint: {
        '@type': 'GeoCoordinates',
        latitude: settings?.latitude ?? 41.82457,
        longitude: settings?.longitude ?? -72.4978
      },
      geoRadius: '16000'
    },
    potentialAction: {
      '@type': 'OrderAction',
      target: {
        '@type': 'EntryPoint',
        urlTemplate: `${SITE_URL}/`,
        inLanguage: 'en-US',
        actionPlatform: [
          'https://schema.org/DesktopWebPlatform',
          'https://schema.org/MobileWebPlatform'
        ]
      },
      deliveryMethod: [
        'https://schema.org/OnSitePickup',
        'https://schema.org/ParcelService'
      ]
    }
  }
}
