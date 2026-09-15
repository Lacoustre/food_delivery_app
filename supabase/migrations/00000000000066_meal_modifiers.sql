-- Add-ons and requests per dish, as the restaurant listed them on 2026-09-14:
-- "Extra Shito +$1.99", "No Coleslaw", "Stew on the Side".
--
-- One list per dish (base_slug), shared by every protein or soup option of
-- that dish. The server prices orders from this table; checkout never sends a
-- price. The website's earlier extras (src/lib/mealExtras.ts) were a
-- hard-coded list keyed by dish names from an older menu. They matched almost
-- nothing, and were never charged or sent to the kitchen.

create table if not exists meal_modifiers (
  id                   uuid primary key default gen_random_uuid(),
  base_slug            text not null,
  name                 text not null,
  price                numeric(10,2) not null default 0 check (price >= 0),
  -- extra: something added, usually paid ("Extra Fish").
  -- request: a free change ("No Shito", "Stew on the Side").
  kind                 text not null check (kind in ('extra', 'request')),
  -- "No Protein" on vegetarian jollof means nothing, so it isn't offered there.
  hide_when_vegetarian boolean not null default false,
  position             int not null default 0,
  active               boolean not null default true,
  created_at           timestamptz not null default now(),
  unique (base_slug, name)
);

create index if not exists meal_modifiers_base_slug_idx on meal_modifiers(base_slug);

alter table meal_modifiers enable row level security;
create policy "meal_modifiers_public_read" on meal_modifiers for select using (true);
create policy "meal_modifiers_admin_insert" on meal_modifiers for insert with check (is_admin());
create policy "meal_modifiers_admin_update" on meal_modifiers for update using (is_admin());
create policy "meal_modifiers_admin_delete" on meal_modifiers for delete using (is_admin());

-- What was chosen, as it was priced at the time: [{id, name, price}].
-- unit_price already includes these, so every existing total and revenue
-- figure stays correct without knowing about them.
alter table order_items add column if not exists modifiers jsonb;

