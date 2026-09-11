-- Orders had no link to the Stripe payment that paid for them, so nothing
-- could find the charge to refund. Cancelling an order set a status and left
-- the customer's card charged, while the cancellation email told them a refund
-- was coming.

alter table orders
  add column if not exists payment_intent_id text,
  add column if not exists refund_id          text,
  add column if not exists refunded_at        timestamptz,
  add column if not exists refund_amount      numeric(10,2) check (refund_amount >= 0);

-- Finding an order by its payment is how a webhook or a reconciliation script
-- will look one up.
create index if not exists orders_payment_intent_id_idx
  on orders(payment_intent_id) where payment_intent_id is not null;

-- One refund per order. A double-click on Cancel must not refund twice, and
-- the unique index makes that impossible regardless of what the code does.
create unique index if not exists orders_refund_id_unique
  on orders(refund_id) where refund_id is not null;

comment on column orders.payment_intent_id is
  'Stripe PaymentIntent that paid for this order. Null for cash orders, which have nothing to refund.';
comment on column orders.refund_id is
  'Stripe Refund id. Non-null means this order has already been refunded.';
