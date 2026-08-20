-- Delivery is moving from in-house drivers to Uber Direct: the create-order
-- edge function dispatches confirmed delivery orders to Uber and stores the
-- returned delivery id + tracking URL here. Existing driver_id/driver_name
-- columns are left untouched for historical orders.
alter table orders
  add column delivery_provider text check (delivery_provider in ('uber_direct')),
  add column uber_delivery_id text,
  add column uber_tracking_url text,
  add column uber_delivery_status text,
  add column uber_fee numeric(10,2);
