-- Order numbers were String(Math.floor(Math.random() * 10000) + 1000) with no
-- unique constraint. Ten thousand possible values and a birthday problem: a
-- 39% chance of a collision by the hundredth order, 86% by the two hundredth.
-- Two live orders sharing #4471 means staff hand the wrong food to the wrong
-- customer, and it gets likelier exactly as the restaurant gets busier.
--
-- Postgres assigns them now. A sequence cannot collide, the application cannot
-- get it wrong because it no longer decides, and the unique index is there in
-- case anything ever writes one directly.
--
-- Safe to run on an empty orders table; this is applied before the first real
-- order. Existing numbers would need backfilling first otherwise.

create sequence if not exists order_number_seq start with 1001 increment by 1;

alter table orders
  alter column order_number set default lpad(nextval('order_number_seq')::text, 4, '0');

-- Belt and braces: the sequence guarantees uniqueness, this catches anything
-- that bypasses it.
create unique index if not exists orders_order_number_unique
  on orders(order_number) where order_number is not null;

comment on column orders.order_number is
  'Customer-facing order number, assigned by order_number_seq. Never generated in application code.';

do $$
declare a text; b text;
begin
  a := lpad(nextval('order_number_seq')::text, 4, '0');
  b := lpad(nextval('order_number_seq')::text, 4, '0');
  if a = b then
    raise exception 'order_number_seq returned % twice', a;
  end if;
end $$;
