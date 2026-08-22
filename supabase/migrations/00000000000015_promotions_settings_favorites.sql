-- Moves the last webapp features off Firestore: promo codes get a real
-- table (they only ever lived in Firestore), the restaurant open/closed
-- status gets its settings row seeded, and favorites/settings join the
-- realtime publication so the webapp's live listeners keep working.

create table promotions (
  id                uuid primary key default gen_random_uuid(),
  code              text not null unique,
  type              text not null check (type in ('percentage', 'fixed')),
  value             numeric(10,2) not null check (value >= 0),
  min_order_amount  numeric(10,2),
  max_discount      numeric(10,2),
  description       text not null default '',
  valid_from        timestamptz not null,
  valid_until       timestamptz not null,
  usage_limit       int,
  used_count        int not null default 0,
  active            boolean not null default true,
  created_at        timestamptz not null default now()
);

alter table promotions enable row level security;
-- Anyone can read (codes are validated by value, not secrecy — same as the
-- old Firestore rules); only admins manage them.
create policy "promotions_public_read" on promotions for select using (true);
create policy "promotions_admin_write" on promotions for insert with check (is_admin());
create policy "promotions_admin_update" on promotions for update using (is_admin());
create policy "promotions_admin_delete" on promotions for delete using (is_admin());

-- The webapp/mobile read this row for the open/closed banner; admin panel
-- and the mobile auto-scheduler write it.
insert into settings (key, value)
values ('restaurant', '{"isOpen": true, "message": ""}')
on conflict (key) do nothing;

alter publication supabase_realtime add table favorites;
alter publication supabase_realtime add table settings;
