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
}): Meal {
  return {
    id: row.id,
    name: row.name,
    price: row.price,
    category: row.category || 'Main Dishes',
    imageUrl: row.image_url || '',
    description: row.description || undefined,
    available: row.available,
    active: row.active
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
