-- Photos for the last four canned drinks. Uploaded to Storage rather than
-- bundled as assets, matching how the dish photos are stored — the five
-- earlier drinks use bare filenames only because those files already shipped
-- with every client.

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/ginger-ale.jpg' where slug = 'ginger-ale';
update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/pepsi.jpg'      where slug = 'pepsi';
update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/diet-coke.jpg'  where slug = 'diet-coke';
update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/dr-pepper.jpg'  where slug = 'dr-pepper';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and menu_section = 'Drinks' and coalesce(image_url, '') = '';
  if n > 0 then
    raise exception 'meals: % drink(s) still have no photo', n;
  end if;
end $$;
