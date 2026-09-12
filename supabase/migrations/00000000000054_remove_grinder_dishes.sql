-- The restaurant has taken the takeout-grinder dishes off the menu.
--
--   Peanut Soup with Fried Plantain (Grinder)      $24.99
--   Peanut Soup with Boiled Yam (Grinder)          $26.99
--   Peanut & Spinach with Boiled Yam (Grinder)     $26.99
--   Spinach with Fried Plantain (Grinder)          $24.99
--   Spinach with Boiled Yam (Grinder)              $26.99
--
-- These are every variant of the "Peanut Soup" and "Spinach" cards, so both
-- cards disappear from the menu with them. Neither cuisine is lost: peanut
-- soup remains under Fufu and Rice Ball, and spinach stew under Boiled Yam,
-- Rice and Boiled Plantain.
--
-- As with the hidden duplicates, order_items.meal_id has no ON DELETE clause,
-- so a dish that appears in a past order is left in place and named rather
-- than failing the migration — an order must not lose what was bought. Such a
-- dish is deactivated instead, which takes it off the menu just as
-- effectively.
do $$
declare
  stuck record;
  removed int;
begin
  for stuck in
    select m.id, m.name
    from meals m
    where m.variant_label ilike '%grinder%'
      and exists (select 1 from order_items oi where oi.meal_id = m.id)
  loop
    update meals set active = false where id = stuck.id;
    raise notice 'Hidden rather than deleted (appears in a past order): %', stuck.name;
  end loop;

  delete from meals m
  where m.variant_label ilike '%grinder%'
    and not exists (select 1 from order_items oi where oi.meal_id = m.id);

  get diagnostics removed = row_count;
  raise notice 'Removed % grinder dish(es)', removed;
end $$;
