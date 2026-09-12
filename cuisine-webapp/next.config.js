/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    unoptimized: true,
    domains: ['localhost'],
    formats: ['image/avif', 'image/webp'],
  },
  experimental: {
    esmExternals: false,
  },

  // The menu is a section of the homepage, not a page of its own, so /menu
  // never existed here — but the old Wix site had it, the Google Business
  // Profile links to it, and it is what anyone types by hand. It was
  // returning 404 to people arriving from Google.
  //
  // Temporary (307) rather than permanent on purpose: a real /menu page,
  // which could rank on its own for "african food menu vernon ct", is worth
  // building later, and a 308 cached in every visitor's browser would fight
  // it for months.
  async redirects() {
    return [
      { source: '/menu', destination: '/#menu', permanent: false },
      { source: '/menus', destination: '/#menu', permanent: false },
      { source: '/our-menu', destination: '/#menu', permanent: false },
      // The Business Profile has a separate "Order online" link field.
      { source: '/order', destination: '/#menu', permanent: false },
      { source: '/order-online', destination: '/#menu', permanent: false },
    ]
  },
}

module.exports = nextConfig
