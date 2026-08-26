-- Group dish variants so the menu shows one card per base dish.
--
-- 126 dishes reduce to 70 bases: 15 bases carry variants (Jollof with seven
-- proteins, Fufu with eight soups, and so on) while 55 are one-offs. Beyond
-- browsability this is what makes photography tractable — the seven largest
-- groups cover 49 dishes with seven photographs instead of forty-nine.
--
-- Each variant stays its own meals row. Only presentation changes: the cart,
-- pricing and order paths keep working from a single meal id, so nothing in
-- computeValidatedTotals or the payment flow is affected.

alter table meals
  add column if not exists base_name     text,
  add column if not exists base_slug     text,
  add column if not exists variant_label text,
  add column if not exists variant_type  text;

comment on column meals.base_slug is
  'Grouping key. Rows sharing one base_slug render as a single menu card.';
comment on column meals.variant_label is
  'The option shown in the picker (e.g. "Goat Meat"). Null for one-off dishes.';
comment on column meals.variant_type is
  'What the picker is choosing — protein | soup | preparation | side. Drives the picker heading, which is not "protein" for every group.';

-- ── Backfill ────────────────────────────────────────────────────────────
-- Names follow "<base> with <variant>". Split on the first " with ".
update meals
set
  base_name = btrim(split_part(name, ' with ', 1)),
  base_slug = lower(regexp_replace(btrim(split_part(name, ' with ', 1)), '[^a-zA-Z0-9]+', '-', 'g')),
  variant_label = nullif(btrim(substring(name from position(' with ' in name) + 6)), '')
where position(' with ' in name) > 0;

-- Dishes with no " with " are their own base.
update meals
set
  base_name = name,
  base_slug = lower(regexp_replace(name, '[^a-zA-Z0-9]+', '-', 'g'))
where base_slug is null;

-- A "variant" of one is just a dish. Clear the label so those render as
-- ordinary cards rather than a picker with a single option.
update meals m
set variant_label = null
where variant_label is not null
  and (select count(*) from meals x where x.base_slug = m.base_slug) < 2;

-- ── Picker headings ─────────────────────────────────────────────────────
-- The choice is only a protein for the rice and yam dishes. Fufu picks a
-- soup, Banku picks how the fish is cooked, and the stews pick a starch —
-- one hardcoded "Choose your protein" would read wrong on half the menu.
update meals set variant_type = 'soup'        where base_slug in ('fufu', 'rice-ball') and variant_label is not null;
update meals set variant_type = 'preparation' where base_slug in ('banku')             and variant_label is not null;
update meals set variant_type = 'side'        where base_slug in ('eggplant', 'bean-stew', 'spinach-stew', 'egusi') and variant_label is not null;
update meals set variant_type = 'protein'     where variant_label is not null and variant_type is null;

create index if not exists meals_base_slug_idx on meals(base_slug);
