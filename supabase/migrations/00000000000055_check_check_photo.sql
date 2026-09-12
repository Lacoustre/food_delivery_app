-- The restaurant supplied a new Check Check photo. Both variants shared the
-- old one and both move together.
--
-- A new filename rather than overwriting check-check.jpg: the old URL is
-- already cached by browsers and by the CDN, and overwriting in place means
-- some customers keep seeing yesterday's picture with no way to tell.
--
-- Converted from a 2.6 MB PNG to a 1200px JPEG (487 KB) to match every other
-- photo on the menu. A menu card is browsed on a phone, often on mobile data.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/check-check-2.jpg'
where base_name = 'Check Check';
