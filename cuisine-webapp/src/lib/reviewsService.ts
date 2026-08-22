import { supabase } from './supabase'

// Reviews live in Supabase order_reviews — one review per order per user,
// the same table the mobile app writes and the admin panel moderates. The
// old Firestore per-meal `reviews` collection was invisible to both.
export interface Review {
  id?: string
  orderId: string
  userId: string
  userName: string
  rating: number
  comment: string
  createdAt: Date
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function rowToReview(row: any): Review {
  return {
    id: row.id,
    orderId: row.order_id,
    userId: row.user_id,
    userName: row.profiles?.name ?? 'Customer',
    rating: row.rating,
    comment: row.comment ?? '',
    createdAt: row.created_at ? new Date(row.created_at) : new Date(),
  }
}

export const reviewsService = {
  // Upsert: the table is unique on (order_id, user_id), so re-reviewing an
  // order updates the existing row — same behavior as the mobile app.
  // user_id comes from the mirrored Supabase session (RLS checks it) — the
  // app-level Firebase uid would be rejected.
  async addReview(review: { orderId: string; rating: number; comment: string }): Promise<void> {
    const { data: userData } = await supabase.auth.getUser()
    if (!userData?.user) throw new Error('Not signed in')
    const { error } = await supabase.from('order_reviews').upsert(
      {
        order_id: review.orderId,
        user_id: userData.user.id,
        rating: review.rating,
        comment: review.comment,
      },
      { onConflict: 'order_id,user_id' },
    )
    if (error) throw new Error(error.message)
  },

  onReviewsChange(orderId: string, callback: (reviews: Review[]) => void) {
    let stopped = false

    const fetchAll = async () => {
      const { data } = await supabase
        .from('order_reviews')
        .select('*, profiles(name)')
        .eq('order_id', orderId)
        .order('created_at', { ascending: false })
      if (!stopped) callback((data ?? []).map(rowToReview))
    }

    fetchAll()
    const channel = supabase
      .channel(`order-reviews-${orderId}`)
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'order_reviews', filter: `order_id=eq.${orderId}` },
        fetchAll,
      )
      .subscribe()

    return () => {
      stopped = true
      supabase.removeChannel(channel)
    }
  },
}
