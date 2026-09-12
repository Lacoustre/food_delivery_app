-- fufu.jpg was 1200x675, a 16:9 photo in a square card, so roughly 44% of its
-- width was being cropped away by the browser with no say in which 44%.
--
-- Same photograph, centre-cropped to square from the 2560x1440 original before
-- scaling, so the framing is decided once here rather than by whatever the
-- card happens to do. All eight Fufu variants share it.
update meals
set image_url = 'https://peimbksjyjcxmurwwmnn.supabase.co/storage/v1/object/public/meals/fufu-2.jpg'
where base_slug = 'fufu';
