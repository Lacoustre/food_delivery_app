-- Support chat moves off Firestore: both clients stream these tables live,
-- and the admin panel can delete a conversation (messages cascade via the
-- existing FK). RLS had select/insert/update but no delete policies.
create policy "support_chats_admin_delete" on support_chats for delete using (is_admin());
create policy "support_messages_admin_delete" on support_messages for delete using (is_admin());

alter publication supabase_realtime add table support_chats;
alter publication supabase_realtime add table support_messages;
