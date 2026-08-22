import { supabase } from './supabase'

// Favorites live in the Supabase favorites table (unique per user+meal,
// owner-only RLS). The userId arguments are the legacy Firebase uid —
// ignored; the mirrored Supabase session identifies the user.
export const favoritesService = {
  async addFavorite(_userId: string, mealId: string) {
    const { data: userData } = await supabase.auth.getUser()
    if (!userData?.user) return
    await supabase
      .from('favorites')
      .upsert(
        { user_id: userData.user.id, meal_id: mealId },
        { onConflict: 'user_id,meal_id' },
      )
  },

  async removeFavorite(_userId: string, mealId: string) {
    const { data: userData } = await supabase.auth.getUser()
    if (!userData?.user) return
    await supabase
      .from('favorites')
      .delete()
      .eq('user_id', userData.user.id)
      .eq('meal_id', mealId)
  },

  onFavoritesChange(_userId: string, callback: (favorites: Set<string>) => void) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let channel: any = null
    let stopped = false

    const start = async () => {
      const { data: userData } = await supabase.auth.getUser()
      const user = userData?.user
      if (!user || stopped) {
        callback(new Set())
        return
      }

      const fetchAll = async () => {
        const { data } = await supabase.from('favorites').select('meal_id').eq('user_id', user.id)
        if (!stopped) callback(new Set((data ?? []).map((r) => r.meal_id as string)))
      }

      await fetchAll()
      channel = supabase
        .channel(`favorites-${user.id}`)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'favorites', filter: `user_id=eq.${user.id}` },
          fetchAll,
        )
        .subscribe()
    }

    start()
    return () => {
      stopped = true
      if (channel) supabase.removeChannel(channel)
    }
  },
}
