-- A card with a variant picker showed the selected variant's description,
-- which restated what the dropdown already said: "Jollof rice served with
-- fried chicken" sitting directly above a dropdown reading "Fried Chicken".
-- The description earned nothing and the customer learned nothing about the
-- dish itself.
--
-- base_description describes the dish; the dropdown carries the choice. Only
-- multi-variant cards need one — a single dish keeps its own description.
--
-- Operational and allergen detail is deliberately carried over: Check Check is
-- Wednesdays only, eggplant contains smoked turkey and oxtail in every
-- variant, and peanut soup says so in words rather than relying on a customer
-- reading "Chicken Peanut Soup" in a dropdown.

alter table meals add column if not exists base_description text;

update meals set base_description = 'Yam cut thick and fried until golden, crisp at the edges and soft in the middle.' where base_slug = 'fried-yam';
update meals set base_description = 'Rice stir-fried with mixed vegetables and seasoning.' where base_slug = 'fried-rice';
update meals set base_description = 'Soft, stretchy pounded fufu, served in a bowl of soup.' where base_slug = 'fufu';
update meals set base_description = 'Smoky party rice, slow-cooked in a tomato and pepper base.' where base_slug = 'jollof';
update meals set base_description = 'Rice and beans cooked together until they take on their deep red colour.' where base_slug = 'waakye';
update meals set base_description = 'Fermented corn and cassava dough, smooth and slightly sour.' where base_slug = 'banku';
update meals set base_description = 'White rice with a rich tomato and pepper stew.' where base_slug = 'rice-stew';
update meals set base_description = 'Beans slow-cooked in a seasoned tomato base.' where base_slug = 'bean-stew';
update meals set base_description = 'Garden egg stew, cooked down slowly. Smoked turkey and oxtail included.' where base_slug = 'eggplant';
update meals set base_description = 'Moulded balls of soft white rice, made for scooping up soup.' where base_slug = 'rice-ball';
update meals set base_description = 'Groundnut soup, rich and slow-simmered. Contains peanuts.' where base_slug = 'peanut-soup';
update meals set base_description = 'Rich tomato gravy, slow-cooked.' where base_slug = 'gravy';
update meals set base_description = 'Seasoned Indomie noodles, stir-fried.' where base_slug = 'indomie';
update meals set base_description = 'Bean stew cooked in palm oil, served with fried plantain.' where base_slug = 'red-red';
update meals set base_description = 'Boiled yam with a slow-cooked spinach stew.' where base_slug = 'boiled-yam-spinach-stew';
update meals set base_description = 'Jollof rice and vegetables, wrapped.' where base_slug = 'jollof-veggie-wrap';
update meals set base_description = 'White rice with a slow-cooked spinach stew.' where base_slug = 'rice-spinach-stew';
update meals set base_description = 'Rice, egg, beans and salad on one plate. Available Wednesdays only.' where base_slug = 'check-check';
update meals set base_description = 'Fermented corn dough, steamed in husks.' where base_slug = 'kenkey';
update meals set base_description = 'Spinach stew, slow-cooked with seasoning.' where base_slug = 'spinach';
update meals set base_description = 'Jollof rice wrapped up.' where base_slug = 'jollof-wrap';
update meals set base_description = 'Smooth pounded yam, served with egusi soup.' where base_slug = 'pounded-yam';

do $$
declare n int;
begin
  -- Every card with a picker must have one, or it falls back to restating the
  -- dropdown.
  select count(*) into n from (
    select base_slug from meals
    where active and base_slug is not null
    group by base_slug
    having count(*) > 1 and count(base_description) = 0
  ) d;
  if n > 0 then
    raise exception 'meals: % multi-variant card(s) have no base_description', n;
  end if;

  select count(*) into n from meals
  where active and base_slug = 'check-check' and base_description not like '%Wednesdays only%';
  if n > 0 then raise exception 'meals: Check Check lost its Wednesday note'; end if;

  select count(*) into n from meals
  where active and base_slug = 'eggplant' and base_description not like '%oxtail%';
  if n > 0 then raise exception 'meals: eggplant lost its oxtail disclosure'; end if;
end $$;
