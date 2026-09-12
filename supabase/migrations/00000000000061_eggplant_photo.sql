-- The eggplant card now uses the boiled yam and eggplant stew photo, on the
-- restaurant's instruction. All four variants share it, as they shared the
-- previous one.
--
-- The source is 2560x1440 — 16:9, far wider than the square menu cards, so it
-- was centre-cropped to square before scaling rather than left for the card to
-- crop. A 16:9 photo dropped into a square frame loses a third of its width,
-- and there is no telling in advance which third.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/eggplant-2.jpg'
where base_slug = 'eggplant';
