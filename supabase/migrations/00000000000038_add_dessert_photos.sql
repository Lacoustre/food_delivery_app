-- Real photographs of the beef patty and the Ghana sponge cake, unlike the
-- generated product shots used for the canned drinks.
--
-- Ice Cream Cup is deliberately still without one. The photo supplied for it
-- was a Baskin-Robbins cup: their logo across the front, their branded spoon,
-- taken inside one of their stores. Putting that on the menu advertises
-- another business, uses their trademark to sell ours, and promises three
-- scoops in a branded cup for $2.99.

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/beef-patty.jpg'
where slug = 'beef-patty';

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/ghana-sponge-cake.jpg'
where slug = 'ghana-sponge-cake-slice';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and slug in ('beef-patty','ghana-sponge-cake-slice')
    and coalesce(image_url, '') = '';
  if n > 0 then
    raise exception 'meals: % dessert(s) did not get a photo', n;
  end if;
end $$;
