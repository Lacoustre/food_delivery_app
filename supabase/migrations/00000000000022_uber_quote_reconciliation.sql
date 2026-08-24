-- Delivery pricing is now pass-through: the customer is charged exactly what
-- Uber quotes at checkout, so the distance-tier table is gone.
--
-- Uber's final invoiced fee can still differ from the quote (quotes expire
-- after 15 minutes, and a scheduled order is re-quoted at dispatch), so record
-- which quote backed the charge. Compared against the existing orders.uber_fee
-- — what Uber actually billed — this makes per-delivery margin visible instead
-- of silent.

alter table orders
  add column if not exists uber_quote_id text;

comment on column orders.uber_quote_id is
  'Uber delivery_quotes id backing delivery_fee (what the customer was charged). Compare delivery_fee against uber_fee for per-order margin.';
