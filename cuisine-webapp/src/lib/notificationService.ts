import { getMessaging, getToken, onMessage } from 'firebase/messaging'
import { supabase } from './supabase'

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

  // Stored on the Supabase profile (profiles.fcm_token) — the same place
  // the mobile app keeps its token — using the mirrored Supabase session
  // instead of the old localStorage Firebase uid.
  async saveTokenToDatabase(token: string) {
    try {
      const { data: userData } = await supabase.auth.getUser()
      if (!userData?.user) return
      await supabase.from('profiles').update({ fcm_token: token }).eq('id', userData.user.id)
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