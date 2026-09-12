-- The Clover order id was returned by the push and thrown away, so nothing on
-- our side could ever refer back to the ticket it created. Cancelling an order
-- in the admin panel therefore left the ticket open on the POS, where staff
-- could still act on food nobody was going to pay for.
alter table orders add column if not exists clover_order_id text;

comment on column orders.clover_order_id is
  'Clover order this was pushed to. Null when the push failed or Clover is not configured.';

-- Cancellation looks the row up by our id, so no index is needed for that;
-- this one is for the reverse direction, reconciling a ticket seen on the POS.
create index if not exists orders_clover_order_id_idx
  on orders (clover_order_id)
  where clover_order_id is not null;
