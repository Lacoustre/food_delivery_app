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
    localStorage.removeItem('calculatedDistance')
  }, [])

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100">
      <div className="max-w-2xl mx-auto px-4 py-16">
        <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 text-center">
          <CheckCircle className="w-20 h-20 text-green-500 mx-auto mb-6" />
          
          <h1 className="text-3xl font-bold text-gray-900 mb-4">
            Order Confirmed!
          </h1>
          
          <p className="text-lg text-gray-700 font-bold mb-8">
            Thank you for your order. We're preparing your delicious meal!
          </p>
          
          <div className="bg-gradient-to-r from-orange-100 to-red-100 rounded-2xl p-6 border border-orange-200 mb-8">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Order Details</h2>
            <div className="space-y-3 text-left">
              <div className="flex justify-between">
                <span className="text-gray-800 font-bold">Order Number:</span>
                <span className="font-bold text-orange-600">
                  {orderNumber ? `#${orderNumber}` : 'Generating...'}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-orange-500" />
                <span className="text-gray-800 font-bold">Estimated Time: 45-60 minutes</span>
              </div>
            </div>
          </div>
          
          <div className="bg-white/80 rounded-2xl p-6 border border-orange-200 mb-8">
            <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2">
              <MapPin className="w-5 h-5 text-orange-500" />
              Restaurant Information
            </h3>
            <div className="text-left space-y-2">
              <p className="font-bold text-gray-900">Taste of African Cuisine</p>
              <p className="text-gray-800 font-bold">200 Hartford Turnpike, Vernon, CT</p>
              <div className="flex items-center gap-2">
                <Phone className="w-4 h-4 text-orange-500" />
                <span className="text-gray-800 font-bold">(860) 123-4567</span>
              </div>
            </div>
          </div>
          
          <div className="space-y-4">
            <Link
              href="/"
              className="w-full block bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-2xl font-bold text-lg hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
            >
              Continue Shopping
            </Link>
            
            <p className="text-sm text-gray-700 font-bold">
              You will receive updates about your order via email or SMS
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}