// Seeds the `meals` table in Supabase from the restaurant's full menu.
// Same menu data as migrate_meals.js (which seeds Firestore) — this is the
// Supabase-side counterpart needed now that admin-panel's Meals.tsx reads
// from Supabase instead.
//
// SETUP:
// 1. Supabase dashboard -> Project Settings -> API -> service_role key.
//    This bypasses RLS (needed since this script has no admin session) —
//    never commit it, never put it in .env.local, only pass it inline:
//      SUPABASE_SERVICE_ROLE_KEY=... node migrate_meals_to_supabase.js
// 2. Images: every item below has image_url: '' since photos aren't ready
//    yet. Re-run with images filled in later, or update via the admin
//    panel — this script uses each item's slugified name as a stable key,
//    so re-running is idempotent (upserts rather than duplicating).

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://peimbksjyjcxmurwwmnn.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_SERVICE_ROLE_KEY env var.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const meals = [
  // ── Jollof Rice ──────────────────────────────────────────────────────
  { name: 'Jollof with Fried Chicken', price: 22.99, category: 'Jollof Rice', description: 'Jollof rice served with fried chicken.' },
  { name: 'Jollof with Grilled Chicken', price: 22.99, category: 'Jollof Rice', description: 'Jollof rice served with grilled chicken.' },
  { name: 'Jollof with Jerk Chicken', price: 23.99, category: 'Jollof Rice', description: 'Jollof rice served with jerk chicken.' },
  { name: 'Jollof with Fish', price: 24.99, category: 'Jollof Rice', description: 'Jollof rice served with fish.' },
  { name: 'Jollof with Goat Meat', price: 26.99, category: 'Jollof Rice', description: 'Jollof rice served with goat meat.' },
  { name: 'Jollof with Turkey', price: 24.99, category: 'Jollof Rice', description: 'Jollof rice served with turkey.' },
  { name: 'Jollof with Tilapia', price: 28.99, category: 'Jollof Rice', description: 'Jollof rice served with tilapia.' },

  // ── Fried Rice ───────────────────────────────────────────────────────
  { name: 'Fried Rice with Fried Chicken', price: 23.99, category: 'Fried Rice', description: 'Fried rice served with fried chicken.' },
  { name: 'Fried Rice with Grilled Chicken', price: 23.99, category: 'Fried Rice', description: 'Fried rice served with grilled chicken.' },
  { name: 'Fried Rice with Jerk Chicken', price: 24.99, category: 'Fried Rice', description: 'Fried rice served with jerk chicken.' },
  { name: 'Fried Rice with Fish', price: 25.99, category: 'Fried Rice', description: 'Fried rice served with fish.' },
  { name: 'Fried Rice with Goat Meat', price: 27.99, category: 'Fried Rice', description: 'Fried rice served with goat meat.' },
  { name: 'Fried Rice with Turkey', price: 25.99, category: 'Fried Rice', description: 'Fried rice served with turkey.' },
  { name: 'Fried Rice with Tilapia', price: 29.99, category: 'Fried Rice', description: 'Fried rice served with tilapia.' },

  // ── Waakye ───────────────────────────────────────────────────────────
  { name: 'Waakye with Fried Chicken', price: 23.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with fried chicken.' },
  { name: 'Waakye with Grilled Chicken', price: 23.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with grilled chicken.' },
  { name: 'Waakye with Jerk Chicken', price: 24.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with jerk chicken.' },
  { name: 'Waakye with Fish', price: 25.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with fish.' },
  { name: 'Waakye with Goat Meat', price: 27.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with goat meat.' },
  { name: 'Waakye with Turkey', price: 25.99, category: 'Waakye', description: 'Traditional Ghanaian rice and beans with turkey.' },

  // ── Fufu Dishes ──────────────────────────────────────────────────────
  { name: 'Fufu with Chicken Light Soup', price: 24.99, category: 'Fufu Dishes', description: 'Fufu served with chicken light soup.' },
  { name: 'Fufu with Goat Light Soup', price: 26.99, category: 'Fufu Dishes', description: 'Fufu served with goat light soup.' },
  { name: 'Fufu with Chicken Peanut Soup', price: 24.99, category: 'Fufu Dishes', description: 'Fufu served with chicken peanut soup.' },
  { name: 'Fufu with Goat Peanut Soup', price: 26.99, category: 'Fufu Dishes', description: 'Fufu served with goat peanut soup.' },
  { name: 'Fufu with Goat Palm Nut Soup', price: 27.99, category: 'Fufu Dishes', description: 'Fufu served with goat palm nut soup.' },
  { name: 'Fufu with Okra Soup', price: 26.99, category: 'Fufu Dishes', description: 'Fufu served with okra soup.' },

  // ── Banku Dishes ─────────────────────────────────────────────────────
  { name: 'Banku with Okra Soup', price: 24.99, category: 'Banku Dishes', description: 'Banku served with okra soup.' },
  { name: 'Banku with Grilled Tilapia', price: 26.99, category: 'Banku Dishes', description: 'Banku served with grilled tilapia.' },
  { name: 'Banku with Steamed Tilapia', price: 26.99, category: 'Banku Dishes', description: 'Banku served with steamed tilapia.' },
  { name: 'Banku with Fried Tilapia', price: 26.99, category: 'Banku Dishes', description: 'Banku served with fried tilapia.' },
  { name: 'Banku with Small Red Snapper', price: 27.99, category: 'Banku Dishes', description: 'Banku served with small red snapper.' },
  { name: 'Banku with Crocker Fish', price: 23.99, category: 'Banku Dishes', description: 'Banku served with crocker fish.' },

  // ── Kenkey Dishes ────────────────────────────────────────────────────
  { name: 'Kenkey with Grilled Tilapia', price: 26.99, category: 'Kenkey Dishes', description: 'Kenkey served with grilled tilapia.' },
  { name: 'Kenkey with Fried Tilapia', price: 26.99, category: 'Kenkey Dishes', description: 'Kenkey served with fried tilapia.' },

  // ── Fried Yam Dishes ─────────────────────────────────────────────────
  { name: 'Fried Yam with Fried Chicken', price: 23.99, category: 'Fried Yam Dishes', description: 'Fried yam served with fried chicken.' },
  { name: 'Fried Yam with Grilled Chicken', price: 23.99, category: 'Fried Yam Dishes', description: 'Fried yam served with grilled chicken.' },
  { name: 'Fried Yam with Fish', price: 24.99, category: 'Fried Yam Dishes', description: 'Fried yam served with fish.' },
  { name: 'Fried Yam with Goat Meat', price: 28.99, category: 'Fried Yam Dishes', description: 'Fried yam served with goat meat.' },
  { name: 'Fried Yam with Tilapia', price: 28.99, category: 'Fried Yam Dishes', description: 'Fried yam served with tilapia.' },
  { name: 'Fried Yam with Turkey Tail', price: 23.99, category: 'Fried Yam Dishes', description: 'Fried yam served with turkey tail.' },
  { name: 'Fried Yam with Turkey Wings', price: 24.99, category: 'Fried Yam Dishes', description: 'Fried yam served with turkey wings.' },
  { name: 'Fried Yam with Red Snapper', price: 34.99, category: 'Fried Yam Dishes', description: 'Fried yam served with red snapper.' },
  { name: 'Fried Yam with Chicken Wings', price: 26.99, category: 'Fried Yam Dishes', description: 'Fried yam served with chicken wings.' },

  // ── Spinach Stew Dishes (Smoked Turkey & Beef Included) ─────────────
  { name: 'Boiled Yam with Spinach Stew', price: 26.99, category: 'Spinach Stew Dishes', description: 'Boiled yam with spinach stew. Smoked turkey and beef included.' },
  { name: 'White Rice with Spinach Stew', price: 25.99, category: 'Spinach Stew Dishes', description: 'White rice with spinach stew. Smoked turkey and beef included.' },
  { name: 'Fried Plantain with Spinach Stew', price: 24.99, category: 'Spinach Stew Dishes', description: 'Fried plantain with spinach stew. Smoked turkey and beef included.' },

  // ── Eggplant Stew Dishes (Smoked Turkey & Oxtail Included) ───────────
  { name: 'Eggplant with Boiled Yam', price: 27.99, category: 'Eggplant Stew Dishes', description: 'Eggplant stew with boiled yam. Smoked turkey and oxtail included.' },
  { name: 'Eggplant with White Rice', price: 26.99, category: 'Eggplant Stew Dishes', description: 'Eggplant stew with white rice. Smoked turkey and oxtail included.' },
  { name: 'Eggplant with Green Plantain', price: 25.99, category: 'Eggplant Stew Dishes', description: 'Eggplant stew with green plantain. Smoked turkey and oxtail included.' },
  { name: 'Eggplant with Fried Plantain', price: 25.99, category: 'Eggplant Stew Dishes', description: 'Eggplant stew with fried plantain. Smoked turkey and oxtail included.' },

  // ── Bean Stew Dishes ─────────────────────────────────────────────────
  { name: 'Bean Stew with White Rice', price: 24.99, category: 'Bean Stew Dishes', description: 'Bean stew served with white rice.' },
  { name: 'Bean Stew with Boiled Yam', price: 26.99, category: 'Bean Stew Dishes', description: 'Bean stew served with boiled yam.' },
  { name: 'Red Red', price: 23.99, category: 'Bean Stew Dishes', description: 'Bean stew in palm oil, chicken included.' },

  // ── Indomie Dishes ───────────────────────────────────────────────────
  { name: 'Indomie', price: 19.99, category: 'Indomie Dishes', description: 'Seasoned Indomie noodles.' },

  // ── Rice Ball Dishes ─────────────────────────────────────────────────
  { name: 'Rice Ball with Chicken Peanut Soup', price: 24.99, category: 'Rice Ball Dishes', description: 'Rice ball served with chicken peanut soup.' },
  { name: 'Rice Ball with Goat Peanut Soup', price: 26.99, category: 'Rice Ball Dishes', description: 'Rice ball served with goat peanut soup.' },
  { name: 'Rice Ball with Palm Nut Soup', price: 26.99, category: 'Rice Ball Dishes', description: 'Rice ball served with palm nut soup.' },

  // ── Egusi Dishes ─────────────────────────────────────────────────────
  { name: 'Pounded Yam with Egusi', price: 26.99, category: 'Egusi Dishes', description: 'Pounded yam served with egusi soup.' },
  { name: 'Fufu with Egusi', price: 26.99, category: 'Egusi Dishes', description: 'Fufu served with egusi soup.' },

  // ── Acheke ───────────────────────────────────────────────────────────
  { name: 'Acheke', price: 27.99, category: 'Acheke', description: 'Ivorian-style grated cassava dish.' },

  // ── Rice & Stew Dishes ───────────────────────────────────────────────
  { name: 'Rice & Stew with Grilled Chicken', price: 22.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with grilled chicken.' },
  { name: 'Rice & Stew with Fried Chicken', price: 22.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with fried chicken.' },
  { name: 'Rice & Stew with Goat Meat', price: 26.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with goat meat.' },
  { name: 'Rice & Stew with Fish', price: 24.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with fish.' },
  { name: 'Rice & Stew with Tilapia', price: 28.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with tilapia.' },
  { name: 'Rice & Stew with Jerk Chicken', price: 23.99, category: 'Rice & Stew Dishes', description: 'Rice and stew served with jerk chicken.' },

  // ── Special Day Dishes ───────────────────────────────────────────────
  { name: 'Check Check', price: 23.99, category: 'Special Day Dishes', description: 'Available Wednesdays only.' },
  { name: 'Tuo Zaafi', price: 28.99, category: 'Special Day Dishes', description: 'Available Saturdays only.' },

  // ── Suya ─────────────────────────────────────────────────────────────
  { name: 'Suya', price: 20.99, category: 'Suya', description: 'Spiced, skewered grilled meat.' },

  // ── Jollof Wraps ─────────────────────────────────────────────────────
  { name: 'Jollof Wrap with Chicken', price: 14.99, category: 'Jollof Wraps', description: 'Jollof rice wrap with chicken.' },
  { name: 'Jollof Wrap with Steak', price: 17.99, category: 'Jollof Wraps', description: 'Jollof rice wrap with steak.' },
  { name: 'Jollof Veggie Wrap', price: 13.99, category: 'Jollof Wraps', description: 'Jollof rice wrap, vegetarian.' },

  // ── African Style Chicken Wings ──────────────────────────────────────
  { name: 'African Style Chicken Wings (5 Pieces)', price: 11.99, category: 'African Style Chicken Wings', description: '5 pieces of African-style chicken wings.' },
  { name: 'African Style Chicken Wings (10 Pieces)', price: 20.99, category: 'African Style Chicken Wings', description: '10 pieces of African-style chicken wings.' },
  { name: 'African Style Chicken Wings (15 Pieces)', price: 23.99, category: 'African Style Chicken Wings', description: '15 pieces of African-style chicken wings.' },
  { name: 'African Style Chicken Wings (20 Pieces)', price: 27.99, category: 'African Style Chicken Wings', description: '20 pieces of African-style chicken wings.' },

  // ── Local Grinder Dishes ─────────────────────────────────────────────
  { name: 'Spinach with Boiled Yam (Grinder)', price: 26.99, category: 'Local Grinder Dishes', description: 'Spinach stew with boiled yam.' },
  { name: 'Spinach with Fried Plantain (Grinder)', price: 24.99, category: 'Local Grinder Dishes', description: 'Spinach stew with fried plantain.' },
  { name: 'Peanut Soup with Boiled Yam (Grinder)', price: 26.99, category: 'Local Grinder Dishes', description: 'Peanut soup with boiled yam.' },
  { name: 'Peanut Soup with Fried Plantain (Grinder)', price: 24.99, category: 'Local Grinder Dishes', description: 'Peanut soup with fried plantain.' },

  // ── Vegetarian Menu ───────────────────────────────────────────────────
  { name: 'Jollof Rice (Vegetarian)', price: 13.99, category: 'Vegetarian', description: 'Vegetarian jollof rice.' },
  { name: 'Fried Rice (Vegetarian)', price: 14.99, category: 'Vegetarian', description: 'Vegetarian fried rice.' },
  { name: 'Waakye (Vegetarian, with Tomato Stew)', price: 14.99, category: 'Vegetarian', description: 'Vegetarian waakye with tomato stew.' },
  { name: 'Indomie (Vegetarian)', price: 19.99, category: 'Vegetarian', description: 'Vegetarian Indomie noodles.' },
  { name: 'Red Red (Vegetarian)', price: 23.99, category: 'Vegetarian', description: 'Vegetarian bean stew in palm oil.' },
  { name: 'Rice & Spinach Stew (Vegetarian)', price: 23.99, category: 'Vegetarian', description: 'Rice with vegetarian spinach stew.' },
  { name: 'Rice & Tomato Stew (Vegetarian)', price: 23.99, category: 'Vegetarian', description: 'Rice with vegetarian tomato stew.' },
  { name: 'Bean Stew with White Rice (Vegetarian)', price: 24.99, category: 'Vegetarian', description: 'Vegetarian bean stew with white rice.' },
  { name: 'Boiled Yam & Spinach Stew (Vegetarian)', price: 25.99, category: 'Vegetarian', description: 'Boiled yam with vegetarian spinach stew.' },
  { name: 'Boiled Yam & Tomato Stew (Vegetarian)', price: 25.99, category: 'Vegetarian', description: 'Boiled yam with vegetarian tomato stew.' },
  { name: 'Bean Stew with Boiled Yam (Vegetarian)', price: 26.99, category: 'Vegetarian', description: 'Vegetarian bean stew with boiled yam.' },
  { name: 'Fried Plantain & Spinach Stew (Vegetarian)', price: 24.99, category: 'Vegetarian', description: 'Fried plantain with vegetarian spinach stew.' },
  { name: 'Fried Plantain & Tomato Stew (Vegetarian)', price: 24.99, category: 'Vegetarian', description: 'Fried plantain with vegetarian tomato stew.' },
  { name: 'Pounded Yam with Egusi (Vegetarian)', price: 26.99, category: 'Vegetarian', description: 'Vegetarian pounded yam with egusi soup.' },
  { name: 'Fufu with Egusi (Vegetarian)', price: 26.99, category: 'Vegetarian', description: 'Vegetarian fufu with egusi soup.' },
  { name: 'Jollof Veggie Wrap (Vegetarian)', price: 13.99, category: 'Vegetarian', description: 'Vegetarian jollof rice wrap.' },
  { name: 'Check Check (Vegetarian)', price: 23.99, category: 'Vegetarian', description: 'Vegetarian check check. Available Wednesdays only.' },

  // ── Individual Items ─────────────────────────────────────────────────
  { name: 'Jollof Rice (Individual)', price: 13.99, category: 'Individual Items', description: 'Jollof rice on its own.' },
  { name: 'Fried Rice (Individual)', price: 14.99, category: 'Individual Items', description: 'Fried rice on its own.' },
  { name: 'Waakye (Individual)', price: 14.99, category: 'Individual Items', description: 'Waakye on its own.' },
  { name: 'Rice Ball', price: 4.99, category: 'Individual Items', description: 'A single rice ball.' },
  { name: 'Fufu Ball', price: 4.99, category: 'Individual Items', description: 'A single fufu ball.' },
  { name: 'Kenkey Ball', price: 4.99, category: 'Individual Items', description: 'A single kenkey ball.' },
  { name: 'Eba Ball', price: 4.99, category: 'Individual Items', description: 'A single eba ball.' },
  { name: 'Fried Plantain (Individual)', price: 7.99, category: 'Individual Items', description: 'Fried plantain on its own.' },

  // ── Desserts ─────────────────────────────────────────────────────────
  { name: 'Brukina', price: 6.99, category: 'Desserts', description: 'Millet and fresh milk dessert drink.' },
  { name: 'Ghana Sponge Cake (Slice)', price: 4.99, category: 'Desserts', description: 'A slice of Ghana sponge cake.' },
  { name: 'Bofrot', price: 4.99, category: 'Desserts', description: 'Ghanaian puff puff.' },
  { name: 'Ghana Donuts', price: 4.99, category: 'Desserts', description: 'Ghana-style donuts.' },
  { name: 'Beef Patty', price: 3.99, category: 'Desserts', description: 'Savory beef patty.' },
  { name: 'Meat Pie', price: 4.99, category: 'Desserts', description: 'Savory meat pie.' },
  { name: 'Chin Chin', price: 4.99, category: 'Desserts', description: 'Crunchy fried snack.' },
  { name: 'Ice Cream Cup', price: 2.99, category: 'Desserts', description: 'A cup of ice cream.' },
  { name: 'Chocolate Chip Cookies (2 Cookies)', price: 2.99, category: 'Desserts', description: 'Two chocolate chip cookies.' },

  // ── Drinks — Traditional African Drinks ─────────────────────────────
  { name: 'Sobolo (Hibiscus Drink)', price: 5.99, category: 'Drinks', description: 'Traditional hibiscus drink.' },
  { name: 'Fresh Pineapple Ginger Juice', price: 5.99, category: 'Drinks', description: 'Fresh pineapple and ginger juice.' },

  // ── Drinks — Soft Drinks ─────────────────────────────────────────────
  { name: 'Coca-Cola', price: 2.99, category: 'Drinks', description: 'Coca-Cola, 1 can/bottle.' },
  { name: 'Diet Coke', price: 2.99, category: 'Drinks', description: 'Diet Coke, 1 can/bottle.' },
  { name: 'Sprite', price: 2.99, category: 'Drinks', description: 'Sprite, 1 can/bottle.' },
  { name: 'Fanta Orange', price: 2.99, category: 'Drinks', description: 'Fanta Orange, 1 can/bottle.' },
  { name: 'Ginger Ale', price: 2.99, category: 'Drinks', description: 'Ginger Ale, 1 can/bottle.' },
  { name: 'Pepsi', price: 2.99, category: 'Drinks', description: 'Pepsi, 1 can/bottle.' },
  { name: 'Dr Pepper', price: 2.99, category: 'Drinks', description: 'Dr Pepper, 1 can/bottle.' },

  // ── Drinks — African Soft Drinks ─────────────────────────────────────
  { name: 'Malta Guinness', price: 3.99, category: 'Drinks', description: 'Malta Guinness malt drink.' },
  { name: 'Alvaro (Malt Drink)', price: 3.99, category: 'Drinks', description: 'Alvaro malt drink.' },

  // ── Drinks — Water ───────────────────────────────────────────────────
  { name: 'Bottled Water', price: 1.99, category: 'Drinks', description: 'Bottled water.' },
];

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

async function seedMeals() {
  const rows = meals.map((meal) => ({
    slug: slugify(meal.name),
    name: meal.name,
    price: meal.price,
    description: meal.description,
    category: meal.category,
    active: true,
    available: true,
    image_url: ''
  }));

  const { error } = await supabase.from('meals').upsert(rows, { onConflict: 'slug' });
  if (error) throw error;

  console.log(`Seeded ${rows.length} meals into Supabase.`);
}

seedMeals().catch((err) => {
  console.error('Failed to seed meals:', err);
  process.exit(1);
});