with lists(list, pos, name, price) as (values
  ('jollof', 1, 'Extra Fried Chicken', 2.99),
  ('jollof', 2, 'Extra Grilled Chicken', 2.99),
  ('jollof', 3, 'Extra Jerk Chicken', 2.99),
  ('jollof', 4, 'Extra Goat Meat', 3.99),
  ('jollof', 5, 'Extra Fish', 3.50),
  ('jollof', 6, 'Extra Turkey', 3.50),
  ('jollof', 7, 'Extra Egg', 0.99),
  ('jollof', 8, 'Extra Fried Plantain', 2.99),
  ('jollof', 9, 'Extra Shito', 1.99),
  ('jollof', 10, 'No Protein', 0),
  ('jollof', 11, 'No Shito', 0),
  ('jollof', 12, 'No Coleslaw', 0),

  ('fried-rice', 1, 'Extra Fried Chicken', 2.99),
  ('fried-rice', 2, 'Extra Grilled Chicken', 2.99),
  ('fried-rice', 3, 'Extra Jerk Chicken', 2.99),
  ('fried-rice', 4, 'Extra Goat Meat', 3.99),
  ('fried-rice', 5, 'Extra Fish', 3.50),
  ('fried-rice', 6, 'Extra Turkey', 3.50),
  ('fried-rice', 7, 'Extra Egg', 0.99),
  ('fried-rice', 8, 'Extra Fried Plantain', 2.99),
  ('fried-rice', 9, 'No Protein', 0),
  ('fried-rice', 10, 'No Veggies', 0),
  ('fried-rice', 11, 'No Egg', 0),

  ('waakye', 1, 'Extra Fried Chicken', 2.99),
  ('waakye', 2, 'Extra Grilled Chicken', 2.99),
  ('waakye', 3, 'Extra Jerk Chicken', 2.99),
  ('waakye', 4, 'Extra Goat Meat', 3.99),
  ('waakye', 5, 'Extra Fish', 3.50),
  ('waakye', 6, 'Extra Turkey', 3.50),
  ('waakye', 7, 'Extra Egg', 0.99),
  ('waakye', 8, 'Extra Stew', 1.99),
  ('waakye', 9, 'Extra Shito', 1.99),
  ('waakye', 10, 'Extra Fried Plantain', 2.99),
  ('waakye', 11, 'No Protein', 0),
  ('waakye', 12, 'No Stew', 0),
  ('waakye', 13, 'No Shito', 0),
  ('waakye', 14, 'No Gari', 0),
  ('waakye', 15, 'No Spaghetti', 0),
  ('waakye', 16, 'No Egg', 0),
  ('waakye', 17, 'Gari on the Side', 0),
  ('waakye', 18, 'Shito on the Side', 0),
  ('waakye', 19, 'Stew on the Side', 0),

  ('banku', 1, 'Extra Tilapia', 21.99),
  ('banku', 2, 'Extra Red Snapper', 22.99),
  ('banku', 3, 'Extra Fish', 3.50),
  ('banku', 4, 'Extra Shito', 1.99),
  ('banku', 5, 'Extra Green Pepper', 1.99),
  ('banku', 6, 'Extra Red Pepper', 1.99),
  ('banku', 7, 'No Protein', 0),
  ('banku', 8, 'No Green Sauce', 0),
  ('banku', 9, 'No Red Sauce', 0),

  ('fufu', 1, 'Extra Goat Meat', 3.99),
  ('fufu', 2, 'Extra Chicken', 2.99),
  ('fufu', 3, 'No Protein', 0),

  ('tuo-zaafi', 1, 'Extra Goat Meat', 3.99),
  ('tuo-zaafi', 2, 'Extra Egg', 0.99),
  ('tuo-zaafi', 3, 'Extra Stew', 1.99),

  ('eggplant', 1, 'Extra Oxtail', 3.99),
  ('eggplant', 2, 'Extra Turkey', 3.50),
  ('eggplant', 3, 'Extra Egg', 0.99),
  ('eggplant', 4, 'Extra Stew', 1.99),
  ('eggplant', 5, 'No Oxtail', 0),
  ('eggplant', 6, 'No Smoked Turkey', 0),
  ('eggplant', 7, 'No Egg', 0),
  ('eggplant', 8, 'Stew on the Side', 0),

  ('spinach', 1, 'Extra Turkey', 3.50),
  ('spinach', 2, 'Extra Egg', 0.99),
  ('spinach', 3, 'Extra Stew', 1.99),
  ('spinach', 4, 'No Smoked Turkey', 0),
  ('spinach', 5, 'No Egg', 0),
  ('spinach', 6, 'Stew on the Side', 0),

  ('fried-yam', 1, 'Extra Fried Chicken', 2.99),
  ('fried-yam', 2, 'Extra Grilled Chicken', 2.99),
  ('fried-yam', 3, 'Extra Jerk Chicken', 2.99),
  ('fried-yam', 4, 'Extra Goat Meat', 3.99),
  ('fried-yam', 5, 'Extra Fish', 3.50),
  ('fried-yam', 6, 'Extra Turkey', 3.50),
  ('fried-yam', 7, 'Extra Shito', 1.99),
  ('fried-yam', 8, 'No Protein', 0),

  ('check-check', 1, 'Extra Chicken', 2.99),
  ('check-check', 2, 'Extra Goat Meat', 3.99),
  ('check-check', 3, 'Extra Fish', 3.50),
  ('check-check', 4, 'Extra Turkey', 3.50),
  ('check-check', 5, 'Extra Egg', 0.99),
  ('check-check', 6, 'Extra Fried Plantain', 2.99),
  ('check-check', 7, 'No Protein', 0),
  ('check-check', 8, 'No Veggies', 0),
  ('check-check', 9, 'No Egg', 0),

  ('jollof-wrap', 1, 'Extra Steak', 2.99),
  ('jollof-wrap', 2, 'Extra Chicken', 2.50),

  ('red-red', 1, 'Extra Fried Plantain', 2.99),
  ('red-red', 2, 'Extra Egg', 0.99),
  ('red-red', 3, 'No Egg', 0),

  ('kenkey', 1, 'Extra Fish', 3.50),
  ('kenkey', 2, 'Extra Tilapia', 21.99),
  ('kenkey', 3, 'Extra Red Snapper', 22.99),
  ('kenkey', 4, 'Extra Shito', 1.99),
  ('kenkey', 5, 'Extra Green Pepper', 1.99),
  ('kenkey', 6, 'Extra Red Pepper', 1.99),
  ('kenkey', 7, 'No Shito', 0),
  ('kenkey', 8, 'No Green Sauce', 0),
  ('kenkey', 9, 'No Red Sauce', 0)
),
-- The restaurant's "Spinach Stew" list applies to all three spinach stew
-- dishes on the site. Indomie has no modifiers.
dishes(slug, list) as (values
  ('jollof', 'jollof'),
  ('fried-rice', 'fried-rice'),
  ('waakye', 'waakye'),
  ('banku', 'banku'),
  ('fufu', 'fufu'),
  ('tuo-zaafi', 'tuo-zaafi'),
  ('eggplant', 'eggplant'),
  ('rice-spinach-stew', 'spinach'),
  ('boiled-yam-spinach-stew', 'spinach'),
  ('boiled-plantain-spinach-stew', 'spinach'),
  ('fried-yam', 'fried-yam'),
  ('check-check', 'check-check'),
  ('jollof-wrap', 'jollof-wrap'),
  ('red-red', 'red-red'),
  ('kenkey', 'kenkey')
)
insert into meal_modifiers (base_slug, name, price, kind, hide_when_vegetarian, position)
select
  d.slug,
  l.name,
  l.price,
  case when l.name like 'Extra %' then 'extra' else 'request' end,
  l.name in ('No Protein', 'No Oxtail', 'No Smoked Turkey'),
  l.pos
from dishes d
join lists l on l.list = d.list
on conflict (base_slug, name) do nothing;
