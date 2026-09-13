-- The dish is khebab. Suya is the spice blend dusted over it, not the name of
-- the food — the menu had the topping standing in for the dish.
--
-- Description names the meats, since that is what a customer is choosing
-- between, and mentions the suya as what it is: the seasoning.
update meals
set name        = 'Khebab',
    base_name   = 'Khebab',
    base_slug   = 'khebab',
    description = 'Goat meat and beef, dusted with suya spice.'
where base_slug = 'suya';

-- The old name must not survive anywhere, or the menu will show both.
do $$
declare
  leftovers int;
begin
  select count(*) into leftovers
  from meals
  where base_slug = 'suya' or name = 'Suya' or base_name = 'Suya';

  if leftovers > 0 then
    raise exception '% row(s) still carry the old Suya name', leftovers;
  end if;
end $$;
