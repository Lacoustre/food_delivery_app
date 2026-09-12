-- Rice & Tomato Stew was a card of its own while every variant of the Rice &
-- Stew card was meat or fish — so a customer opening that card saw no
-- vegetarian option at all, and the veggie version sat elsewhere in the grid
-- under a different name.
--
-- They are the same dish: Rice & Stew's own description is "White rice with
-- tomato and pepper stew". It becomes the Vegetarian variant, which is how
-- Jollof, Fried Rice, Waakye and Check Check already handle theirs.
--
-- The name stays "Rice & Tomato Stew" — the card title comes from base_name,
-- and the row's own name is what appears on receipts and kitchen tickets,
-- where the distinction is worth keeping.
update meals
set base_slug        = 'rice-stew',
    base_name        = 'Rice & Stew',
    base_description = 'White rice with tomato and pepper stew.',
    variant_label    = 'Vegetarian',
    variant_type     = 'protein'
where base_slug = 'rice-tomato-stew-vegetarian-';

-- The card must still offer meat. If this ever ran against a menu where the
-- vegetarian row was the only one left, the card would silently become
-- vegetarian-only.
do $$
declare
  meaty int;
begin
  select count(*) into meaty
  from meals
  where base_slug = 'rice-stew' and is_vegetarian is not true;

  if meaty = 0 then
    raise exception 'Rice & Stew would have no non-vegetarian option left';
  end if;
end $$;
