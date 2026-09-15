'use client'

import { useState, useEffect } from 'react'
import { Star, MessageCircle, User } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { reviewsService, type Review } from '@/lib/reviewsService'
import { GOOGLE_WRITE_REVIEW_URL } from '@/lib/googleReviewsService'

interface ReviewsProps {
  orderId: string
  orderLabel: string
  userCanReview?: boolean
}

export default function Reviews({ orderId, orderLabel, userCanReview = false }: ReviewsProps) {
  const { user } = useAuth()
  const [reviews, setReviews] = useState<Review[]>([])
  const [showAddReview, setShowAddReview] = useState(false)
  const [rating, setRating] = useState(0)
  const [comment, setComment] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [justReviewed, setJustReviewed] = useState(false)

  useEffect(() => {
    const unsubscribe = reviewsService.onReviewsChange(orderId, setReviews)
    return () => unsubscribe()
  }, [orderId])

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || rating === 0) return

    setSubmitting(true)
    try {
      await reviewsService.addReview({ orderId, rating, comment })
      setRating(0)
      setComment('')
      setShowAddReview(false)
      setJustReviewed(true)
    } catch (error) {
      console.error('Error adding review:', error)
      alert('Failed to add review. Please try again.')
    } finally {
      setSubmitting(false)
    }
  }

  const averageRating = reviews.length > 0
    ? reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length
    : 0

  const renderStars = (rating: number, interactive = false, onStarClick?: (star: number) => void) => {
    return (
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={`w-5 h-5 ${
              star <= rating
                ? 'fill-yellow-400 text-yellow-400'
                : 'text-gray-300'
            } ${interactive ? 'cursor-pointer hover:text-yellow-400' : ''}`}
            onClick={() => interactive && onStarClick?.(star)}
          />
        ))}
      </div>
    )
  }

  return (
    <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <MessageCircle className="w-6 h-6 text-orange-500" />
            Reviews ({reviews.length})
          </h3>
          {reviews.length > 0 && (
            <div className="flex items-center gap-2 mt-2">
              {renderStars(averageRating)}
              <span className="text-lg font-bold text-gray-900">
                {averageRating.toFixed(1)}
              </span>
            </div>
          )}
        </div>

        {user && userCanReview && !showAddReview && (
          <button
            onClick={() => setShowAddReview(true)}
            className="bg-orange-500 text-white px-4 py-2 rounded-xl font-medium hover:bg-orange-600 transition-colors"
          >
            {reviews.length > 0 ? 'Update Review' : 'Write Review'}
          </button>
        )}
      </div>

      {/* Add Review Form */}
      {showAddReview && (
        <form onSubmit={handleSubmitReview} className="bg-orange-50 rounded-2xl p-6 mb-6 border border-orange-200">
          <h4 className="font-bold text-gray-900 mb-4">Rate {orderLabel}</h4>

          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Rating</label>
            {renderStars(rating, true, setRating)}
          </div>

          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Comment</label>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              className="w-full p-3 border border-orange-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none"
              rows={3}
              placeholder="Share your experience with this order..."
              required
            />
          </div>

          <div className="flex gap-3">
            <button
              type="submit"
              disabled={rating === 0 || submitting}
              className="bg-orange-500 text-white px-6 py-2 rounded-xl font-medium hover:bg-orange-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {submitting ? 'Submitting...' : 'Submit Review'}
            </button>
            <button
              type="button"
              onClick={() => {
                setShowAddReview(false)
                setRating(0)
                setComment('')
              }}
              className="bg-gray-200 text-gray-700 px-6 py-2 rounded-xl font-medium hover:bg-gray-300 transition-colors"
            >
              Cancel
            </button>
          </div>
        </form>
      )}

      {/* Every reviewer is invited, whatever they rated. Google forbids asking
          only happy customers ("review gating"), and a business can't post a
          review for anyone — the customer writes it in their own account. */}
      {/* justReviewed as well: the list refreshes on a live update, which can
          lag or not arrive, and the thank-you shouldn't wait on it. */}
      {(justReviewed || reviews.length > 0) && !showAddReview && (
        <div
          data-google-invite
          className={`rounded-2xl p-4 mb-4 border flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
            justReviewed ? 'bg-kente-50 border-kente-50' : 'bg-white/80 border-orange-100'
          }`}
        >
          <p className="text-gray-800 font-medium">
            {justReviewed ? 'Thanks for your review. Would you post it on Google too?' : 'Post your review on Google too.'}
          </p>
          <a
            href={GOOGLE_WRITE_REVIEW_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center justify-center gap-2 shrink-0 bg-gray-900 text-white px-4 py-2 rounded-xl font-medium hover:bg-black transition-colors"
          >
            <Star className="w-4 h-4" />
            Review on Google
          </a>
        </div>
      )}

      {/* Reviews List */}
      <div className="space-y-4">
        {reviews.length === 0 ? (
          <p className="text-gray-500 text-center py-8">No review yet for this order.</p>
        ) : (
          reviews.map((review) => (
            <div key={review.id} className="bg-white/80 rounded-2xl p-4 border border-orange-100">
              <div className="flex items-start justify-between mb-2">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 bg-orange-500 rounded-full flex items-center justify-center">
                    <User className="w-5 h-5 text-white" />
                  </div>
                  <div>
                    <div className="font-medium text-gray-900">{review.userName}</div>
                    <div className="text-sm text-gray-500">
                      {new Date(review.createdAt).toLocaleDateString()}
                    </div>
                  </div>
                </div>
                {renderStars(review.rating)}
              </div>
              <p className="text-gray-700 mb-3">{review.comment}</p>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
