-- Five drinks carried a bare filename where every other meal carries a full
-- URL. The customer site papers over it — getImageUrl maps a bare filename to
-- /assets/images/ — but nothing else does, so the admin panel resolved the
-- filename against its own origin and showed a broken image for each.
--
-- The files are now in Storage alongside the other drink photos, so the column
-- means one thing everywhere: the address of the picture. The mobile app and
-- the order emails benefit for the same reason.
update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/bottled-water.png'
  where image_url = 'bottle_water.png';

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/coca-cola.png'
  where image_url = 'coke.png';

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/fanta-orange.png'
  where image_url = 'fanta.png';

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/malta-guinness.png'
  where image_url = 'ghana_malt.png';

update meals set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/sprite.png'
  where image_url = 'sprite.png';

-- Anything else still holding a bare filename is the same bug and would show
-- the same broken image, so say so loudly rather than leaving it to be found
-- in a screenshot months from now.
do $$
declare
  stragglers record;
begin
  for stragglers in
    select name, image_url from meals
    where image_url is not null
      and image_url <> ''
      and image_url not like 'http%'
      and image_url not like '/assets/%'
  loop
    raise notice 'Still a bare filename: % -> %', stragglers.name, stragglers.image_url;
  end loop;
end $$;
