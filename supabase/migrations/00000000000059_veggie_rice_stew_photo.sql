-- "rice and stew veggie" from the shared Drive folder.
--
-- The vegetarian rice and stew is its own card, Rice & Tomato Stew, rather
-- than a variant of Rice & Stew — which has six variants and every one of them
-- is meat or fish. So this photo goes on that card alone and the meat variants
-- keep theirs.
--
-- Landscape, 1400x1050, against square cards: cropped at the sides.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/rice-tomato-stew-2.jpg'
where base_slug = 'rice-tomato-stew-vegetarian-';
