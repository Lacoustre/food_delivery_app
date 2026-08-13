-- The webapp's menu display subscribes to live meal changes (admin edits
-- price/availability), same pattern as orders.
alter publication supabase_realtime add table meals;
