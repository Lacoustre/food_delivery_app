-- A harder pass over the lot. These sit under a dish name and above a
-- dropdown, clamped to two lines — a clause is all they get. Anything a photo
-- already shows is not worth saying.
--
-- Kept in full: the peanut warning and the eggplant meat disclosure. Those are
-- the two a customer could be harmed or annoyed by not knowing, and brevity is
-- not worth either.

update meals set base_description = 'Fried yam, crisp outside and soft in the middle.' where base_slug = 'fried-yam';
update meals set base_description = 'Garden egg stew. Smoked turkey and oxtail included.'  where base_slug = 'eggplant';
update meals set base_description = 'Fermented corn and cassava dough, slightly sour.'     where base_slug = 'banku';
update meals set base_description = 'Soft rice balls, for scooping up soup.'               where base_slug = 'rice-ball';
update meals set base_description = 'Bean stew in palm oil, with fried plantain.'          where base_slug = 'red-red';
update meals set base_description = 'Smoky rice in a tomato and pepper base.'              where base_slug = 'jollof';
update meals set base_description = 'Rice stir-fried with vegetables.'                     where base_slug = 'fried-rice';
update meals set base_description = 'White rice with tomato and pepper stew.'              where base_slug = 'rice-stew';
update meals set base_description = 'Beans slow-cooked in a tomato base.'                  where base_slug = 'bean-stew';
update meals set base_description = 'Boiled yam with spinach stew.'                        where base_slug = 'boiled-yam-spinach-stew';
update meals set base_description = 'White rice with spinach stew.'                        where base_slug = 'rice-spinach-stew';
update meals set base_description = 'Pounded yam with egusi soup.'                         where base_slug = 'pounded-yam';
update meals set base_description = 'Slow-cooked spinach stew.'                            where base_slug = 'spinach';
update meals set base_description = 'Groundnut soup. Contains peanuts.'                    where base_slug = 'peanut-soup';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and base_slug = 'peanut-soup' and base_description not ilike '%peanut%';
  if n > 0 then raise exception 'meals: peanut soup lost its allergen warning'; end if;

  select count(*) into n from meals
  where active and base_slug = 'eggplant' and base_description not like '%oxtail%';
  if n > 0 then raise exception 'meals: eggplant lost its oxtail disclosure'; end if;

  select count(*) into n from meals
  where active and base_slug = 'check-check' and base_description not like '%Wednesdays only%';
  if n > 0 then raise exception 'meals: Check Check lost its Wednesday note'; end if;

  select count(*) into n from (
    select base_slug from meals where active and base_slug is not null
    group by base_slug having count(*) > 1 and count(base_description) = 0
  ) d;
  if n > 0 then raise exception 'meals: % multi-variant card(s) have no base_description', n; end if;
end $$;
