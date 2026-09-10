-- Five drinks were falling back to the logo while a correct product shot was
-- already sitting in assets/images/, bundled with the app and unused.
--
-- These are set to a bare filename rather than a Storage URL on purpose: both
-- clients resolve a bare name against their local assets folder (webapp
-- getImageUrl, mobile MealImage), so one value works in the webapp, the mobile
-- app and the admin panel, costs no bandwidth, and still renders offline.

update meals set image_url = 'coke.png'         where slug = 'coca-cola';
update meals set image_url = 'sprite.png'       where slug = 'sprite';
update meals set image_url = 'fanta.png'        where slug = 'fanta-orange';
update meals set image_url = 'ghana_malt.png'   where slug = 'malta-guinness';
update meals set image_url = 'bottle_water.png' where slug = 'bottled-water';

do $$
declare n int;
begin
  select count(*) into n from meals
  where active and image_url in
    ('coke.png','sprite.png','fanta.png','ghana_malt.png','bottle_water.png');
  if n <> 5 then
    raise exception 'meals: expected 5 drinks on bundled photos, found %', n;
  end if;
end $$;
