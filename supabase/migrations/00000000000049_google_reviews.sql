-- Reviews synced from the Google Business Profile API.
--
-- Separate from `reviews` on purpose: that table requires user_id referencing
-- profiles, and a Google reviewer has no account here. Mixing them would mean
-- either a nullable foreign key or fake profile rows.
--
-- Google's review name is the primary key, so a re-sync updates in place —
-- ratings and text can be edited by the reviewer, and a business reply can be
-- added later.

create table if not exists google_reviews (
  -- e.g. accounts/123/locations/456/reviews/AbC — stable per review.
  name           text primary key,
  reviewer_name  text not null,
  reviewer_photo text,
  rating         int  not null check (rating between 1 and 5),
  comment        text,
  reply          text,
  reply_at       timestamptz,
  created_at     timestamptz not null,
  updated_at     timestamptz,
  synced_at      timestamptz not null default now()
);

create index if not exists google_reviews_created_at_idx
  on google_reviews(created_at desc);

-- Only reviews with something written are worth showing in a carousel; a bare
-- star rating with no text reads as filler.
create index if not exists google_reviews_with_comment_idx
  on google_reviews(rating desc, created_at desc)
  where comment is not null and comment <> '';

alter table google_reviews enable row level security;

-- Public: they are already public on Google.
create policy "google_reviews_public_read" on google_reviews
  for select using (true);

-- Written only by the sync function, which uses the service role and bypasses
-- RLS. No policy for insert/update/delete means nobody else can write.

comment on table google_reviews is
  'Synced from the Google Business Profile API by the sync-google-reviews edge function. Never written by the apps.';
