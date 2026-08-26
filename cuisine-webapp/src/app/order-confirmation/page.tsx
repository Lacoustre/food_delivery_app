'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'
import { CheckCircle, Clock, MapPin, Phone } from 'lucide-react'

export default function OrderConfirmationPage() {
  const [orderNumber, setOrderNumber] = useState<number | null>(null)
  const router = useRouter()

  useEffect(() => {
    // Generate order number only on client side to avoid hydration mismatch
    setOrderNumber(Math.floor(Math.random() * 10000) + 1000)
    
    // Clear any remaining cart data
    localStorage.removeItem('cart')
    localStorage.removeItem('orderType')
    localStorage.removeItem('deliveryAddress')
  }, [])

  return (
    <div className="min-h-screen bg-sand-100">
      <div className="page-shell-narrow px-4 py-16">
        <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 text-center">
          <CheckCircle className="w-20 h-20 text-kente mx-auto mb-6" />
          
          <h1 className="font-display text-3xl text-ink mb-4">
            Order Confirmed!
          </h1>
          
          <p className="text-lg text-sand-700 font-bold mb-8">
            Thank you for your order. We're preparing your delicious meal!
          </p>
          
          <div className="bg-sand-200 rounded-card p-6 border border-gold-300 mb-8">
            <h2 className="text-xl font-bold text-ink mb-4">Order Details</h2>
            <div className="space-y-3 text-left">
              <div className="flex justify-between">
                <span className="text-ink-soft font-bold">Order Number:</span>
                <span className="font-bold text-gold-600">
                  {orderNumber ? `#${orderNumber}` : 'Generating...'}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-gold" />
                <span className="text-ink-soft font-bold">Estimated Time: 45-60 minutes</span>
              </div>
            </div>
          </div>
          
          <div className="bg-white/80 rounded-card p-6 border border-gold-300 mb-8">
            <h3 className="text-lg font-bold text-ink mb-4 flex items-center gap-2">
              <MapPin className="w-5 h-5 text-gold" />
              Restaurant Information
            </h3>
            <div className="text-left space-y-2">
              <p className="font-bold text-ink">Taste of African Cuisine</p>
              <p className="text-ink-soft font-bold">200 Hartford Turnpike, Vernon, CT</p>
              <div className="flex items-center gap-2">
                <Phone className="w-4 h-4 text-gold" />
                <span className="text-ink-soft font-bold">(860) 805-5121</span>
              </div>
            </div>
          </div>
          
          <div className="space-y-4">
            <Link
              href="/"
              className="w-full block bg-gold text-white py-4 rounded-card font-bold text-lg hover:bg-gold-600 transition-all shadow-card"
            >
              Continue Shopping
            </Link>
            
            <p className="text-sm text-sand-700 font-bold">
              You will receive updates about your order via email or SMS
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}