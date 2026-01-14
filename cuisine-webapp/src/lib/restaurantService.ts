import { doc, onSnapshot } from 'firebase/firestore'
import { db } from './firebase'

export interface RestaurantStatus {
  isOpen: boolean
  message?: string
  updatedAt: Date
}

export const restaurantService = {
  onStatusChange(callback: (status: RestaurantStatus) => void): () => void {
    const statusDoc = doc(db, 'settings', 'restaurant')
    console.log('Setting up restaurant status listener...')
    
    return onSnapshot(statusDoc, (doc) => {
      console.log('Restaurant status document updated:', doc.exists(), doc.data())
      if (doc.exists()) {
        const data = doc.data()
        const status = {
          isOpen: data.isOpen ?? true,
          message: data.message || '',
          updatedAt: data.updatedAt?.toDate() || new Date()
        }
        console.log('Parsed restaurant status:', status)
        callback(status)
      } else {
        console.log('No restaurant status document found, defaulting to open')
        callback({
          isOpen: true,
          message: '',
          updatedAt: new Date()
        })
      }
    }, (error) => {
      console.error('Error listening to restaurant status:', error)
      callback({
        isOpen: true,
        message: '',
        updatedAt: new Date()
      })
    })
  }
}