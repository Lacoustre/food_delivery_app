import type { MetadataRoute } from 'next'

/**
 * Makes the site installable: "Add to Home Screen" on an iPhone, "Install
 * app" on Android. It then opens full screen under the restaurant's logo,
 * with no browser bar — the part of having an app that a customer actually
 * notices, without an app store standing between them and ordering.
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Taste of African Cuisine',
    short_name: 'African Cuisine',
    description:
      'Order jollof, waakye, banku and fufu for pickup or delivery from Taste of African Cuisine in Vernon, Connecticut.',
    start_url: '/',
    display: 'standalone',
    background_color: '#FBF8F3',
    theme_color: '#C9982E',
    categories: ['food'],
    icons: [
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
      // Android masks icons to a circle. These are the same squares, with the
      // logo at 80% width on cream, so the mask has margin to cut into.
      { src: '/icons/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'maskable' },
      { src: '/icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  }
}
