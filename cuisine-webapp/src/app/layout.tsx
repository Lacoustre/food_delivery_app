import type { Metadata } from "next";
import { DM_Sans, Instrument_Serif } from "next/font/google";
import "./globals.css";
import { AuthProvider } from '@/lib/AuthContext';
import { SITE_URL } from './robots';
import { restaurantSchema } from '@/lib/restaurantSchema';

// Body and UI. Warm, highly legible, good tabular numerals for prices.
const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm-sans",
  display: "swap",
});

// Dish names and headings. Carries the appetite appeal and premium register
// that a single UI sans could not.
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  variable: "--font-instrument-serif",
  display: "swap",
});

const DESCRIPTION =
  "Jollof, waakye, banku and fufu made from scratch. Order pickup or delivery from Taste of African Cuisine, 200 Hartford Turnpike, Vernon, Connecticut.";

export const metadata: Metadata = {
  // Without this, every relative URL below resolves against localhost at build
  // time, and the canonical tag points somewhere that does not exist.
  metadataBase: new URL(SITE_URL),
  title: {
    default: "Taste of African Cuisine — Authentic African Cooking in Vernon, CT",
    // Inner pages set their own; this keeps the restaurant name on all of them.
    template: "%s — Taste of African Cuisine",
  },
  description: DESCRIPTION,
  // The site answers on both the apex and www. Without a canonical, Google
  // treats them as two sites competing with each other.
  alternates: { canonical: "/" },
  openGraph: {
    type: "website",
    siteName: "Taste of African Cuisine",
    title: "Taste of African Cuisine — Authentic African Cooking in Vernon, CT",
    description: DESCRIPTION,
    url: SITE_URL,
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "Taste of African Cuisine",
    description: DESCRIPTION,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: { index: true, follow: true, "max-image-preview": "large" },
  },
  // Helps Google associate the site with the physical business.
  other: {
    "geo.region": "US-CT",
    "geo.placename": "Vernon, Connecticut",
    "geo.position": "41.82457;-72.4978",
    ICBM: "41.82457, -72.4978",
  },
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const schema = await restaurantSchema();

  return (
    <html lang="en">
      <head>
        {/* Describes the business to search engines in the form they read:
            same name, address, phone and coordinates as the Google Business
            Profile, so the two are understood as one place. */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
        />
      </head>
      <body
        className={`${dmSans.variable} ${instrumentSerif.variable} font-primary antialiased bg-sand-50 text-ink`}
      >
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  );
}
