-- The wings occupied four separate cards that differed only in how many
-- pieces you got, so a quarter of the Main Dishes grid was the same dish
-- repeated. They become one card with a portion dropdown, the way Fufu and
-- Jollof already work.
--
-- variant_type 'portion' is new — the existing ones are protein, soup, side
-- and preparation. The menu maps it to "Choose your portion"; without that
-- entry it would fall back to "Choose an option".
update meals
set base_slug        = 'african-style-chicken-wings',
    base_name        = 'African Style Chicken Wings',
    variant_type     = 'portion',
    base_description = 'Chicken wings, African style.',
    variant_label    = case
                         when name like '%(5 Pieces)%'  then '5 Pieces'
                         when name like '%(10 Pieces)%' then '10 Pieces'
                         when name like '%(15 Pieces)%' then '15 Pieces'
                         when name like '%(20 Pieces)%' then '20 Pieces'
                       end
where name like 'African Style Chicken Wings (%Pieces)%';

-- Every one of the four has to end up with a label, or it drops out of the
-- grouped card and becomes invisible on the menu.
do $$
declare
  orphans int;
begin
  select count(*) into orphans
  from meals
  where base_slug = 'african-style-chicken-wings' and variant_label is null;

  if orphans > 0 then
    raise exception 'Wings variant % row(s) have no label — they would vanish from the menu', orphans;
  end if;
end $$;
