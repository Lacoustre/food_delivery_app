-- Rename the section to "Side Dishes" and put all of Individual Items in it.
--
-- Migration 26 split "Individual Items" by price, keeping the ~$14
-- "(Individual)" rice dishes with the mains. That was our inference, not the
-- kitchen's: Individual Items is a single section on the restaurant's own
-- menu and stays one section here.

update meals
set menu_section = 'Side Dishes'
where menu_section = 'Sides'
   or category = 'Individual Items';

do $$
declare n int;
begin
  select count(*) into n from meals where menu_section is null or menu_section = 'Sides';
  if n > 0 then
    raise exception 'meals: % row(s) left unsectioned or still on the old label', n;
  end if;
end $$;
