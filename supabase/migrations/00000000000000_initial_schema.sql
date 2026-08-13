-- ============================================================================
-- Taste of African Cuisine Vernon — Initial Postgres schema (Supabase)
-- Migrated from Firestore. See firestore.rules / storage.rules for the
-- previous access-control model this replaces.
-- ============================================================================

create extension if not exists "pgcrypto"; -- gen_random_uuid()

-- ============================================================================
-- PROFILES  (replaces users/{userId} + admins/{adminId})
-- ============================================================================
-- Supabase already gives us auth.users (email/phone/password, managed).
-- This table holds app-specific fields, 1:1 with auth.users.
create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text,
  email         text unique,
  phone         text unique,
  role          text not null default 'customer'
                  check (role in ('customer', 'driver', 'admin')),
  fcm_token     text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
-- NOTE: role = 'admin' replaces the old admins/{uid} collection. Nobody can
-- set their own role to 'admin' (see RLS below) — the first admin must be
-- promoted directly via the Supabase SQL editor / service role, same as
-- before with the Firebase Console.

create table addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  street      text not null,
  city        text,
  state       text,
  zip         text,
  lat         double precision,
  lng         double precision,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);
create index addresses_user_id_idx on addresses(user_id);

create table user_notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  title       text,
  body        text,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);
create index user_notifications_user_id_idx on user_notifications(user_id);

create table complaints (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  subject     text,
  message     text not null,
  status      text not null default 'open' check (status in ('open', 'resolved')),
  created_at  timestamptz not null default now()
);
create index complaints_user_id_idx on complaints(user_id);

-- ============================================================================
-- MEALS  (replaces meals/{mealId})
-- ============================================================================
create table meals (
  id           uuid primary key default gen_random_uuid(),
  slug         text unique not null,
  name         text not null,
  price        numeric(10,2) not null check (price >= 0),
  description  text,
  category     text,
  active       boolean not null default true,
  image_url    text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index meals_category_idx on meals(category);
create index meals_active_idx on meals(active);

create table favorites (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  meal_id     uuid not null references meals(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (user_id, meal_id)
);

create table reviews (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles(id) on delete cascade,
  meal_id     uuid references meals(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now()
);
create index reviews_meal_id_idx on reviews(meal_id);

-- ============================================================================
-- SETTINGS  (replaces settings/{settingId} — e.g. restaurant open/closed)
-- ============================================================================
create table settings (
  key         text primary key,
  value       jsonb not null,
  updated_at  timestamptz not null default now()
);

-- ============================================================================
-- DRIVERS  (replaces drivers/{driverId})
-- ============================================================================
create table drivers (
  id           uuid primary key references profiles(id) on delete cascade,
  vehicle_make text,
  vehicle_model text,
  license_plate text,
  is_approved  boolean not null default false,
  approved_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table driver_locations (
  driver_id     uuid primary key references drivers(id) on delete cascade,
  latitude      double precision not null,
  longitude     double precision not null,
  accuracy      double precision,
  heading       double precision,
  speed         double precision,
  last_updated  timestamptz not null default now()
);

-- ============================================================================
-- ORDERS  (replaces orders/{orderId} + scheduled_orders/{orderId})
-- Line items pulled out into a real table instead of an embedded array/blob.
-- ============================================================================
create table orders (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references profiles(id),
  driver_id           uuid references drivers(id),
  address_id          uuid references addresses(id),
  status              text not null default 'pending'
                        check (status in (
                          'pending', 'confirmed', 'preparing', 'out_for_delivery',
                          'delivered', 'cancelled'
                        )),
  scheduled_for        timestamptz,        -- null = ASAP order; non-null = replaces scheduled_orders
  subtotal            numeric(10,2) not null check (subtotal >= 0),
  delivery_fee        numeric(10,2) not null default 0,
  total               numeric(10,2) not null check (total >= 0),
  last_message        text,
  last_message_at     timestamptz,
  last_message_by     text check (last_message_by in ('customer', 'driver', 'admin')),
  delivery_photo_url  text,
  photo_taken_at      timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index orders_user_id_idx on orders(user_id);
create index orders_driver_id_idx on orders(driver_id);
create index orders_status_idx on orders(status);

create table order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  meal_id     uuid not null references meals(id),
  quantity    int not null check (quantity > 0),
  unit_price  numeric(10,2) not null check (unit_price >= 0),
  notes       text
);
create index order_items_order_id_idx on order_items(order_id);

create table order_reviews (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  user_id     uuid not null references profiles(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),
  unique (order_id, user_id)
);

create table delivery_photos (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders(id) on delete cascade,
  driver_id   uuid not null references drivers(id),
  photo_url   text not null,
  uploaded_at timestamptz not null default now()
);
create index delivery_photos_order_id_idx on delivery_photos(order_id);

-- ── Order-scoped chat: `messages` and `order_messages` were the same
-- feature built twice in Firestore. One table replaces both.
create table order_messages (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references orders(id) on delete cascade,
  sender_id    uuid not null references profiles(id),
  sender_type  text not null check (sender_type in ('customer', 'driver', 'admin')),
  message      text not null,
  read         boolean not null default false,
  created_at   timestamptz not null default now()
);
create index order_messages_order_id_idx on order_messages(order_id);

-- ============================================================================
-- SUPPORT CHAT  (replaces support_chats/{chatId} + support_messages/{messageId})
-- ============================================================================
create table support_chats (
  id                 uuid primary key default gen_random_uuid(),
  customer_id        uuid not null references profiles(id) on delete cascade,
  last_message       text,
  last_message_time  timestamptz,
  unread_count       int not null default 0,
  status             text not null default 'active' check (status in ('active', 'closed')),
  created_at         timestamptz not null default now()
);
create index support_chats_customer_id_idx on support_chats(customer_id);

create table support_messages (
  id           uuid primary key default gen_random_uuid(),
  chat_id      uuid not null references support_chats(id) on delete cascade,
  -- Real admin accounts now exist, so "admin" is a genuine profile row
  -- instead of the literal string 'admin' Firestore used as a stand-in.
  sender_id    uuid not null references profiles(id),
  sender_type  text not null check (sender_type in ('customer', 'admin')),
  message      text not null,
  read         boolean not null default false,
  created_at   timestamptz not null default now()
);
create index support_messages_chat_id_idx on support_messages(chat_id);

create table admin_notifications (
  id          uuid primary key default gen_random_uuid(),
  title       text,
  body        text,
  read        boolean not null default false,
  created_at  timestamptz not null default now()
);

-- NOTE: phone_index and email_phone_links have no equivalent here — the
-- `unique` constraints on profiles.phone / profiles.email do that job
-- natively, and Postgres enforces it atomically at write time instead of
-- via app-level manual checks.

-- ============================================================================
-- updated_at trigger (shared by every table that has the column)
-- ============================================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_set_updated_at before update on profiles
  for each row execute function set_updated_at();
create trigger meals_set_updated_at before update on meals
  for each row execute function set_updated_at();
create trigger drivers_set_updated_at before update on drivers
  for each row execute function set_updated_at();
create trigger orders_set_updated_at before update on orders
  for each row execute function set_updated_at();
