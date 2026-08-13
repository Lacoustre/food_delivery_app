-- Firestore's meals track two independent flags: `active` (shown in the
-- menu at all) and `available` (temporarily out of stock). The original
-- schema only had `active` — adding `available` for parity with Meals.tsx.
alter table meals add column available boolean not null default true;

-- Storage bucket for meal photos (mirrors the Firestore Storage `meals/`
-- path) — public read so the menu can display images unauthenticated,
-- admin-only write.
insert into storage.buckets (id, name, public)
values ('meals', 'meals', true)
on conflict (id) do nothing;

create policy "meals_images_public_read" on storage.objects for select
  using (bucket_id = 'meals');
create policy "meals_images_admin_write" on storage.objects for insert
  with check (bucket_id = 'meals' and public.is_admin());
create policy "meals_images_admin_update" on storage.objects for update
  using (bucket_id = 'meals' and public.is_admin());
create policy "meals_images_admin_delete" on storage.objects for delete
  using (bucket_id = 'meals' and public.is_admin());
