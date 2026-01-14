import { collection, doc, getDoc, query, where, getDocs, orderBy, limit } from 'firebase/firestore'
import { db } from './firebase'

export interface Promotion {
  id: string
  code: string
  type: 'percentage' | 'fixed'
  value: number
  minOrderAmount?: number
  maxDiscount?: number
  description: string
  validFrom: Date
  validUntil: Date
  usageLimit?: number
  usedCount: number
  active: boolean
}

export const promotionsService = {
  async validatePromoCode(code: string, orderTotal: number): Promise<{ valid: boolean, promotion?: Promotion, discount?: number, error?: string }> {
    try {
      const q = query(
        collection(db, 'promotions'),
        where('code', '==', code.toUpperCase()),
        where('active', '==', true)
      )
      
      const snapshot = await getDocs(q)
      
      if (snapshot.empty) {
        return { valid: false, error: 'Invalid promo code' }
      }
      
      const promotion = { id: snapshot.docs[0].id, ...snapshot.docs[0].data() } as Promotion
      const now = new Date()
      
      // Check if promotion is still valid
      if (promotion.validUntil < now) {
        return { valid: false, error: 'Promo code has expired' }
      }
      
      if (promotion.validFrom > now) {
        return { valid: false, error: 'Promo code is not yet active' }
      }
      
      // Check usage limit
      if (promotion.usageLimit && promotion.usedCount >= promotion.usageLimit) {
        return { valid: false, error: 'Promo code usage limit reached' }
      }
      
      // Check minimum order amount
      if (promotion.minOrderAmount && orderTotal < promotion.minOrderAmount) {
        return { 
          valid: false, 
          error: `Minimum order amount of $${promotion.minOrderAmount.toFixed(2)} required` 
        }
      }
      
      // Calculate discount
      let discount = 0
      if (promotion.type === 'percentage') {
        discount = orderTotal * (promotion.value / 100)
        if (promotion.maxDiscount) {
          discount = Math.min(discount, promotion.maxDiscount)
        }
      } else {
        discount = promotion.value
      }
      
      return { valid: true, promotion, discount }
    } catch (error) {
      console.error('Error validating promo code:', error)
      return { valid: false, error: 'Error validating promo code' }
    }
  },

  async getActivePromotions(): Promise<Promotion[]> {
    try {
      const now = new Date()
      const q = query(
        collection(db, 'promotions'),
        where('active', '==', true),
        where('validUntil', '>', now),
        orderBy('validUntil', 'asc'),
        limit(5)
      )
      
      const snapshot = await getDocs(q)
      return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() } as Promotion))
    } catch (error) {
      console.error('Error fetching promotions:', error)
      return []
    }
  }
}