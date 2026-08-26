import type { Metadata } from "next";
import { DM_Sans, Instrument_Serif } from "next/font/google";
import "./globals.css";
import { AuthProvider } from '@/lib/AuthContext';

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

export const metadata: Metadata = {
  title: "Taste of African Cuisine — Authentic Ghanaian Food in Vernon, CT",
  description:
    "Jollof, waakye, banku and fufu made from scratch. Order pickup or delivery from Taste of African Cuisine, 200 Hartford Turnpike, Vernon, Connecticut.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
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
