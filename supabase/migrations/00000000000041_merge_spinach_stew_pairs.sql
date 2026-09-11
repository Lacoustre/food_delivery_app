-- Two dishes each existed as two separate cards, vegetarian and not, under
-- names similar enough that a customer had to work out they were the same
-- dish: "Rice & Spinach Stew" $23.99 alongside "White Rice with Spinach Stew"
-- $25.99, and the same again for boiled yam.
--
-- Grouped the way red-red, indomie and jollof-veggie-wrap already are: one
-- card, a picker beneath, is_vegetarian carrying the dietary fact. Variant
-- prices differ, which the model already supports — jollof's eight proteins
-- range from $13.99 to $29.99.
--
-- "Spinach with Boiled Yam (Grinder)" is deliberately left alone. It is a
-- Local Grinder dish, a different preparation rather than a third variant.
--
-- The group photo is the vegetarian one in both cases. Every variant in a
-- group shares one image, and showing a meat dish to someone who has just
-- selected "Vegetarian" is the error that matters; the reverse only
-- undersells. It also gives White Rice with Spinach Stew a photo, which it
-- did not have.

update meals set base_slug = 'rice-spinach-stew', base_name = 'Rice & Spinach Stew',
  variant_label = 'Vegetarian', variant_type = 'protein',
  image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/rice-spinach-stew-vegetarian-.jpg'
where slug = 'rice-spinach-stew-vegetarian';

update meals set base_slug = 'rice-spinach-stew', base_name = 'Rice & Spinach Stew',
  variant_label = 'Smoked Turkey & Beef', variant_type = 'protein',
  image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/rice-spinach-stew-vegetarian-.jpg'
where slug = 'white-rice-with-spinach-stew';

update meals set base_slug = 'boiled-yam-spinach-stew', base_name = 'Boiled Yam & Spinach Stew',
  variant_label = 'Vegetarian', variant_type = 'protein',
  image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/boiled-yam-spinach-stew-vegetarian-.jpg'
where slug = 'boiled-yam-spinach-stew-vegetarian';

update meals set base_slug = 'boiled-yam-spinach-stew', base_name = 'Boiled Yam & Spinach Stew',
  variant_label = 'Smoked Turkey & Beef', variant_type = 'protein',
  image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/boiled-yam-spinach-stew-vegetarian-.jpg'
where slug = 'boiled-yam-with-spinach-stew';

do $$
declare n int;
begin
  select count(*) into n from meals where active and base_slug = 'rice-spinach-stew';
  if n <> 2 then raise exception 'meals: expected 2 rice & spinach variants, found %', n; end if;

  select count(*) into n from meals where active and base_slug = 'boiled-yam-spinach-stew';
  if n <> 2 then raise exception 'meals: expected 2 boiled yam & spinach variants, found %', n; end if;

  select count(*) into n from meals
  where active and base_slug in ('rice-spinach-stew','boiled-yam-spinach-stew')
    and coalesce(image_url,'') = '';
  if n > 0 then raise exception 'meals: % merged row(s) lost their photo', n; end if;
end $$;
