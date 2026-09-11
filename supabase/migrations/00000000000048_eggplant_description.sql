-- Oxtail comes out of the eggplant wording and the description is shortened.
--
-- "Smoked turkey" stays. The dish is not vegetarian, and that is the part a
-- customer needs to know before ordering what reads like a vegetable stew.
-- If the recipe still contains oxtail, this hides an ingredient from anyone
-- avoiding beef specifically — worth putting back if so.

update meals set base_description = 'Garden egg stew with smoked turkey.'
where base_slug = 'eggplant';

update meals
set description = replace(description, ' Smoked turkey and oxtail included.', ' Smoked turkey included.')
where base_slug = 'eggplant' and description like '%oxtail%';

do $$
declare n int;
begin
  select count(*) into n from meals where active and base_slug = 'eggplant' and
    (description ilike '%oxtail%' or base_description ilike '%oxtail%');
  if n > 0 then raise exception 'meals: % eggplant row(s) still mention oxtail', n; end if;

  -- The dish contains meat; saying nothing at all would be worse than verbose.
  select count(*) into n from meals where active and base_slug = 'eggplant'
    and base_description not ilike '%turkey%';
  if n > 0 then raise exception 'meals: eggplant no longer discloses that it contains meat'; end if;
end $$;
