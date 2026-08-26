-- Separate the plain Rice Ball from the Rice Ball soup dishes.
--
-- The backfill in migration 23 grouped all four rows under base_slug
-- 'rice-ball'. Three are $24.99–26.99 mains sold with a soup; the fourth is a
-- $4.99 rice ball on its own, which is a side portion rather than a variant of
-- the same dish. Left grouped it would render a blank option in the picker and
-- advertise the card as "from $4.99" for meals that actually cost $24.99 —
-- a price a customer would reasonably expect us to honour.

update meals
set base_slug = 'rice-ball-side',
    base_name = 'Rice Ball'
where name = 'Rice Ball'
  and variant_label is null;

-- Guard against the same shape reappearing: any row still sitting inside a
-- multi-row group without a label would render as an unlabelled choice.
do $$
declare orphan_count int;
begin
  select count(*) into orphan_count
  from meals m
  where m.variant_label is null
    and (select count(*) from meals x where x.base_slug = m.base_slug) > 1;

  if orphan_count > 0 then
    raise exception 'meals: % row(s) sit in a variant group without a variant_label', orphan_count;
  end if;
end $$;
