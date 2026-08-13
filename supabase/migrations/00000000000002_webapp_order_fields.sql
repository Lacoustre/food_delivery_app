-- The webapp's checkout collects a few fields the original schema (modeled
-- off the Flutter app's Firestore orders) didn't have: an order number,
-- order type, payment method, a tax line, and a free-text delivery address
-- (the Flutter app uses a saved addresses table via address_id instead).
alter table orders
  add column order_number text,
  add column order_type text check (order_type in ('delivery', 'pickup')),
  add column payment_method text check (payment_method in ('card', 'cash')),
  add column tax numeric(10,2) not null default 0,
  add column delivery_address text;

-- Snapshot the meal name at order time so order history stays correct even
-- if the meal is later renamed or removed from the menu.
alter table order_items
  add column name text;
