-- Ice Cream Cup, reshot without branding. The first photo supplied was a
-- Baskin-Robbins cup (see migration 38); this one is a plain white cup, so it
-- neither advertises another business nor promises their product.
--
-- Drinks, Side Dishes and Desserts are now fully photographed. Only three
-- main dishes remain without one.

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/ice-cream-cup.jpg'
where slug = 'ice-cream-cup';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and menu_section in ('Drinks', 'Desserts', 'Side Dishes')
    and coalesce(image_url, '') = '';
  if n > 0 then
    raise exception 'meals: % drink/dessert/side still has no photo', n;
  end if;
end $$;
