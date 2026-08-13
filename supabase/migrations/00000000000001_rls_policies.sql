-- ============================================================================
-- Row-Level Security — mirrors firestore.rules / storage.rules 1:1.
-- ============================================================================

-- ── Helper: is the current user an admin? ──────────────────────────────────
create or replace function is_admin()
returns boolean as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;
-- security definer + stable: runs with elevated privilege so it can read
-- profiles regardless of the caller's own row-level policy, same as
-- Firestore's exists()/get() calls run with elevated privilege.

alter table profiles enable row level security;
alter table addresses enable row level security;
alter table user_notifications enable row level security;
alter table complaints enable row level security;
alter table meals enable row level security;
alter table favorites enable row level security;
alter table reviews enable row level security;
alter table settings enable row level security;
alter table drivers enable row level security;
alter table driver_locations enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table order_reviews enable row level security;
alter table delivery_photos enable row level security;
alter table order_messages enable row level security;
alter table support_chats enable row level security;
alter table support_messages enable row level security;
alter table admin_notifications enable row level security;

-- ── profiles ─────────────────────────────────────────────────────────────
create policy "profiles_select_own_or_admin" on profiles for select
  using (auth.uid() = id or is_admin());
create policy "profiles_update_own" on profiles for update
  using (auth.uid() = id)
  -- A non-admin can update their own row, but can't grant themselves the
  -- admin role — mirrors admins/{uid}'s "allow write: if false" lockout.
  with check (auth.uid() = id and (role = 'customer' or role = 'driver'));
create policy "profiles_insert_own" on profiles for insert
  with check (auth.uid() = id);

-- ── addresses / user_notifications / complaints (owner-only) ───────────────
create policy "addresses_owner" on addresses for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_notifications_owner" on user_notifications for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "complaints_owner" on complaints for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── meals — public read, admin write ────────────────────────────────────
create policy "meals_public_read" on meals for select using (true);
create policy "meals_admin_write" on meals for insert with check (is_admin());
create policy "meals_admin_update" on meals for update using (is_admin());
create policy "meals_admin_delete" on meals for delete using (is_admin());

-- ── favorites (owner-only) ───────────────────────────────────────────────
create policy "favorites_owner" on favorites for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── reviews — public read, owner write, admin override ──────────────────
create policy "reviews_public_read" on reviews for select using (true);
create policy "reviews_owner_insert" on reviews for insert
  with check (auth.uid() = user_id);
create policy "reviews_owner_or_admin_update" on reviews for update
  using (auth.uid() = user_id or is_admin());
create policy "reviews_owner_or_admin_delete" on reviews for delete
  using (auth.uid() = user_id or is_admin());

-- ── settings — public read, admin write ─────────────────────────────────
create policy "settings_public_read" on settings for select using (true);
create policy "settings_admin_write" on settings for insert with check (is_admin());
create policy "settings_admin_update" on settings for update using (is_admin());

-- ── drivers ──────────────────────────────────────────────────────────────
create policy "drivers_signed_in_read" on drivers for select
  using (auth.uid() is not null);
create policy "drivers_owner_insert" on drivers for insert
  with check (auth.uid() = id);
create policy "drivers_owner_or_admin_update" on drivers for update
  using (auth.uid() = id or is_admin());

-- ── driver_locations ─────────────────────────────────────────────────────
-- Same known limitation as firestore.rules: any signed-in user can read any
-- driver's live location (needed so a customer can watch their delivery,
-- but nothing here scopes it to "their" driver specifically). Tightening
-- this means joining through orders — worth doing as a follow-up.
create policy "driver_locations_signed_in_read" on driver_locations for select
  using (auth.uid() is not null);
create policy "driver_locations_owner_write" on driver_locations for insert
  with check (auth.uid() = driver_id);
create policy "driver_locations_owner_update" on driver_locations for update
  using (auth.uid() = driver_id);

-- ── orders ───────────────────────────────────────────────────────────────
create policy "orders_participant_or_admin_read" on orders for select
  using (auth.uid() = user_id or auth.uid() = driver_id or is_admin());
create policy "orders_owner_insert" on orders for insert
  with check (auth.uid() = user_id);
create policy "orders_participant_or_admin_update" on orders for update
  using (auth.uid() = user_id or auth.uid() = driver_id or is_admin());

-- ── order_items — access follows the parent order ───────────────────────
create policy "order_items_via_order" on order_items for select
  using (exists (
    select 1 from orders o where o.id = order_id
      and (auth.uid() = o.user_id or auth.uid() = o.driver_id or is_admin())
  ));
create policy "order_items_via_order_insert" on order_items for insert
  with check (exists (
    select 1 from orders o where o.id = order_id and auth.uid() = o.user_id
  ));

-- ── order_reviews ────────────────────────────────────────────────────────
create policy "order_reviews_public_read" on order_reviews for select using (true);
create policy "order_reviews_owner_insert" on order_reviews for insert
  with check (auth.uid() = user_id);
create policy "order_reviews_owner_or_admin_update" on order_reviews for update
  using (auth.uid() = user_id or is_admin());
create policy "order_reviews_owner_or_admin_delete" on order_reviews for delete
  using (auth.uid() = user_id or is_admin());

-- ── delivery_photos ──────────────────────────────────────────────────────
create policy "delivery_photos_participant_or_admin_read" on delivery_photos for select
  using (
    auth.uid() = driver_id or is_admin() or
    exists (select 1 from orders o where o.id = order_id and o.user_id = auth.uid())
  );
create policy "delivery_photos_driver_insert" on delivery_photos for insert
  with check (auth.uid() = driver_id);

-- ── order_messages ───────────────────────────────────────────────────────
create policy "order_messages_participant_or_admin_read" on order_messages for select
  using (
    auth.uid() = sender_id or is_admin() or
    exists (
      select 1 from orders o where o.id = order_id
        and (auth.uid() = o.user_id or auth.uid() = o.driver_id)
    )
  );
create policy "order_messages_sender_insert" on order_messages for insert
  with check (auth.uid() = sender_id);
create policy "order_messages_participant_or_admin_update" on order_messages for update
  using (
    auth.uid() = sender_id or is_admin() or
    exists (
      select 1 from orders o where o.id = order_id
        and (auth.uid() = o.user_id or auth.uid() = o.driver_id)
    )
  );

-- ── support_chats ────────────────────────────────────────────────────────
create policy "support_chats_owner_or_admin_read" on support_chats for select
  using (auth.uid() = customer_id or is_admin());
create policy "support_chats_owner_insert" on support_chats for insert
  with check (auth.uid() = customer_id);
create policy "support_chats_owner_or_admin_update" on support_chats for update
  using (auth.uid() = customer_id or is_admin());

-- ── support_messages ─────────────────────────────────────────────────────
create policy "support_messages_owner_or_admin_read" on support_messages for select
  using (
    is_admin() or
    exists (select 1 from support_chats c where c.id = chat_id and c.customer_id = auth.uid())
  );
create policy "support_messages_insert" on support_messages for insert
  with check (
    (sender_type = 'customer' and sender_id = auth.uid()) or
    (sender_type = 'admin' and is_admin() and sender_id = auth.uid())
  );

-- ── admin_notifications — admin-only ─────────────────────────────────────
create policy "admin_notifications_admin_only" on admin_notifications for all
  using (is_admin()) with check (is_admin());
