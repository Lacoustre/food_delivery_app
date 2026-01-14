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
}

module.exports = nextConfig