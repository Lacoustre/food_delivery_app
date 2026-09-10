-- Alvaro (Malt Drink) comes off the menu.
--
-- Deactivated rather than deleted: order_items reference meals by id, so the
-- row has to survive for the history of anyone who already bought one.
-- Malta Guinness, the other $3.99 malt drink, stays.

update meals
set active = false
where name = 'Alvaro (Malt Drink)';

do $$
declare n int;
begin
  select count(*) into n from meals where name = 'Alvaro (Malt Drink)' and active;
  if n > 0 then raise exception 'meals: Alvaro is still active'; end if;
end $$;
