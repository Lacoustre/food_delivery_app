import type { Metadata } from 'next'
import { LegalPage } from '../legal/LegalPage'

export const metadata: Metadata = {
  title: 'Refunds & cancellations — Taste of African Cuisine',
  description:
    'When Taste of African Cuisine can cancel or refund an order, and how long a refund takes to arrive.'
}

export default function Refunds() {
  return (
    <LegalPage title="Refunds &amp; cancellations" updated="11 September 2026">
      <p>
        Food is cooked to order, which is what makes this different from returning a
        product. Once the kitchen has started, the ingredients are used whether or
        not you collect it. This page says plainly when we can cancel and when we
        cannot.
      </p>

      <h2>Cancelling</h2>
      <ul>
        <li>
          <strong>Before we start cooking</strong> — call{' '}
          <a href="tel:+18608055121">(860) 805-5121</a> and we will cancel and refund
          in full.
        </li>
        <li>
          <strong>Once cooking has started</strong> — we usually cannot cancel,
          because the food is already being made. Call anyway; if we have not got
          far, we will do what we can.
        </li>
        <li>
          <strong>Once a courier has collected it</strong> — the order cannot be
          cancelled.
        </li>
        <li>
          <strong>Scheduled orders</strong> — cancel any time before we begin
          preparing, for a full refund.
        </li>
      </ul>
      <p>
        There is no cancel button on the site. Call us: it is faster than any form,
        and the kitchen can be told immediately.
      </p>

      <h2>When we refund</h2>
      <p>We refund in full, without argument, when:</p>
      <ul>
        <li>We cancel your order for any reason</li>
        <li>Something is missing from what arrived</li>
        <li>You were sent the wrong dish</li>
        <li>The food arrives in a state it should not be in</li>
      </ul>
      <p>
        Tell us the same day, ideally with a photo. Email{' '}
        <a href="mailto:orders@tasteofafricancuisine.com">orders@tasteofafricancuisine.com</a>{' '}
        or call. We would rather fix it than argue about it.
      </p>

      <h2>When we usually cannot</h2>
      <ul>
        <li>
          <strong>You did not like it.</strong> Our food is seasoned the way these
          dishes are seasoned at home. Tell us anyway — we would like to know, and we
          may still do something about it.
        </li>
        <li>
          <strong>Nobody was there for the delivery.</strong> If the courier cannot
          reach you on the number given and cannot hand the food over, we cannot
          refund it.
        </li>
        <li>
          <strong>The address was wrong.</strong> If food goes to an address you
          entered incorrectly, we cannot recover it.
        </li>
      </ul>

      <h2>How a refund reaches you</h2>
      <p>
        Card refunds go back to the card you paid with. We issue them the same day we
        agree one; your bank then takes its own time, usually five to ten working
        days. That part is out of our hands.
      </p>
      <p>
        Cash pickup orders are refunded in cash at the restaurant.
      </p>
      <p>
        Partial refunds are possible — if one dish out of four was wrong, we refund
        that dish rather than the whole order.
      </p>

      <h2>Delivery fees</h2>
      <p>
        Where we are at fault, the delivery fee is refunded with the food. Where an
        order could not be delivered for a reason on your side, the courier has still
        been paid for the journey and the fee is not refundable.
      </p>

      <h2>Problems</h2>
      <p>
        Call <a href="tel:+18608055121">(860) 805-5121</a> during opening hours, or
        email{' '}
        <a href="mailto:orders@tasteofafricancuisine.com">orders@tasteofafricancuisine.com</a>{' '}
        any time. Quote your order number — it is in your confirmation email.
      </p>
      <p>
        Please talk to us before disputing a charge with your bank. A chargeback takes
        months and costs us a fee even when we were going to refund you anyway.
      </p>
    </LegalPage>
  )
}
