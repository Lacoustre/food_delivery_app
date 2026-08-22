import { supabase } from './supabase'

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

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function rowToPromotion(row: any): Promotion {
  return {
    id: row.id,
    code: row.code,
    type: row.type,
    value: Number(row.value),
    minOrderAmount: row.min_order_amount != null ? Number(row.min_order_amount) : undefined,
    maxDiscount: row.max_discount != null ? Number(row.max_discount) : undefined,
    description: row.description ?? '',
    validFrom: new Date(row.valid_from),
    validUntil: new Date(row.valid_until),
    usageLimit: row.usage_limit ?? undefined,
    usedCount: row.used_count ?? 0,
    active: row.active,
  }
}

// Promo codes live in the Supabase promotions table (public read, admin
// write). Validation math is unchanged from the Firestore version.
export const promotionsService = {
  async validatePromoCode(code: string, orderTotal: number): Promise<{ valid: boolean, promotion?: Promotion, discount?: number, error?: string }> {
    try {
      const { data } = await supabase
        .from('promotions')
        .select('*')
        .eq('code', code.toUpperCase())
        .eq('active', true)
        .maybeSingle()

      if (!data) {
        return { valid: false, error: 'Invalid promo code' }
      }

      const promotion = rowToPromotion(data)
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
      const { data } = await supabase
        .from('promotions')
        .select('*')
        .eq('active', true)
        .gt('valid_until', new Date().toISOString())
        .order('valid_until', { ascending: true })
        .limit(5)
      return (data ?? []).map(rowToPromotion)
    } catch (error) {
      console.error('Error fetching promotions:', error)
      return []
    }
  }
}
