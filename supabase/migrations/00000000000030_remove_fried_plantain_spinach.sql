-- "Fried Plantain with Spinach Stew" comes off the menu as well.
--
-- This is the non-vegetarian one (smoked turkey and beef, $24.99), a separate
-- dish from the vegetarian pair handled in migration 29. Deactivated rather
-- than deleted for the same reason: order_items reference meals by id.

update meals
set active = false
where name = 'Fried Plantain with Spinach Stew';

do $$
declare n int;
begin
  select count(*) into n from meals
  where name = 'Fried Plantain with Spinach Stew' and active;
  if n > 0 then
    raise exception 'meals: the dish is still active';
  end if;
end $$;
