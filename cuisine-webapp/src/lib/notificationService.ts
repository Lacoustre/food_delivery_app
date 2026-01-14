import { getMessaging, getToken, onMessage } from 'firebase/messaging'
import { doc, updateDoc } from 'firebase/firestore'
import { db } from './firebase'

class NotificationService {
  private messaging: any = null

  async init() {
    if (typeof window === 'undefined') return

    try {
      this.messaging = getMessaging()
      await this.requestPermission()
    } catch (error) {
      console.error('Notification service init failed:', error)
    }
  }

  async requestPermission() {
    if (!('Notification' in window)) return

    const permission = await Notification.requestPermission()
    if (permission === 'granted') {
      await this.getToken()
    }
  }

  async getToken() {
    if (!this.messaging) return

    try {
      const token = await getToken(this.messaging, {
        vapidKey: process.env.NEXT_PUBLIC_VAPID_KEY
      })
      
      if (token) {
        await this.saveTokenToDatabase(token)
        return token
      }
    } catch (error) {
      console.error('Token generation failed:', error)
    }
  }

  async saveTokenToDatabase(token: string) {
    const userId = localStorage.getItem('userId')
    if (!userId) return

    try {
      await updateDoc(doc(db, 'users', userId), {
        fcmToken: token,
        updatedAt: new Date()
      })
    } catch (error) {
      console.error('Failed to save token:', error)
    }
  }

  onMessage(callback: (payload: any) => void) {
    if (!this.messaging) return

    return onMessage(this.messaging, callback)
  }
}

export const notificationService = new NotificationService()