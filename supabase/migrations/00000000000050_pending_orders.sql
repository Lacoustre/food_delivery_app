-- The browser confirms the card and then calls /api/create-order. If it dies
-- in between — closed tab, dead battery, tunnel — the customer is charged and
-- no order exists. The kitchen never sees it and nobody is told.
--
-- create-payment-intent now records what the order would be, keyed by the
-- PaymentIntent. The Stripe webhook uses it to create the order if the browser
-- never managed to. The browser path stays primary; this is the backstop.
--
-- The payload is the already-validated order: server-priced items, the Uber
-- quote, the totals. Nothing here is taken from the client at webhook time.

create table if not exists pending_orders (
  payment_intent_id text primary key,
  user_id           uuid not null references profiles(id) on delete cascade,
  payload           jsonb not null,
  created_at        timestamptz not null default now()
);

create index if not exists pending_orders_created_at_idx
  on pending_orders(created_at);

alter table pending_orders enable row level security;

-- No policies at all: only the API routes touch this, and they use the service
-- role. A customer has no reason to read or write it, and the payload contains
-- server-computed prices that must not be editable.

comment on table pending_orders is
  'What an order would be, written before payment. Read by the Stripe webhook when the browser fails to call create-order. Not customer-facing.';
