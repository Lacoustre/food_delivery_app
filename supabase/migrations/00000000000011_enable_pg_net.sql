-- Supabase Cron invokes edge functions via HTTP, which requires pg_net.
-- Needed for the dispatch-due-orders job (scheduled/retry Uber dispatch).
create extension if not exists pg_net;
