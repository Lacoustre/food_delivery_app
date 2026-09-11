-- Pounded Yam with Egusi and Check Check, the last two cards without a photo.
-- Every card on the menu now has one.
--
-- Both photos show the meat version, and both groups contain a vegetarian
-- variant that will therefore display meat. That is the opposite of the choice
-- made in migration 41, and deliberately so: there the vegetarian photo
-- existed and was the safer of two options, here it does not exist at all. A
-- labelled vegetarian variant showing the meat version of the same dish beats
-- no photograph. Replace if a vegetarian shot is ever taken.

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/pounded-yam.jpg'
where base_slug = 'pounded-yam' and active;

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/check-check.jpg'
where base_slug = 'check-check' and active;

do $$
declare n int;
begin
  select count(*) into n from meals where active and coalesce(image_url, '') = '';
  if n > 0 then
    raise exception 'meals: % dish(es) still have no photo', n;
  end if;
end $$;
