-- Supabase Cron stores its jobs in cron.job, provided by pg_cron —
-- pg_net (already enabled) only covers the HTTP call side.
create extension if not exists pg_cron;
