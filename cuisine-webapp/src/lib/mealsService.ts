import { collection, getDocs, doc, getDoc, query, where, orderBy, onSnapshot } from 'firebase/firestore'
import { db } from './firebase'

export interface Meal {
  id: string
  name: string
  price: number
  category: string
  rating?: number
  imageUrl: string
  description?: string
  available: boolean
  active?: boolean
  ingredients?: string[]
  spiceLevel?: 'mild' | 'medium' | 'hot'
  preparationTime?: number
}

export const mealsService = {
  async getAllMeals(): Promise<Meal[]> {
    try {
      const mealsCollection = collection(db, 'meals')
      const mealsSnapshot = await getDocs(mealsCollection)
      return mealsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Meal))
    } catch (error) {
      console.error('Error fetching meals:', error)
      return []
    }
  },

  // Real-time listener for meals
  onMealsChange(callback: (meals: Meal[]) => void): () => void {
    const mealsCollection = collection(db, 'meals')
    return onSnapshot(mealsCollection, (snapshot) => {
      const meals = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Meal))
      callback(meals)
    }, (error) => {
      console.error('Error listening to meals:', error)
      callback([])
    })
  },

  async getMealsByCategory(category: string): Promise<Meal[]> {
    try {
      const mealsCollection = collection(db, 'meals')
      const q = query(mealsCollection, where('category', '==', category))
      const mealsSnapshot = await getDocs(q)
      return mealsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Meal))
    } catch (error) {
      console.error('Error fetching meals by category:', error)
      return []
    }
  },

  async getFeaturedMeals(): Promise<Meal[]> {
    try {
      const mealsCollection = collection(db, 'meals')
      const q = query(mealsCollection, where('rating', '>=', 4.5), orderBy('rating', 'desc'))
      const mealsSnapshot = await getDocs(q)
      return mealsSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      } as Meal))
    } catch (error) {
      console.error('Error fetching featured meals:', error)
      return []
    }
  }
}