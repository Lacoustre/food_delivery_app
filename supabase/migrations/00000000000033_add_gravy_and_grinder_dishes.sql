-- Four dishes on the printed master menu that were never in the database.
--
--   Gravy w goatmeat              $29.99
--   Gravy w chicken               $24.99
--   Gravy w Fish                  $27.99
--   Peanut w spinach, Boiled Yam  $26.99
--
-- The three Gravy dishes differ only by protein, so they become one card with
-- a protein picker, the same shape as Jollof and Peanut Soup. The printed menu
-- files them under "Individual Items" — which maps to Side Dishes on the site
-- — but at $24.99-$29.99 they are priced as mains, and nobody looking for a
-- main course looks under Side Dishes. menu_section says Main Dishes; the
-- category is left as printed so the kitchen's own listing still matches.
--
-- Already applied to production over the REST API (the CLI session had
-- expired); this file exists so a fresh database reaches the same state.

insert into meals (
  slug, name, description, price, category,
  base_slug, base_name, variant_label, variant_type,
  menu_section, image_url, active, available, is_vegetarian
)
values
  ('gravy-with-goat-meat', 'Gravy with Goat Meat',
   'Gravy served with goat meat.', 29.99, 'Individual Items',
   'gravy', 'Gravy', 'Goat Meat', 'protein', 'Main Dishes', '', true, true, false),

  ('gravy-with-fish', 'Gravy with Fish',
   'Gravy served with fish.', 27.99, 'Individual Items',
   'gravy', 'Gravy', 'Fish', 'protein', 'Main Dishes', '', true, true, false),

  ('gravy-with-chicken', 'Gravy with Chicken',
   'Gravy served with chicken.', 24.99, 'Individual Items',
   'gravy', 'Gravy', 'Chicken', 'protein', 'Main Dishes', '', true, true, false),

  -- A third variant of the existing peanut-soup group, alongside Boiled Yam
  -- and Fried Plantain.
  ('peanut-and-spinach-with-boiled-yam-grinder',
   'Peanut & Spinach with Boiled Yam (Grinder)',
   'Peanut soup and spinach stew with boiled yam.', 26.99, 'Local Grinder Dishes',
   'peanut-soup', 'Peanut Soup', 'Spinach & Boiled Yam (Grinder)', 'protein',
   'Main Dishes', '', true, true, false)
on conflict (slug) do nothing;

do $$
declare n int;
begin
  select count(*) into n from meals where base_slug = 'gravy' and active;
  if n <> 3 then
    raise exception 'meals: expected 3 active gravy variants, found %', n;
  end if;

  select count(*) into n from meals where base_slug = 'peanut-soup' and active;
  if n <> 3 then
    raise exception 'meals: expected 3 active peanut soup variants, found %', n;
  end if;
end $$;
