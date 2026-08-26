import { supabase } from './supabase'
import { getOpenState } from './hours'

export interface RestaurantStatus {
  isOpen: boolean
  message?: string
  updatedAt: Date
}

// Open/closed banner state, evaluated from the opening hours in the settings
// row rather than read from its `isOpen` field. That field is a cache the
// mobile app wrote from the same hours, so it went stale whenever no admin had
// the app open — the banner said closed at 4pm on a Wednesday while the
// schedule said 11:00–21:00. The server decides the same way, so the banner
// and the checkout can no longer disagree.
export const restaurantService = {
  onStatusChange(callback: (status: RestaurantStatus) => void): () => void {
    let stopped = false

    const fetchStatus = async () => {
      const [state, { data }] = await Promise.all([
        getOpenState(),
        supabase.from('settings').select('updated_at').eq('key', 'restaurant').single(),
      ])
      if (stopped) return
      callback({
        isOpen: state.open,
        message: state.open ? '' : (state.reason ?? ''),
        updatedAt: data?.updated_at ? new Date(data.updated_at) : new Date(),
      })
    }

    fetchStatus()
    // Re-evaluate on the minute so the banner flips at opening and closing
    // time without a page reload.
    const tick = setInterval(fetchStatus, 60_000)
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
      clearInterval(tick)
      supabase.removeChannel(channel)
    }
  },
}
