-- New Bean Stew photo from the shared Drive folder. All four variants share
-- one card and one picture, so they move together.
--
-- New filename rather than overwriting bean-stew.jpg, for the same reason as
-- the others: the old URL is cached by browsers and the CDN.
--
-- This one is portrait, 1050x1400, where the menu cards are square — so it is
-- cropped top and bottom rather than at the sides. Left as supplied, but it is
-- the shape most likely to lose part of the dish.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/bean-stew-2.jpg'
where base_name = 'Bean Stew';
