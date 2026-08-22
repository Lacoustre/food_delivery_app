-- The mobile notification page badges each notification by type
-- (order/promo/system) and streams the list live.
alter table user_notifications add column if not exists type text;
alter publication supabase_realtime add table user_notifications;
