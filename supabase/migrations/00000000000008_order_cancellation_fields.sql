alter table orders
  add column cancelled_at timestamptz,
  add column cancelled_by text check (cancelled_by in ('customer', 'admin')),
  add column cancellation_reason text;
