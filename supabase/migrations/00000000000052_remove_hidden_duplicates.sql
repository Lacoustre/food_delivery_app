-- Removes three dishes that were hidden rather than deleted during the menu
-- merge, so they sat in the admin panel forever as a count nobody could
-- explain. They have been invisible to customers throughout: the website
-- filters on active, so deleting them changes nothing a customer sees.
--
--   Alvaro (Malt Drink)                $3.99   Drinks
--   Fried Plantain & Tomato Stew      $24.99   Main Dishes
--   Fried Plantain with Spinach Stew  $24.99   Main Dishes
--
-- order_items.meal_id has no ON DELETE clause, so a dish that appears in any
-- past order cannot be deleted — an order must not lose the record of what
-- was actually bought. Rather than failing the whole migration, anything an
-- order still refers to is left hidden exactly as it is, and named in the
-- output. favorites and reviews do cascade, which is fine: a dish no customer
-- can see cannot be meaningfully favourited or reviewed from here on.
do $$
declare
  doomed uuid[] := array[
    'bfbcfe65-7608-48b9-89bc-779bf8f4dad3',  -- Alvaro (Malt Drink)
    'f6489f9f-f976-49a1-8e4d-bf362b712350',  -- Fried Plantain & Tomato Stew
    '47f62040-7641-4011-964e-d2313717e811'   -- Fried Plantain with Spinach Stew
  ]::uuid[];
  kept record;
  removed int;
begin
  for kept in
    select m.id, m.name
    from meals m
    where m.id = any(doomed)
      and exists (select 1 from order_items oi where oi.meal_id = m.id)
  loop
    raise notice 'Kept % (%): it appears in a past order', kept.name, kept.id;
  end loop;

  delete from meals m
  where m.id = any(doomed)
    and not exists (select 1 from order_items oi where oi.meal_id = m.id);

  get diagnostics removed = row_count;
  raise notice 'Removed % hidden duplicate(s)', removed;
end $$;
