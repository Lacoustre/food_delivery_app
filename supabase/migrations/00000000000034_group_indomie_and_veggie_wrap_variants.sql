-- Indomie and Jollof Veggie Wrap each existed as two separate rows with the
-- same name and price, so each rendered as two identical-looking cards and a
-- customer had no way to tell them apart.
--
-- They are not duplicates: one of each pair is vegetarian and one is not.
-- Group them the way red-red and check-check already are — one card, a
-- picker underneath, is_vegetarian carrying the dietary fact and "Vegetarian"
-- staying out of the dish name (the convention migration 25 established).

-- The vegetarian rows join their non-vegetarian sibling's group.
update meals
set base_slug     = 'indomie',
    base_name     = 'Indomie',
    variant_label = 'Vegetarian',
    variant_type  = 'protein',
    is_vegetarian = true
where slug = 'indomie-vegetarian';

update meals
set base_slug     = 'jollof-veggie-wrap',
    base_name     = 'Jollof Veggie Wrap',
    variant_label = 'Vegetarian',
    variant_type  = 'protein',
    is_vegetarian = true
where slug = 'jollof-veggie-wrap-vegetarian';

-- The non-vegetarian rows become the other variant.
update meals
set base_name     = 'Indomie',
    variant_label = 'Regular',
    variant_type  = 'protein',
    is_vegetarian = false
where slug = 'indomie';

-- This one also said "vegetarian" in its description while being flagged
-- non-vegetarian. A customer avoiding meat would have read that and ordered
-- the wrong dish, so the word comes out.
update meals
set description   = 'Jollof rice wrap.',
    base_name     = 'Jollof Veggie Wrap',
    variant_label = 'Regular',
    variant_type  = 'protein',
    is_vegetarian = false
where slug = 'jollof-veggie-wrap';

do $$
declare n int;
begin
  select count(*) into n from meals where base_slug = 'indomie' and active;
  if n <> 2 then
    raise exception 'meals: expected 2 active indomie variants, found %', n;
  end if;

  select count(*) into n from meals where base_slug = 'jollof-veggie-wrap' and active;
  if n <> 2 then
    raise exception 'meals: expected 2 active veggie wrap variants, found %', n;
  end if;

  select count(*) into n from meals
  where active and not is_vegetarian and description ilike '%vegetarian%';
  if n > 0 then
    raise exception 'meals: % non-vegetarian dish(es) still describe themselves as vegetarian', n;
  end if;
end $$;
