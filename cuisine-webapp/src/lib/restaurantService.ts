import { supabase } from './supabase'

export interface RestaurantStatus {
  isOpen: boolean
  message?: string
  updatedAt: Date
}

// Open/closed banner state — the Supabase settings row key='restaurant'
// (value jsonb {isOpen, message}), written by the admin panel and the
// mobile app's hours auto-scheduler.
export const restaurantService = {
  onStatusChange(callback: (status: RestaurantStatus) => void): () => void {
    let stopped = false

    const fetchStatus = async () => {
      const { data } = await supabase.from('settings').select('value, updated_at').eq('key', 'restaurant').single()
      if (stopped) return
      const value = (data?.value ?? {}) as { isOpen?: boolean; message?: string }
      callback({
        isOpen: value.isOpen ?? true,
        message: value.message || '',
        updatedAt: data?.updated_at ? new Date(data.updated_at) : new Date(),
      })
    }

    fetchStatus()
    const channel = supabase
      .channel('restaurant-status')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'settings', filter: 'key=eq.restaurant' },
        fetchStatus,
      )
      .subscribe()

    return () => {
      stopped = true
      supabase.removeChannel(channel)
    }
  },
}
