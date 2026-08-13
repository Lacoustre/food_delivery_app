-- admin-panel's Orders.tsx uses a richer status set than the original
-- schema allowed (distinguishing pickup vs delivery flow, and a terminal
-- "completed" separate from "delivered"/"picked up"), and needs driver
-- assignment + online/offline tracking that didn't exist yet.
alter table orders drop constraint orders_status_check;
alter table orders add constraint orders_status_check check (status in (
  'pending', 'confirmed', 'preparing', 'ready for pickup', 'on the way',
  'delivered', 'picked up', 'completed', 'cancelled'
));

-- driver_name is plain text rather than relying solely on driver_id (FK to
-- drivers) because the driver system itself hasn't been migrated to
-- Supabase yet — the driver picker still reads from Firestore, so there's
-- no valid Postgres drivers.id to reference at assignment time.
alter table orders
  add column driver_name text,
  add column driver_status text check (driver_status in ('assigned')),
  add column assigned_at timestamptz;

alter table drivers
  add column is_active boolean not null default false;

-- Realtime is opt-in per table in Supabase — Orders.tsx subscribes to
-- live order changes, so the table needs to be added to the publication.
alter publication supabase_realtime add table orders;
