-- Admin-panel's Reviews.tsx lets staff reply to a customer review — the
-- original schema had no field for that.
alter table order_reviews
  add column admin_reply text,
  add column admin_reply_date timestamptz;
