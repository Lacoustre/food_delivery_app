-- Photo for the Gravy card, plus the one row migration 33 left without the
-- group's picture.
--
-- Every row in a variant group carries the same image_url (see jollof, 8/8),
-- so the card renders a photo whichever protein the customer has selected.

update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/gravy.jpg'
where base_slug = 'gravy' and active;

-- Peanut & Spinach with Boiled Yam joined the group in migration 33 with an
-- empty image_url, leaving the group at 2 of 3.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/peanut-soup.jpg'
where base_slug = 'peanut-soup' and active and coalesce(image_url, '') = '';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and base_slug in ('gravy','peanut-soup') and coalesce(image_url,'') = '';
  if n > 0 then
    raise exception 'meals: % row(s) in these groups still have no photo', n;
  end if;
end $$;
