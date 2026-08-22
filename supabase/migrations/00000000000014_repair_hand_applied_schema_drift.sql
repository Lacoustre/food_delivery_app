-- The live schema was originally hand-applied via the SQL editor, and all of
-- migration 00000000000002 plus part of 00000000000003 never actually ran:
-- orders was missing order_number/order_type/payment_method/tax/
-- delivery_address/driver_name (and order_items.name, repaired in 13).
-- create-order inserts several of these, so order creation itself was
-- failing against the live database. Same definitions as the original
-- migrations, guarded with if-not-exists so this is a no-op anywhere the
-- columns already landed.
alter table orders
  add column if not exists order_number text,
  add column if not exists order_type text check (order_type in ('delivery', 'pickup')),
  add column if not exists payment_method text check (payment_method in ('card', 'cash')),
  add column if not exists tax numeric(10,2) not null default 0,
  add column if not exists delivery_address text,
  add column if not exists driver_name text;
