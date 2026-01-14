'use client'

import { useState } from 'react'
import { Tag, Check, X } from 'lucide-react'
import { promotionsService, type Promotion } from '@/lib/promotionsService'

interface PromoCodeProps {
  orderTotal: number
  onPromoApplied: (promotion: Promotion, discount: number) => void
  onPromoRemoved: () => void
  appliedPromo?: { promotion: Promotion, discount: number }
}

export default function PromoCode({ orderTotal, onPromoApplied, onPromoRemoved, appliedPromo }: PromoCodeProps) {
  const [promoCode, setPromoCode] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleApplyPromo = async () => {
    if (!promoCode.trim()) return
    
    setLoading(true)
    setError('')
    
    try {
      const result = await promotionsService.validatePromoCode(promoCode, orderTotal)
      
      if (result.valid && result.promotion && result.discount !== undefined) {
        onPromoApplied(result.promotion, result.discount)
        setPromoCode('')
      } else {
        setError(result.error || 'Invalid promo code')
      }
    } catch (error) {
      setError('Failed to apply promo code')
    } finally {
      setLoading(false)
    }
  }

  const handleRemovePromo = () => {
    onPromoRemoved()
    setError('')
  }

  return (
    <div className="bg-white/60 backdrop-blur-sm rounded-2xl shadow-lg border border-orange-200 p-6">
      <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
        <Tag className="w-5 h-5 text-orange-500" />
        Promo Code
      </h3>
      
      {appliedPromo ? (
        <div className="bg-green-50 border border-green-200 rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Check className="w-5 h-5 text-green-600" />
              <div>
                <div className="font-bold text-green-800">{appliedPromo.promotion.code}</div>
                <div className="text-sm text-green-700">{appliedPromo.promotion.description}</div>
                <div className="text-sm font-bold text-green-800">
                  Discount: -${appliedPromo.discount.toFixed(2)}
                </div>
              </div>
            </div>
            <button
              onClick={handleRemovePromo}
              className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex gap-2">
            <input
              type="text"
              value={promoCode}
              onChange={(e) => setPromoCode(e.target.value.toUpperCase())}
              placeholder="Enter promo code"
              className="flex-1 p-3 border-2 border-orange-200 rounded-xl focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none"
              onKeyPress={(e) => e.key === 'Enter' && handleApplyPromo()}
            />
            <button
              onClick={handleApplyPromo}
              disabled={!promoCode.trim() || loading}
              className="bg-orange-500 text-white px-6 py-3 rounded-xl font-medium hover:bg-orange-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? 'Applying...' : 'Apply'}
            </button>
          </div>
          
          {error && (
            <div className="text-red-600 text-sm bg-red-50 p-3 rounded-lg border border-red-200">
              {error}
            </div>
          )}
        </div>
      )}
    </div>
  )
}