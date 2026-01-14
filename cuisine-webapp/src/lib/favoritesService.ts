import { collection, doc, setDoc, deleteDoc, onSnapshot, query, where } from 'firebase/firestore'
import { db } from './firebase'

export const favoritesService = {
  async addFavorite(userId: string, mealId: string) {
    await setDoc(doc(db, 'favorites', `${userId}_${mealId}`), {
      userId,
      mealId,
      createdAt: new Date()
    })
  },

  async removeFavorite(userId: string, mealId: string) {
    await deleteDoc(doc(db, 'favorites', `${userId}_${mealId}`))
  },

  onFavoritesChange(userId: string, callback: (favorites: Set<string>) => void) {
    const q = query(collection(db, 'favorites'), where('userId', '==', userId))
    return onSnapshot(q, (snapshot) => {
      const favoriteIds = new Set(snapshot.docs.map(doc => doc.data().mealId))
      callback(favoriteIds)
    })
  }
}