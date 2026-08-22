-- The in-house driver system is fully retired (deliveries are Uber Direct,
-- the driver app is deleted, and no production data exists). Drop its
-- tables and the orders driver columns; the RLS policies that referenced
-- driver_id are recreated without it.

drop policy "orders_participant_or_admin_read" on orders;
create policy "orders_participant_or_admin_read" on orders for select
  using (auth.uid() = user_id or is_admin());

drop policy "orders_participant_or_admin_update" on orders;
create policy "orders_participant_or_admin_update" on orders for update
  using (auth.uid() = user_id or is_admin());

drop policy "order_items_via_order" on order_items;
create policy "order_items_via_order" on order_items for select
  using (exists (
    select 1 from orders o where o.id = order_id
      and (auth.uid() = o.user_id or is_admin())
  ));

drop table if exists order_messages;
drop table if exists delivery_photos;
drop table if exists driver_locations;
-- orders.driver_id FK must go before its target table; the column itself
-- (and the policies that referenced it, recreated above) follow below.
alter table orders drop constraint if exists orders_driver_id_fkey;
alter table orders drop column if exists driver_id;
drop table if exists drivers;

alter table orders
  drop column if exists driver_id,
  drop column if exists driver_name,
  drop column if exists driver_status,
  drop column if exists assigned_at,
  drop column if exists last_message,
  drop column if exists last_message_at,
  drop column if exists last_message_by,
  drop column if exists delivery_photo_url,
  drop column if exists photo_taken_at;
