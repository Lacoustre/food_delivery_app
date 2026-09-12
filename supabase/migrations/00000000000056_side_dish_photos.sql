-- Fufu Ball and Rice Ball had photos from 10 September; the restaurant put
-- replacements in the shared Drive folder on the 12th. Same reasoning as the
-- Check Check swap: new filenames rather than overwriting, because the old
-- URLs are cached by browsers and the CDN, and both converted to 1200px JPEG
-- from multi-megabyte PNGs.
--
-- Note these two are 4:3 rather than square, and the menu cards are square, so
-- they are cropped at the sides. Left as supplied — a crop the restaurant can
-- see and object to is better than a guess at recomposing their photo.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/fufu-ball-2.jpg'
where name = 'Fufu Ball' and menu_section = 'Side Dishes';

update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/rice-ball-side-2.jpg'
where name = 'Rice Ball' and menu_section = 'Side Dishes';
