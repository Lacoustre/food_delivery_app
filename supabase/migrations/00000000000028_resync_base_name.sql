-- Re-derive base_name from the cleaned dish names.
--
-- Migration 23 populated base_name, then 25 stripped "(Vegetarian)" from name
-- without touching the copy already sitting in base_name. Menu cards render
-- base_name, so they still read "Indomie (Vegetarian)" beside a Vegetarian
-- badge — the suffix the flag was meant to replace, shown twice.

update meals
set base_name = case
      when position(' with ' in name) > 0
        then btrim(split_part(name, ' with ', 1))
      else name
    end
where base_name is distinct from (
      case
        when position(' with ' in name) > 0
          then btrim(split_part(name, ' with ', 1))
        else name
      end);

-- Rows folded into another group in migration 25 keep that group's display
-- name rather than their own — "Jollof Rice" became a Vegetarian option on the
-- Jollof card, so the card is titled Jollof.
update meals set base_name = 'Jollof'     where base_slug = 'jollof';
update meals set base_name = 'Fried Rice' where base_slug = 'fried-rice';
update meals set base_name = 'Waakye'     where base_slug = 'waakye';

do $$
declare n int;
begin
  select count(*) into n from meals where base_name ilike '%(vegetarian%';
  if n > 0 then
    raise exception 'meals: % base_name(s) still carry the vegetarian suffix', n;
  end if;

  -- Every row in a group must agree on the card title.
  select count(*) into n from (
    select base_slug from meals group by base_slug having count(distinct base_name) > 1
  ) d;
  if n > 0 then
    raise exception 'meals: % group(s) disagree on base_name', n;
  end if;
end $$;
