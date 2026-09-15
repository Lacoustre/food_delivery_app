import { SITE_URL } from '@/app/robots'
import { mealImageSrc } from './mealImage'

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

interface MenuRow {
  name: string
  price: number
  image_url: string | null
  description: string | null
  base_slug: string | null
  base_name: string | null
  base_description: string | null
  is_vegetarian: boolean | null
  menu_section: string | null
}

async function loadMenu(): Promise<MenuRow[]> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  if (!url || !key) return []
  try {
    const res = await fetch(
      `${url}/rest/v1/meals?select=name,price,image_url,description,base_slug,base_name,base_description,is_vegetarian,menu_section&active=eq.true`,
      { headers: { apikey: key, Authorization: `Bearer ${key}` }, next: { revalidate: 3600 } }
    )
    return res.ok ? await res.json() : []
  } catch {
    return []
  }
}

/**
 * The menu as schema.org understands it: sections of dishes, each with its
 * photo and price. Without this Google knew the restaurant existed but not
 * that any particular photo was one of its dishes. One item per dish rather
 * than per option, the same grouping the menu cards use, with the price range
 * across its options.
 */
function menuSchema(rows: MenuRow[]) {
  const order = ['Main Dishes', 'Side Dishes', 'Desserts', 'Drinks']
  const bySection = new Map<string, Map<string, MenuRow[]>>()
  for (const r of rows) {
    const section = r.menu_section || 'Main Dishes'
    const dish = r.base_slug || r.name
    if (!bySection.has(section)) bySection.set(section, new Map())
    const dishes = bySection.get(section)!
    dishes.set(dish, [...(dishes.get(dish) ?? []), r])
  }

  return {
    '@type': 'Menu',
    name: 'Taste of African Cuisine menu',
    url: `${SITE_URL}/#menu`,
    hasMenuSection: [...bySection.keys()]
      .sort((a, b) => (order.indexOf(a) + 99) % 99 - (order.indexOf(b) + 99) % 99)
      .map(section => ({
        '@type': 'MenuSection',
        name: section,
        hasMenuItem: [...bySection.get(section)!.values()].map(group => {
          const first = group[0]
          const prices = group.map(g => Number(g.price))
          const low = Math.min(...prices), high = Math.max(...prices)
          const img = group.map(g => mealImageSrc(g.image_url)).find(s => s.startsWith('/menu-images/'))
          return {
            '@type': 'MenuItem',
            name: first.base_name || first.name,
            description: first.base_description || first.description || undefined,
            image: img ? `${SITE_URL}${img}` : undefined,
            suitableForDiet: group.every(g => g.is_vegetarian) ? 'https://schema.org/VegetarianDiet' : undefined,
            offers: low === high
              ? { '@type': 'Offer', price: low.toFixed(2), priceCurrency: 'USD' }
              : { '@type': 'AggregateOffer', lowPrice: low.toFixed(2), highPrice: high.toFixed(2), priceCurrency: 'USD' },
          }
        }),
      })),
  }
}

export async function restaurantSchema() {
  const [settings, menuRows] = await Promise.all([loadSettings(), loadMenu()])
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
    hasMenu: menuSchema(menuRows),
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
