'use client'

import { useState, useEffect } from 'react'
import { Star, MessageCircle, User, Camera, X } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { reviewsService, type Review } from '@/lib/reviewsService'
import { orderService } from '@/lib/orderService'
import Image from 'next/image'

interface ReviewsProps {
  mealId: string
  mealName: string
  userCanReview?: boolean
}

export default function Reviews({ mealId, mealName, userCanReview = false }: ReviewsProps) {
  const { user, userProfile } = useAuth()
  const [reviews, setReviews] = useState<Review[]>([])
  const [showAddReview, setShowAddReview] = useState(false)
  const [rating, setRating] = useState(0)
  const [comment, setComment] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [selectedImages, setSelectedImages] = useState<File[]>([])
  const [imagePreviewUrls, setImagePreviewUrls] = useState<string[]>([])

  useEffect(() => {
    const unsubscribe = reviewsService.onReviewsChange(mealId, setReviews)
    return () => unsubscribe()
  }, [mealId])

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || [])
    if (files.length + selectedImages.length > 3) {
      alert('You can only upload up to 3 images')
      return
    }
    
    const newImages = [...selectedImages, ...files]
    setSelectedImages(newImages)
    
    // Create preview URLs
    const newPreviewUrls = files.map(file => URL.createObjectURL(file))
    setImagePreviewUrls(prev => [...prev, ...newPreviewUrls])
  }

  const removeImage = (index: number) => {
    const newImages = selectedImages.filter((_, i) => i !== index)
    const newPreviewUrls = imagePreviewUrls.filter((_, i) => i !== index)
    
    // Revoke the URL to free memory
    URL.revokeObjectURL(imagePreviewUrls[index])
    
    setSelectedImages(newImages)
    setImagePreviewUrls(newPreviewUrls)
  }

  const uploadImages = async (images: File[]): Promise<string[]> => {
    const { ref, uploadBytes, getDownloadURL } = await import('firebase/storage')
    const { storage } = await import('../lib/firebase')
    
    const uploadPromises = images.map(async (image) => {
      const imageRef = ref(storage, `reviews/${Date.now()}_${image.name}`)
      const snapshot = await uploadBytes(imageRef, image)
      return getDownloadURL(snapshot.ref)
    })
    
    return Promise.all(uploadPromises)
  }

  const handleSubmitReview = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user || !userProfile || rating === 0) return

    setSubmitting(true)
    try {
      let imageUrls: string[] = []
      
      // Upload images if any are selected
      if (selectedImages.length > 0) {
        try {
          imageUrls = await uploadImages(selectedImages)
        } catch (error) {
          console.error('Error uploading images:', error)
          alert('Failed to upload images. Review will be submitted without images.')
        }
      }
      
      await reviewsService.addReview({
        mealId,
        userId: user.uid,
        userName: userProfile.name,
        rating,
        comment,
        images: imageUrls
      })
      
      setRating(0)
      setComment('')
      setSelectedImages([])
      setImagePreviewUrls([])
      setShowAddReview(false)
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
            Write Review
          </button>
        )}
      </div>

      {/* Add Review Form */}
      {showAddReview && (
        <form onSubmit={handleSubmitReview} className="bg-orange-50 rounded-2xl p-6 mb-6 border border-orange-200">
          <h4 className="font-bold text-gray-900 mb-4">Rate {mealName}</h4>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Rating</label>
            {renderStars(rating, true, setRating)}
          </div>
          
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Photos (optional)</label>
            <div className="flex items-center gap-4">
              <label className="flex items-center gap-2 bg-orange-100 text-orange-600 px-4 py-2 rounded-xl cursor-pointer hover:bg-orange-200 transition-colors">
                <Camera className="w-4 h-4" />
                Add Photos ({selectedImages.length}/3)
                <input
                  type="file"
                  multiple
                  accept="image/*"
                  onChange={handleImageSelect}
                  className="hidden"
                  disabled={selectedImages.length >= 3}
                />
              </label>
            </div>
            
            {/* Image Previews */}
            {imagePreviewUrls.length > 0 && (
              <div className="flex gap-2 mt-3 flex-wrap">
                {imagePreviewUrls.map((url, index) => (
                  <div key={index} className="relative">
                    <img
                      src={url}
                      alt={`Preview ${index + 1}`}
                      className="w-20 h-20 object-cover rounded-lg border border-orange-200"
                    />
                    <button
                      type="button"
                      onClick={() => removeImage(index)}
                      className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center hover:bg-red-600 transition-colors"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>
          <div className="mb-4">
            <label className="block text-sm font-medium text-gray-700 mb-2">Comment</label>
            <textarea
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              className="w-full p-3 border border-orange-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none"
              rows={3}
              placeholder="Share your experience with this dish..."
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

      {/* Reviews List */}
      <div className="space-y-4">
        {reviews.length === 0 ? (
          <p className="text-gray-500 text-center py-8">No reviews yet. Be the first to review this dish!</p>
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
              {review.images && review.images.length > 0 && (
                <div className="flex gap-2 flex-wrap">
                  {review.images.map((imageUrl, index) => (
                    <div key={index} className="relative">
                      <Image
                        src={imageUrl}
                        alt={`Review image ${index + 1}`}
                        width={80}
                        height={80}
                        className="object-cover rounded-lg border border-orange-200"
                        unoptimized
                      />
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  )
}