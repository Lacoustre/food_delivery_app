-- The live database was originally set up via the SQL editor and migration
-- 00000000000002's order_items.name half never made it in — create-order
-- inserts this column, so its absence breaks order-item writes, and
-- dispatch-due-orders selects it for the Uber manifest. Idempotent so it's
-- a no-op wherever the column already exists.
alter table order_items add column if not exists name text;
