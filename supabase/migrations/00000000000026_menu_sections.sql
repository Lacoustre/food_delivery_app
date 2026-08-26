-- Collapse 24 categories into the handful of headings a customer expects.
--
-- The menu was grouped by dish family — "Jollof Rice", "Fried Yam Dishes",
-- "Banku Dishes", "Egusi Dishes", "Acheke" — which produced 24 headings, half
-- of them over one or two dishes. Those names describe the food rather than
-- helping anyone find it, and now that variants collapse into one card the
-- headings were often longer than the sections beneath them.
--
-- category is kept as-is: the admin panel edits it, and it still carries the
-- dish-family detail. menu_section is purely how the menu is grouped on screen.

alter table meals
  add column if not exists menu_section text;

comment on column meals.menu_section is
  'Heading the dish appears under on the menu. Coarse on purpose — category keeps the dish-family detail for the admin panel.';

-- Default everything to mains, then carve out the exceptions.
update meals set menu_section = 'Main Dishes';

update meals set menu_section = 'Drinks'   where category = 'Drinks';
update meals set menu_section = 'Desserts' where category = 'Desserts';

-- "Individual Items" mixed two different things. The balls and the plantain
-- are $4.99–7.99 accompaniments; the "(Individual)" rice dishes are ~$14
-- single portions of a main and belong with the mains.
update meals
set menu_section = 'Sides'
where category = 'Individual Items'
  and (name ilike '%ball%' or name ilike '%plantain%');

-- Shito and similar condiments, wherever they were filed.
update meals
set menu_section = 'Sides'
where name ilike '%shito%';

do $$
declare n int;
begin
  select count(*) into n from meals where menu_section is null;
  if n > 0 then
    raise exception 'meals: % row(s) have no menu_section', n;
  end if;

  select count(distinct menu_section) into n from meals;
  if n > 6 then
    raise exception 'meals: % menu sections — the point was to have few', n;
  end if;
end $$;

create index if not exists meals_menu_section_idx on meals(menu_section);
