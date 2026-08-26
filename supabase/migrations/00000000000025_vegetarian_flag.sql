-- Make "vegetarian" a dietary flag rather than a category, a name suffix and a
-- separate menu section all at once.
--
-- All 17 vegetarian dishes sat in category='Vegetarian' AND carried
-- "(Vegetarian)" in the name — the same fact stated twice. Worse, it split the
-- menu: "Jollof Rice (Vegetarian)" ($13.99) lived under Vegetarian while
-- "Jollof with Fried Chicken" ($22.99) lived under Jollof Rice, so a
-- vegetarian looking at the Jollof card never saw the dish they wanted, and
-- the card's price started $9 higher than it needed to.
--
-- As a flag, the meat-free option becomes just another choice in the protein
-- picker, which is what it always was.

alter table meals
  add column if not exists is_vegetarian boolean not null default false;

comment on column meals.is_vegetarian is
  'Dietary flag. Drives the menu filter and the badge on a dish; replaces the old "(Vegetarian)" name suffix and the Vegetarian category.';

update meals
set is_vegetarian = true
where category = 'Vegetarian' or name ilike '%(vegetarian%';

-- ── Names ───────────────────────────────────────────────────────────────
-- Drop the suffix now the flag carries it. Waakye is written
-- "Waakye (Vegetarian, with Tomato Stew)", so it needs handling before the
-- generic strip or the pairing would be lost with it.
update meals
set name = 'Waakye with Tomato Stew'
where name = 'Waakye (Vegetarian, with Tomato Stew)';

update meals
set name = btrim(regexp_replace(name, '\s*\(Vegetarian\)\s*$', '', 'i'))
where name ilike '%(vegetarian)';

-- ── Rejoin the dishes that were really variants ──────────────────────────
-- These are the same dish as their meat versions, minus the meat, so they
-- belong in the picker rather than in a separate section.
update meals set base_slug = 'jollof',     base_name = 'Jollof',     variant_label = 'Vegetarian', variant_type = 'protein' where name = 'Jollof Rice';
update meals set base_slug = 'fried-rice', base_name = 'Fried Rice', variant_label = 'Vegetarian', variant_type = 'protein' where name = 'Fried Rice';
update meals set base_slug = 'waakye',     base_name = 'Waakye',     variant_label = 'Vegetarian', variant_type = 'protein' where name = 'Waakye with Tomato Stew';

-- Four dishes were already inside a group but carried the suffix in their
-- picker label. Strip it, except where a meat version of the same pairing
-- exists — there the words are what tell the two options apart, and the flag
-- alone cannot, since both would read "White Rice".
update meals m
set variant_label = btrim(regexp_replace(variant_label, '\s*\(Vegetarian\)\s*$', '', 'i'))
where m.variant_label ilike '%(vegetarian)'
  and not exists (
    select 1 from meals o
    where o.base_slug = m.base_slug
      and o.id <> m.id
      and o.variant_label = btrim(regexp_replace(m.variant_label, '\s*\(Vegetarian\)\s*$', '', 'i'))
  );

-- ── Guards ──────────────────────────────────────────────────────────────
do $$
declare n int;
begin
  select count(*) into n from meals where name ilike '%(vegetarian%';
  if n > 0 then
    raise exception 'meals: % name(s) still carry the vegetarian suffix', n;
  end if;

  -- Two options with the same label in one picker are indistinguishable.
  select count(*) into n from (
    select base_slug, variant_label from meals
    where variant_label is not null
    group by base_slug, variant_label having count(*) > 1
  ) d;
  if n > 0 then
    raise exception 'meals: % duplicate (base_slug, variant_label) pair(s)', n;
  end if;
end $$;

create index if not exists meals_is_vegetarian_idx on meals(is_vegetarian) where is_vegetarian;
