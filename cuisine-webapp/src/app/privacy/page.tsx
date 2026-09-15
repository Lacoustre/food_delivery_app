import type { Metadata } from 'next'
import { LegalPage } from '../legal/LegalPage'

export const metadata: Metadata = {
  title: 'Privacy — Taste of African Cuisine',
  description:
    'What Taste of African Cuisine collects when you order, who processes it, and how to have it deleted.'
}

export default function Privacy() {
  return (
    <LegalPage title="Privacy" updated="September 11, 2026">
      <p>
        Taste of African Cuisine, 200 Hartford Turnpike, Vernon, CT 06066, runs this
        site and the mobile app. This page describes what we collect when you order,
        who else handles it, and how to have it removed. It is written to describe
        what the software actually does rather than to cover every eventuality.
      </p>

      <h2>What we collect</h2>
      <p>When you create an account and place an order, we store:</p>
      <ul>
        <li>Your name, email address and phone number</li>
        <li>Your delivery address, when you order delivery</li>
        <li>What you ordered, what it cost, and when</li>
        <li>Any note you add to an order</li>
      </ul>
      <p>
        <strong>We never see or store your card details.</strong> The card fields on
        the checkout page are served by Stripe and the number goes straight to them.
        Our servers receive an identifier for the payment and the amount, nothing
        more.
      </p>

      <h2>Who else handles it</h2>
      <p>
        Running a restaurant website means other companies are involved. Each one
        gets only what it needs:
      </p>
      <ul>
        <li>
          <strong>Stripe</strong> — processes card payments. They receive your card
          details directly and the order amount.
        </li>
        <li>
          <strong>Uber Direct</strong> — delivers your food. They receive your name,
          phone number and delivery address so the courier can find you. Pickup
          orders send them nothing.
        </li>
        <li>
          <strong>Supabase</strong> — stores the database, in the United States.
        </li>
        <li>
          <strong>Resend</strong> — sends your order confirmation and status emails.
        </li>
        <li>
          <strong>Vercel</strong> — hosts this website.
        </li>
        <li>
          <strong>Google Firebase</strong> — delivers push notifications to the
          mobile app, if you use it and allow them.
        </li>
      </ul>
      <p>
        We do not sell your information, and we do not share it with anyone for
        advertising.
      </p>

      <h2>How long we keep it</h2>
      <p>
        Order records are kept as long as the account exists, so you can see your own
        history and so we can answer questions about a past order. Payment records
        are kept by Stripe under their own retention rules, which we cannot shorten.
      </p>

      <h2>Deleting your account</h2>
      <p>
        Email{' '}
        <a href="mailto:orders@tasteofafricancuisine.com">orders@tasteofafricancuisine.com</a>{' '}
        from the address on the account and we will delete it and its order history.
      </p>
      <p>
        Two honest caveats. Records Stripe holds for financial and anti-fraud
        purposes are theirs to keep, and deleting the account does not remove them.
        And if an order is still being prepared or delivered, we will finish it
        first.
      </p>

      <h2>Cookies and tracking</h2>
      <p>
        This site sets no advertising or analytics cookies. Your browser stores your
        cart and login session locally so the site works between pages. Nothing is
        shared with an advertising network.
      </p>

      <h2>Children</h2>
      <p>
        This site is not intended for children under 13, and we do not knowingly
        collect their information.
      </p>

      <h2>Changes</h2>
      <p>
        If this changes, the date at the top changes with it. Material changes will
        be mentioned in an email to account holders.
      </p>
    </LegalPage>
  )
}
