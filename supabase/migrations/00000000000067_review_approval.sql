-- Reviews customers leave on their orders are approved by the restaurant
-- before they appear on the website.
--
-- Until now every review was readable by anyone and nothing was approved; the
-- homepage didn't show them at all. Approval publishes a review on the
-- website. It has nothing to do with Google: a business can't post reviews
-- there for a customer. The site instead invites every reviewer, whatever
-- they rated, to post on Google themselves.

alter table order_reviews
  add column if not exists is_approved boolean not null default false,
  add column if not exists approved_at timestamptz;

-- ── Who may set what ────────────────────────────────────────────────────────
-- The owner-update policy let a customer change any column of their own
-- review — including approving it, or writing the restaurant's reply under
-- it. Row-level security can't restrict columns, so a trigger does.
create or replace function order_reviews_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Staff, and the service role used by server code, decide approval and
  -- write replies.
  if is_admin() or coalesce(auth.role(), '') = 'service_role' then
    if not new.is_approved then
      new.approved_at := null;
    elsif tg_op = 'INSERT' then
      new.approved_at := now();
    elsif not old.is_approved then
      new.approved_at := now();
    end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.is_approved := false;
    new.approved_at := null;
    new.admin_reply := null;
    new.admin_reply_date := null;
  else
    new.admin_reply := old.admin_reply;
    new.admin_reply_date := old.admin_reply_date;
    -- An edited review goes back for approval; anything else keeps its state.
    if new.rating is distinct from old.rating or new.comment is distinct from old.comment then
      new.is_approved := false;
      new.approved_at := null;
    else
      new.is_approved := old.is_approved;
      new.approved_at := old.approved_at;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists order_reviews_guard on order_reviews;
create trigger order_reviews_guard
  before insert or update on order_reviews
  for each row execute function order_reviews_guard();

-- ── Reading ─────────────────────────────────────────────────────────────────
-- Unapproved reviews are between the customer and the restaurant.
drop policy if exists "order_reviews_public_read" on order_reviews;
create policy "order_reviews_read" on order_reviews for select
  using (is_approved or auth.uid() = user_id or is_admin());

-- ── Writing ─────────────────────────────────────────────────────────────────
-- Only checked that the row carried the caller's own id, so anyone signed in
-- could review any order, including orders that weren't theirs. Now it has to
-- be their own order, and one that has reached them.
drop policy if exists "order_reviews_owner_insert" on order_reviews;
create policy "order_reviews_owner_insert" on order_reviews for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from orders o
      where o.id = order_id
        and o.user_id = auth.uid()
        and o.status in ('delivered', 'picked up', 'completed')
    )
  );

-- ── The homepage ────────────────────────────────────────────────────────────
-- Reviewer names live in profiles, which only their owner can read. This
-- hands out a first name and last initial — "Prince N." — and nothing else,
-- for approved reviews with something written.
create or replace function approved_reviews(max_count int default 12)
returns table (
  id uuid,
  reviewer text,
  rating int,
  comment text,
  dishes text,
  created_at timestamptz
)
language sql security definer stable set search_path = public as $$
  select
    r.id,
    case
      when p.name is null or trim(p.name) = '' then 'Customer'
      when position(' ' in trim(p.name)) = 0 then initcap(trim(p.name))
      else initcap(split_part(trim(p.name), ' ', 1)) || ' '
        || upper(left(regexp_replace(trim(p.name), '^.*\s+', ''), 1)) || '.'
    end,
    r.rating,
    r.comment,
    (select string_agg(distinct oi.name, ', ') from order_items oi where oi.order_id = r.order_id),
    r.created_at
  from order_reviews r
  left join profiles p on p.id = r.user_id
  where r.is_approved and coalesce(trim(r.comment), '') <> ''
  order by r.approved_at desc nulls last, r.created_at desc
  limit least(greatest(max_count, 1), 50);
$$;

grant execute on function approved_reviews(int) to anon, authenticated;
