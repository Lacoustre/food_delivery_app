import { collection, addDoc, query, where, orderBy, onSnapshot, getDocs, doc, updateDoc } from 'firebase/firestore'
import { db } from './firebase'

export interface Review {
  id?: string
  mealId: string
  userId: string
  userName: string
  rating: number
  comment: string
  images?: string[]
  createdAt: Date
}

export const reviewsService = {
  async addReview(review: Omit<Review, 'id' | 'createdAt'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'reviews'), {
      ...review,
      createdAt: new Date()
    })
    return docRef.id
  },

  onReviewsChange(mealId: string, callback: (reviews: Review[]) => void) {
    const q = query(
      collection(db, 'reviews'),
      where('mealId', '==', mealId),
      orderBy('createdAt', 'desc')
    )
    
    return onSnapshot(q, (snapshot) => {
      const reviews = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Review[]
      callback(reviews)
    })
  },

  async getMealRating(mealId: string): Promise<{ average: number, count: number }> {
    const q = query(collection(db, 'reviews'), where('mealId', '==', mealId))
    const snapshot = await getDocs(q)
    
    if (snapshot.empty) {
      return { average: 0, count: 0 }
    }
    
    const reviews = snapshot.docs.map(doc => doc.data() as Review)
    const total = reviews.reduce((sum, review) => sum + review.rating, 0)
    
    return {
      average: total / reviews.length,
      count: reviews.length
    }
  }
}