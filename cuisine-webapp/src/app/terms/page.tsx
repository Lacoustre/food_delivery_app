import type { Metadata } from 'next'
import { LegalPage } from '../legal/LegalPage'

export const metadata: Metadata = {
  title: 'Terms — Taste of African Cuisine',
  description:
    'Ordering, prices, tax, delivery area and allergens at Taste of African Cuisine, Vernon CT.'
}

export default function Terms() {
  return (
    <LegalPage title="Terms of service" updated="September 11, 2026">
      <p>
        These terms cover ordering from Taste of African Cuisine, 200 Hartford
        Turnpike, Vernon, CT 06066, through this website or our mobile app. Placing
        an order means accepting them.
      </p>

      <h2>Ordering</h2>
      <p>
        An order is accepted when we confirm it, not when you submit it. If we cannot
        make something — an ingredient has run out, or we are busier than the kitchen
        can manage — we will contact you and refund anything already paid.
      </p>
      <p>
        We take orders during opening hours: Tuesday to Thursday 11am&ndash;9pm,
        Friday 11am&ndash;8pm, Saturday 11am&ndash;9pm. We are closed Sundays and
        Mondays. You can order ahead while we are closed &mdash; choose a pickup or
        delivery time up to three hours later, and we will have it ready then. We
        cannot take an order for a time we are shut.
      </p>
      <p>
        Some dishes are made on set days only. Check Check is Wednesdays and Tuo
        Zaafi is Saturdays, and the menu says so on the dish.
      </p>

      <h2>Prices and tax</h2>
      <p>
        Prices are in US dollars and shown on the menu. Connecticut sales tax of
        7.35% is added to the food total at checkout, and the delivery fee, where one
        applies, is not taxed. The total you see before paying is the total you are
        charged.
      </p>
      <p>
        Prices can change. The price that applies is the one shown when you place the
        order.
      </p>

      <h2>Payment</h2>
      <p>
        Card payments are handled by Stripe; we never see your card number. Delivery
        orders must be paid by card, because our couriers cannot collect cash. For
        pickup you may pay by card online or with cash at the counter.
      </p>

      <h2>Delivery</h2>
      <p>
        Deliveries are made by Uber Direct couriers, not by our own staff. We deliver
        roughly ten miles from the restaurant; if an address is outside that, checkout
        will tell you before you pay.
      </p>
      <p>
        The delivery fee is quoted by Uber for your specific address and shown before
        you pay. Times are estimates. Everything is cooked to order, and traffic and
        weather affect the rest.
      </p>
      <p>
        Please give an address a courier can actually reach, with a working phone
        number. If nobody can be reached and the food cannot be handed over, we cannot
        refund it.
      </p>

      <h2>Allergens</h2>
      <p>
        Our kitchen handles peanuts, shellfish, fish, eggs, wheat and dairy. Dishes
        are cooked in a shared kitchen and we cannot guarantee any dish is free of a
        given allergen.
      </p>
      <p>
        Dish descriptions name the main ingredients, including where a dish contains
        peanuts or meat that may not be obvious from the name. If you have a serious
        allergy, call us on{' '}
        <a href="tel:+18608055121">(860) 805-5121</a> before ordering rather than
        relying on the website.
      </p>

      <h2>Your account</h2>
      <p>
        Keep your password to yourself; orders placed from your account are treated as
        yours. Tell us if you think someone else has access.
      </p>
      <p>
        We may close an account that is being used fraudulently or abusively.
      </p>

      <h2>Cancellations and refunds</h2>
      <p>
        Covered on the{' '}
        <a href="/refunds">refunds and cancellations</a> page.
      </p>

      <h2>Liability</h2>
      <p>
        Nothing here limits liability we cannot limit by law, including for death or
        personal injury caused by negligence. Otherwise, our responsibility for an
        order is limited to what you paid for it.
      </p>

      <h2>Governing law</h2>
      <p>These terms are governed by the laws of the State of Connecticut.</p>
    </LegalPage>
  )
}
