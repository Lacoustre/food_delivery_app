import { supabase } from './supabase'

export interface Meal {
  id: string
  name: string
  price: number
  category: string
  imageUrl: string
  description?: string
  available: boolean
  active?: boolean
  /** Grouping key — rows sharing one render as a single menu card. */
  baseSlug: string
  baseName: string
  /** Describes the dish rather than the selected variant. Multi-variant cards only. */
  baseDescription?: string
  /** Option shown in the picker. Null when the dish has no variants. */
  variantLabel?: string
  /** protein | soup | preparation | side — drives the picker heading. */
  variantType?: string
  isVegetarian: boolean
  /** Main Dishes | Side Dishes | Desserts | Drinks */
  menuSection: string
}

function toMeal(row: {
  id: string
  name: string
  price: number
  category: string | null
  image_url: string | null
  description: string | null
  available: boolean
  active: boolean
  base_slug: string | null
  base_name: string | null
  base_description: string | null
  variant_label: string | null
  variant_type: string | null
  is_vegetarian: boolean | null
  menu_section: string | null
}): Meal {
  return {
    id: row.id,
    name: row.name,
    price: row.price,
    category: row.category || 'Main Dishes',
    imageUrl: row.image_url || '',
    description: row.description || undefined,
    available: row.available,
    active: row.active,
    // Fall back to the dish itself so a row predating the grouping migrations
    // still renders as its own card rather than vanishing from the menu.
    baseSlug: row.base_slug || row.id,
    baseName: row.base_name || row.name,
    baseDescription: row.base_description || undefined,
    variantLabel: row.variant_label || undefined,
    variantType: row.variant_type || undefined,
    isVegetarian: row.is_vegetarian ?? false,
    menuSection: row.menu_section || 'Main Dishes'
  }
}

export const mealsService = {
  async getAllMeals(): Promise<Meal[]> {
    const { data, error } = await supabase.from('meals').select('*')
    if (error) {
      console.error('Error fetching meals:', error)
      return []
    }
    return (data || []).map(toMeal)
  },

  // Real-time listener for meals
  onMealsChange(callback: (meals: Meal[]) => void): () => void {
    const fetchAndEmit = async () => {
      const { data, error } = await supabase.from('meals').select('*')
      if (error) {
        console.error('Error listening to meals:', error)
        callback([])
        return
      }
      callback((data || []).map(toMeal))
    }

    fetchAndEmit()

    const channel = supabase
      .channel('meals-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'meals' }, fetchAndEmit)
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  },

  async getMealsByCategory(category: string): Promise<Meal[]> {
    const { data, error } = await supabase.from('meals').select('*').eq('category', category)
    if (error) {
      console.error('Error fetching meals by category:', error)
      return []
    }
    return (data || []).map(toMeal)
  }
}
