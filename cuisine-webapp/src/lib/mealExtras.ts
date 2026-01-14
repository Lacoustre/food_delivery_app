export const mealExtras: Record<string, Array<{
  name: string
  price: number
  required: boolean
  group?: string
}>> = {
  'Waakye': [
    { name: 'Spaghetti', price: 0.0, required: false },
    { name: 'Gari', price: 0.0, required: false },
    { name: 'Egg', price: 0.0, required: false },
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 0.0, required: true, group: 'Protein' },
    { name: 'Goat Meat', price: 4.0, required: true, group: 'Protein' },
  ],
  'Jollof Rice': [
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 2.0, required: true, group: 'Protein' },
    { name: 'Goat Meat', price: 4.0, required: true, group: 'Protein' },
  ],
  'Fried Rice': [
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 2.0, required: true, group: 'Protein' },
    { name: 'Goat Meat', price: 4.0, required: true, group: 'Protein' },
  ],
  'Fried Yam': [
    { name: 'Turkey Wings', price: 0.0, required: true, group: 'Protein' },
    { name: 'Goat Meat', price: 4.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 0.0, required: true, group: 'Protein' },
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
  ],
  'Beans & Plantain': [
    { name: 'Meat', price: 0.0, required: true, group: 'Protein' },
    { name: 'Egg', price: 0.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 3.0, required: true, group: 'Protein' },
    { name: 'Turkey Wings', price: 0.0, required: true, group: 'Protein' },
  ],
  'Rice Ball & Peanut Soup': [
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
    { name: 'Goat meat', price: 0.0, required: true, group: 'Protein' },
  ],
  'Rice & Stew': [
    { name: 'Chicken', price: 0.0, required: true, group: 'Protein' },
    { name: 'Goat meat', price: 4.0, required: true, group: 'Protein' },
    { name: 'Fish', price: 3.0, required: true, group: 'Protein' },
    { name: 'Turkey Wings', price: 0.0, required: true, group: 'Protein' },
  ],
}