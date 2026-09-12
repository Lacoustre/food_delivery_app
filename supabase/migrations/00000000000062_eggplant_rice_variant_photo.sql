-- Eggplant with White Rice gets its own photo, the rice-and-eggplant-stew one,
-- rather than the boiled yam picture the rest of the card uses. Each variant
-- carries its own image, so a variant that genuinely looks different on the
-- plate can show that — the same reasoning as the vegetarian Rice & Stew.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/eggplant-rice.jpg'
where base_slug = 'eggplant' and variant_label = 'White Rice';
