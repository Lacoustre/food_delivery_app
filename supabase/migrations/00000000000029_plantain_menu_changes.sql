-- Menu corrections from the kitchen.
--
-- 1. "Fried Plantain & Tomato Stew" comes off the menu.
-- 2. "Fried Plantain & Spinach Stew" is actually boiled plantain, not fried.
--
-- Both are the vegetarian variants. The non-vegetarian "Fried Plantain with
-- Spinach Stew" is a different dish and is left alone.

-- Deactivated rather than deleted: order_items reference meals by id, so
-- removing the row would break the history of anyone who already ordered it.
-- active = false hides it from every menu and makes the server refuse it.
update meals
set active = false
where name = 'Fried Plantain & Tomato Stew';

-- Renamed to match the house style for its siblings ("Boiled Yam & Spinach
-- Stew", "Rice & Spinach Stew"). "Vegetarian" stays out of the name — the
-- is_vegetarian flag carries that, and migration 25 removed exactly this kind
-- of duplication.
update meals
set name        = 'Boiled Plantain & Spinach Stew',
    description = 'Boiled plantain with vegetarian spinach stew.',
    base_name   = 'Boiled Plantain & Spinach Stew',
    base_slug   = 'boiled-plantain-spinach-stew'
where name = 'Fried Plantain & Spinach Stew';

do $$
declare n int;
begin
  select count(*) into n from meals
  where name in ('Fried Plantain & Tomato Stew') and active;
  if n > 0 then
    raise exception 'meals: the tomato stew dish is still active';
  end if;

  select count(*) into n from meals where name = 'Boiled Plantain & Spinach Stew';
  if n <> 1 then
    raise exception 'meals: expected exactly one boiled plantain dish, found %', n;
  end if;
end $$;
