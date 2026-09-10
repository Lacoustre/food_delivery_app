-- Merge dishes that render as two identical cards.
--
-- Red Red and Check Check each exist twice: a normal version and a vegetarian
-- one, same name, same price. On the menu that is two cards reading "Red Red"
-- with nothing to tell them apart. They are the same dish with and without
-- meat, which is exactly what the variant picker is for — the same treatment
-- migration 25 gave Jollof, Fried Rice and Waakye.

-- ── Red Red ─────────────────────────────────────────────────────────────
update meals set base_slug = 'red-red', base_name = 'Red Red',
       variant_label = 'With Chicken', variant_type = 'protein'
where base_slug = 'red-red' and is_vegetarian = false;

update meals set base_slug = 'red-red', base_name = 'Red Red',
       variant_label = 'Vegetarian', variant_type = 'protein'
where base_slug = 'red-red-vegetarian-';

-- ── Check Check ─────────────────────────────────────────────────────────
update meals set base_slug = 'check-check', base_name = 'Check Check',
       variant_label = 'With Meat', variant_type = 'protein'
where base_slug = 'check-check' and is_vegetarian = false;

update meals set base_slug = 'check-check', base_name = 'Check Check',
       variant_label = 'Vegetarian', variant_type = 'protein'
where base_slug = 'check-check-vegetarian-';

-- ── Rice Ball ───────────────────────────────────────────────────────────
-- Not a vegetarian twin: migration 24 split the $4.99 single ball out of the
-- soup dishes deliberately. But both cards still read "Rice Ball", so the
-- side portion says so.
update meals set base_name = 'Rice Ball (Side)'
where base_slug = 'rice-ball-side';

do $$
declare n int;
begin
  select count(*) into n from (
    select base_name from meals where active
    group by base_name having count(distinct base_slug) > 1
  ) d;
  -- Jollof Veggie Wrap and Indomie are still pending a decision, so two
  -- duplicate names are expected here for now.
  if n > 2 then
    raise exception 'meals: % base names still span multiple cards', n;
  end if;
end $$;
