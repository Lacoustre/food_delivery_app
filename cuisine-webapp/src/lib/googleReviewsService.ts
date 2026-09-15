import { supabase } from '@/lib/supabase'

/**
 * Reviews synced from the Google Business Profile API by the
 * sync-google-reviews edge function.
 *
 * The homepage carousel falls back to its hardcoded list while this table is
 * empty, which it will be until Google approves API access. That keeps the
 * section working rather than showing an empty carousel for however long the
 * approval takes.
 */

export interface GoogleReview {
  name: string
  reviewerName: string
  reviewerPhoto?: string
  rating: number
  comment: string
  createdAt: string
  reply?: string
}

/** "4 months ago" — Google shows relative dates and people expect them here. */
export function relativeDate(iso: string): string {
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return ''
  const days = Math.floor((Date.now() - then) / 86_400_000)

  if (days < 1) return 'today'
  if (days === 1) return 'yesterday'
  if (days < 30) return `${days} days ago`

  const months = Math.floor(days / 30)
  if (months < 12) return months === 1 ? 'a month ago' : `${months} months ago`

  const years = Math.floor(days / 365)
  return years === 1 ? 'a year ago' : `${years} years ago`
}

export const googleReviewsService = {
  /**
   * Only reviews with text. A bare five stars and no words makes a poor
   * carousel slide, however good the rating.
   */
  async getReviews(limit = 12): Promise<GoogleReview[]> {
    try {
      const { data, error } = await supabase
        .from('google_reviews')
        .select('name, reviewer_name, reviewer_photo, rating, comment, created_at, reply')
        .not('comment', 'is', null)
        .neq('comment', '')
        .order('created_at', { ascending: false })
        .limit(limit)

      if (error || !data) return []

      return data.map(r => ({
        name: r.name,
        reviewerName: r.reviewer_name,
        reviewerPhoto: r.reviewer_photo ?? undefined,
        rating: r.rating,
        comment: r.comment,
        createdAt: r.created_at,
        reply: r.reply ?? undefined
      }))
    } catch {
      // A failed fetch should leave the carousel on its fallback, not break
      // the homepage.
      return []
    }
  },

  /** The real average, for showing a rating anywhere. Null if there are none. */
  async getSummary(): Promise<{ count: number; average: number } | null> {
    try {
      const { data, error } = await supabase
        .from('google_reviews')
        .select('rating')

      if (error || !data?.length) return null
      const total = data.reduce((sum, r) => sum + (r.rating ?? 0), 0)
      return {
        count: data.length,
        average: Number((total / data.length).toFixed(1))
      }
    } catch {
      return null
    }
  }
}

/**
 * The restaurant's Google listing, for reading its reviews.
 */
export const GOOGLE_REVIEWS_URL = 'https://www.google.com/maps/place/TASTE+OF+AFRICAN+CUISINE/@41.8244336,-72.4977335,17z/data=!4m17!1m8!3m7!1s0x89e659d27432c9e5:0x507eb4ac1cfc581d!2sTASTE+OF+AFRICAN+CUISINE!8m2!3d41.8244336!4d-72.4977335!10e9!16s%2Fg%2F11vb0yh4nv!3m7!1s0x89e659d27432c9e5:0x507eb4ac1cfc581d!8m2!3d41.8244336!4d-72.4977335!9m1!1b1!16s%2Fg%2F11vb0yh4nv?entry=ttu&g_ep=EgoyMDI2MDkwOS4wIKXMDSoASAFQAw%3D%3D'

/**
 * Where a customer goes to post a review on Google. A business can't post
 * one for them: Google only takes reviews written by the customer in their
 * own account, so the site sends people here and they write it themselves.
 *
 * For now the listing, which has a "Write a review" button. The "Ask for
 * reviews" link from Google Business Profile opens the form directly and is
 * better; put it here when the restaurant shares it.
 */
export const GOOGLE_WRITE_REVIEW_URL = GOOGLE_REVIEWS_URL
