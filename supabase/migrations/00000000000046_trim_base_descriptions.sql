-- Three descriptions were doing too much work.
--
-- Check Check keeps only the part a customer needs: which day it is on. The
-- rest was describing a plate they can see in the photo.

update meals set base_description = 'Rice and beans, cooked together.'
where base_slug = 'waakye';

update meals set base_description = 'Soft pounded fufu, served with soup.'
where base_slug = 'fufu';

update meals set base_description = 'Available Wednesdays only.'
where base_slug = 'check-check';

do $$
declare n int;
begin
  -- The Wednesday note is the whole reason Check Check still has a
  -- description; losing it would be worse than the verbosity.
  select count(*) into n from meals
  where active and base_slug = 'check-check' and base_description not like '%Wednesdays only%';
  if n > 0 then raise exception 'meals: Check Check lost its Wednesday note'; end if;
end $$;
