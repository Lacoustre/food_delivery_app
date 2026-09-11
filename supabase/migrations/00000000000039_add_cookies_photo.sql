-- Chocolate Chip Cookies. Every dessert now has a photo except Ice Cream Cup,
-- whose supplied image was a branded Baskin-Robbins cup (see migration 38).
--
-- Note the photo shows four cookies while the item sells two. Left as supplied
-- — it reads as a serving suggestion rather than a promise at this price — but
-- a tighter crop showing two would match the order exactly.

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/chocolate-chip-cookies.jpg'
where slug = 'chocolate-chip-cookies-2-cookies';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and slug = 'chocolate-chip-cookies-2-cookies'
    and coalesce(image_url, '') = '';
  if n > 0 then
    raise exception 'meals: the cookies did not get a photo';
  end if;
end $$;
