-- Profile photos move from Firebase Storage to a Supabase Storage bucket.
-- Public read (avatars render in admin/support views); each user writes
-- only inside their own uid-named folder. The URL is mirrored onto the
-- profile row so web/admin can show it without touching Firebase.
alter table profiles add column if not exists avatar_url text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy "avatars_public_read" on storage.objects for select
  using (bucket_id = 'avatars');
create policy "avatars_owner_insert" on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "avatars_owner_update" on storage.objects for update
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "avatars_owner_delete" on storage.objects for delete
  using (bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]);
