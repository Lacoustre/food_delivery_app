'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { ArrowLeft, CreditCard, Lock, MapPin, Clock, User, Navigation } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { loadStripe } from '@stripe/stripe-js'
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js'
import { orderService } from '@/lib/orderService'
import PromoCode from '@/components/PromoCode'
import { promotionsService, type Promotion } from '@/lib/promotionsService'
import { createPaymentIntent, stripePromise } from '@/lib/stripeService'
import { useToast } from '@/hooks/use-toast'
import { Toaster } from '@/components/ui/toaster'

interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
  imageUrl: string
  category: string
}

interface OrderData {
  orderType: 'delivery' | 'pickup'
  deliveryAddress?: string
  customerInfo: {
    name: string
    email: string
    phone: string
  }
  paymentMethod: 'card' | 'cash'
  deliveryTime?: string
}

const StripePaymentForm = ({ onPaymentSuccess, total, processing, orderData }: {
  onPaymentSuccess: () => void
  total: number
  processing: boolean
  orderData: OrderData
}) => {
  const stripe = useStripe()
  const elements = useElements()
  const [error, setError] = useState<string | null>(null)
  const [clientSecret, setClientSecret] = useState<string | null>(null)
  const [isProcessing, setIsProcessing] = useState(false)

  useEffect(() => {
    createPaymentIntent(total).then(({ clientSecret }) => {
      setClientSecret(clientSecret)
    }).catch(err => {
      console.error('Failed to create payment intent:', err)
      setError('Failed to initialize payment. Please try again.')
    })
  }, [total])

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    
    if (!stripe || !elements || !clientSecret || isProcessing || processing) return
    
    setIsProcessing(true)
    setError(null)
    
    try {
      const { error: submitError } = await elements.submit()
      if (submitError) {
        setError(submitError.message || 'Payment validation failed')
        setIsProcessing(false)
        return
      }
      
      const { error, paymentIntent } = await stripe.confirmPayment({
        elements,
        clientSecret,
        redirect: 'if_required'
      })

      if (error) {
        setError(error.message || 'Payment failed')
      } else if (paymentIntent?.status === 'succeeded') {
        onPaymentSuccess()
      }
    } catch (err) {
      console.error('Payment error:', err)
      setError('Payment failed. Please try again.')
    } finally {
      setIsProcessing(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="p-6 border-2 border-orange-200 rounded-2xl bg-white/80">
        {clientSecret ? (
          <PaymentElement />
        ) : (
          <div className="text-center py-8 text-gray-600">Loading payment form...</div>
        )}
      </div>
      {error && (
        <div className="text-red-600 text-sm bg-red-50 p-3 rounded-lg border border-red-200">
          {error}
        </div>
      )}
      <button
        type="submit"
        disabled={!stripe || !clientSecret || isProcessing || processing}
        className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-2xl font-bold text-lg hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
      >
        {(isProcessing || processing) ? (
          <>
            <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-white"></div>
            Processing Payment...
          </>
        ) : (
          <>
            <Lock className="w-5 h-5" />
            Pay ${total.toFixed(2)}
          </>
        )}
      </button>
    </form>
  )
}

function CheckoutContent() {
  // Function to decode HTML entities in URLs
  const decodeImageUrl = (url: string) => {
    if (!url) return '/assets/images/logo.png'
    // Decode HTML entities - handle double encoding
    let decoded = url
      .replace(/&amp;amp;/g, '&')  // Handle double encoding first
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
    return decoded
  }

  const [cartItems, setCartItems] = useState<CartItem[]>([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  const [clientSecret, setClientSecret] = useState<string | null>(null)
  const [locationLoading, setLocationLoading] = useState(false)
  const [paymentSuccess, setPaymentSuccess] = useState(false)
  const [appliedPromo, setAppliedPromo] = useState<{ promotion: Promotion, discount: number } | undefined>()
  const [orderData, setOrderData] = useState<OrderData>({
    orderType: 'delivery',
    customerInfo: { name: '', email: '', phone: '' },
    paymentMethod: 'card'
  })
  
  const { user, userProfile } = useAuth()
  const router = useRouter()
  const { toast } = useToast()

  // Check for payment success from URL params
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.get('payment_success') === 'true') {
      setPaymentSuccess(true)
      // Clean up URL
      window.history.replaceState({}, '', '/checkout')
    }
  }, [])

  useEffect(() => {
    // Enhanced authentication check with session recovery
    if (!user && typeof window !== 'undefined') {
      const hasCart = localStorage.getItem('cart')
      const authToken = localStorage.getItem('authToken')
      
      if (hasCart && !authToken) {
        // Preserve checkout flow
        localStorage.setItem('checkoutRedirect', 'true')
        router.push('/login?redirect=checkout')
        return
      }
    }

    if (!user) return

    const savedCart = localStorage.getItem('cart')
    const savedOrderType = localStorage.getItem('orderType') || 'delivery'
    const savedDeliveryAddress = localStorage.getItem('deliveryAddress') || ''

    if (!savedCart || JSON.parse(savedCart).length === 0) {
      router.push('/cart')
      return
    }

    setCartItems(JSON.parse(savedCart))
    setOrderData(prev => ({
      ...prev,
      orderType: savedOrderType as 'delivery' | 'pickup',
      deliveryAddress: savedDeliveryAddress,
      customerInfo: {
        name: userProfile?.name || '',
        email: user.email || '',
        phone: userProfile?.phone || ''
      }
    }))
    
    // Auto-detect location if delivery and no saved address
    if (savedOrderType === 'delivery' && !savedDeliveryAddress) {
      detectLocation()
    }
    
    setLoading(false)
  }, [user, userProfile, router])

  const calculateDeliveryFee = (distance: number = 3) => {
    const baseFee = 3.99
    const baseTierMaxDistance = 3.0
    const midTierMaxDistance = 10.0
    const midTierRatePerMile = 0.50
    const extendedTierBase = 7.49
    const extendedTierRatePerMile = 0.75

    if (distance <= baseTierMaxDistance) {
      return baseFee
    } else if (distance <= midTierMaxDistance) {
      return baseFee + (distance - baseTierMaxDistance) * midTierRatePerMile
    } else {
      return extendedTierBase + (distance - midTierMaxDistance) * extendedTierRatePerMile
    }
  }

  const [calculatedDistance, setCalculatedDistance] = useState<number>(3)

  useEffect(() => {
    const savedDistance = localStorage.getItem('calculatedDistance')
    if (savedDistance) {
      setCalculatedDistance(parseFloat(savedDistance))
    }
  }, [])

  const subtotal = cartItems.reduce((sum, item) => sum + (item.price * item.quantity), 0)
  const deliveryFee = orderData.orderType === 'delivery' ? calculateDeliveryFee(calculatedDistance) : 0
  const promoDiscount = appliedPromo?.discount || 0
  const tax = (subtotal + deliveryFee - promoDiscount) * 0.0735
  const total = subtotal + deliveryFee + tax - promoDiscount

  useEffect(() => {
    if (total > 0) {
      createPaymentIntent(total).then(({ clientSecret }) => {
        setClientSecret(clientSecret)
      })
    }
  }, [total])

  const getCurrentLocation = async () => {
    setLocationLoading(true)
    try {
      if (!navigator.geolocation) {
        throw new Error('Geolocation is not supported by this browser')
      }

      const position = await new Promise<GeolocationPosition>((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 15000,
          maximumAge: 60000
        })
      })

      const { latitude, longitude } = position.coords
      
      // Try multiple geocoding services for better accuracy
      let address = ''
      
      try {
        // First try: Nominatim (OpenStreetMap)
        const nominatimResponse = await fetch(
          `https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}&addressdetails=1`
        )
        
        if (nominatimResponse.ok) {
          const data = await nominatimResponse.json()
          const addr = data.address
          address = `${addr.house_number || ''} ${addr.road || ''}, ${addr.city || addr.town || addr.village || ''}, ${addr.state || ''} ${addr.postcode || ''}, ${addr.country || ''}`.replace(/,\s*,/g, ',').replace(/^,\s*|,\s*$/g, '')
        }
      } catch (error) {
        console.log('Nominatim failed, trying backup service')
      }
      
      // Fallback: BigDataCloud
      if (!address) {
        const response = await fetch(
          `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${latitude}&longitude=${longitude}&localityLanguage=en`
        )
        
        if (response.ok) {
          const data = await response.json()
          address = `${data.locality || ''}, ${data.principalSubdivision || ''} ${data.postcode || ''}, ${data.countryName || ''}`.replace(/,\s*,/g, ',').replace(/^,\s*|,\s*$/g, '')
        }
      }
      
      if (!address) {
        throw new Error('Could not determine address from location')
      }
      
      setOrderData(prev => ({ ...prev, deliveryAddress: address }))
      localStorage.setItem('deliveryAddress', address)
    } catch (error) {
      console.error('Location error:', error)
      let errorMessage = 'Unable to get your location. '
      if (error instanceof GeolocationPositionError) {
        switch (error.code) {
          case error.PERMISSION_DENIED:
            errorMessage += 'Please allow location access and try again.'
            break
          case error.POSITION_UNAVAILABLE:
            errorMessage += 'Location information is unavailable.'
            break
          case error.TIMEOUT:
            errorMessage += 'Location request timed out.'
            break
        }
      } else {
        errorMessage += 'Please enter your address manually.'
      }
      toast({
        variant: 'destructive',
        title: 'Location Error',
        description: errorMessage
      })
    } finally {
      setLocationLoading(false)
    }
  }

  const handlePaymentSuccess = async () => {
    setProcessing(true)
    
    try {
      // Validate required fields
      if (!orderData.customerInfo.name || !orderData.customerInfo.phone) {
        toast({
          variant: 'destructive',
          title: 'Missing Information',
          description: 'Please fill in all required customer information'
        })
        return
      }
      
      if (orderData.orderType === 'delivery' && !orderData.deliveryAddress) {
        toast({
          variant: 'destructive',
          title: 'Missing Address',
          description: 'Please provide a delivery address'
        })
        return
      }
      
      if (!orderData.deliveryTime) {
        toast({
          variant: 'destructive',
          title: 'Missing Time Selection',
          description: 'Please select a preferred delivery/pickup time'
        })
        return
      }

      // Create order in database
      const orderPayload = {
        orderNumber: Math.floor(Math.random() * 10000) + 1000,
        userId: user?.uid || '',
        customerInfo: orderData.customerInfo,
        items: cartItems.map(item => ({
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: item.quantity
        })),
        orderType: orderData.orderType,
        deliveryAddress: orderData.deliveryAddress,
        deliveryTime: orderData.deliveryTime,
        subtotal,
        deliveryFee,
        tax,
        total,
        paymentMethod: orderData.paymentMethod,
        status: 'confirmed' as const
      }
      
      await orderService.createOrder(orderPayload)
      
      // Send confirmation email
      try {
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type: 'confirmation',
            orderData: {
              customerEmail: orderData.customerInfo.email,
              customerName: orderData.customerInfo.name,
              orderNumber: orderPayload.orderNumber,
              orderType: orderData.orderType,
              items: cartItems.map(item => ({
                name: item.name,
                quantity: item.quantity,
                price: item.price
              })),
              subtotal,
              deliveryFee,
              tax,
              total,
              deliveryAddress: orderData.deliveryAddress,
              status: 'confirmed'
            }
          })
        })
      } catch (emailError) {
        console.error('Failed to send confirmation email:', emailError)
      }
      
      // Send confirmation notification
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification('Order Confirmed!', {
          body: `Your order #${orderPayload.orderNumber} has been confirmed. We're preparing your delicious meal!`,
          icon: '/assets/images/logo.png'
        })
      }
      
      // Clear cart and redirect
      localStorage.removeItem('cart')
      localStorage.removeItem('orderType')
      localStorage.removeItem('deliveryAddress')
      localStorage.removeItem('calculatedDistance')
      localStorage.removeItem('checkoutRedirect')
      
      setPaymentSuccess(true)
      
      // Delay redirect to show success state
      setTimeout(() => {
        router.push('/order-confirmation')
      }, 2000)
    } catch (error) {
      console.error('Order failed:', error)
      toast({
        variant: 'destructive',
        title: 'Order Failed',
        description: error instanceof Error ? error.message : 'Order failed. Please try again.'
      })
    } finally {
      setProcessing(false)
    }
  }

  const handleCashOrder = async () => {
    setProcessing(true)
    
    try {
      // Validate required fields
      if (!orderData.customerInfo.name || !orderData.customerInfo.phone) {
        toast({
          variant: 'destructive',
          title: 'Missing Information',
          description: 'Please fill in all required customer information'
        })
        return
      }
      
      if (orderData.orderType === 'delivery' && !orderData.deliveryAddress) {
        toast({
          variant: 'destructive',
          title: 'Missing Address',
          description: 'Please provide a delivery address'
        })
        return
      }
      
      if (!orderData.deliveryTime) {
        toast({
          variant: 'destructive',
          title: 'Missing Time Selection',
          description: 'Please select a preferred delivery/pickup time'
        })
        return
      }

      // Create order in database
      const orderPayload = {
        orderNumber: Math.floor(Math.random() * 10000) + 1000,
        userId: user?.uid || '',
        customerInfo: orderData.customerInfo,
        items: cartItems.map(item => ({
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: item.quantity
        })),
        orderType: orderData.orderType,
        deliveryAddress: orderData.deliveryAddress,
        deliveryTime: orderData.deliveryTime,
        subtotal,
        deliveryFee,
        tax,
        total,
        paymentMethod: orderData.paymentMethod,
        status: 'confirmed' as const
      }
      
      await orderService.createOrder(orderPayload)
      
      // Send confirmation email
      try {
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type: 'confirmation',
            orderData: {
              customerEmail: orderData.customerInfo.email,
              customerName: orderData.customerInfo.name,
              orderNumber: orderPayload.orderNumber,
              orderType: orderData.orderType,
              items: cartItems.map(item => ({
                name: item.name,
                quantity: item.quantity,
                price: item.price
              })),
              subtotal,
              deliveryFee,
              tax,
              total,
              deliveryAddress: orderData.deliveryAddress,
              status: 'confirmed'
            }
          })
        })
      } catch (emailError) {
        console.error('Failed to send confirmation email:', emailError)
      }
      
      // Send confirmation notification
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification('Order Confirmed!', {
          body: `Your order #${orderPayload.orderNumber} has been confirmed. We're preparing your delicious meal!`,
          icon: '/assets/images/logo.png'
        })
      }
      
      // Clear cart and redirect
      localStorage.removeItem('cart')
      localStorage.removeItem('orderType')
      localStorage.removeItem('deliveryAddress')
      localStorage.removeItem('calculatedDistance')
      
      router.push('/order-confirmation')
    } catch (error) {
      console.error('Order failed:', error)
      toast({
        variant: 'destructive',
        title: 'Order Failed',
        description: error instanceof Error ? error.message : 'Order failed. Please try again.'
      })
    } finally {
      setProcessing(false)
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500"></div>
      </div>
    )
  }

  // Show success state if payment completed
  if (paymentSuccess) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
        <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 text-center max-w-md">
          <div className="w-16 h-16 bg-green-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Payment Successful!</h2>
          <p className="text-gray-700 mb-4">Your order has been confirmed. Redirecting...</p>
          <div className="animate-spin rounded-full h-6 w-6 border-t-2 border-orange-500 mx-auto"></div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 relative overflow-hidden">
      {/* Background Logo */}
      <div className="fixed inset-0 flex items-center justify-center opacity-5 pointer-events-none z-0">
        <img 
          src="/assets/images/logo.png" 
          alt="Background Logo" 
          className="w-96 h-96 object-contain"
        />
      </div>
      
      <div className="relative z-10">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-md shadow-lg border-b border-orange-100">
        <div className="max-w-6xl mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/cart" className="p-3 hover:bg-orange-100 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-orange-600" />
            </Link>
            <div>
              <h1 className="text-3xl font-bold bg-gradient-to-r from-orange-600 to-red-600 bg-clip-text text-transparent">
                Checkout
              </h1>
              <p className="text-gray-700 font-bold">Complete your order</p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Left Column - Forms */}
          <div className="lg:col-span-2 space-y-6">
            {/* Customer Information */}
            <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                <User className="w-6 h-6 text-orange-500" />
                Customer Information
              </h3>
              <div className="grid md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-bold text-gray-800 mb-2">Full Name *</label>
                  <input
                    type="text"
                    value={orderData.customerInfo.name}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, name: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 h-14 text-gray-900 font-bold"
                    placeholder="Enter your full name"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-bold text-gray-800 mb-2">Phone Number *</label>
                  <input
                    type="tel"
                    value={orderData.customerInfo.phone}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, phone: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 h-14 text-gray-900 font-bold"
                    placeholder="(555) 123-4567"
                    required
                  />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-bold text-gray-800 mb-2">Email Address *</label>
                  <input
                    type="email"
                    value={orderData.customerInfo.email}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, email: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 h-14 text-gray-900 font-bold"
                    placeholder="your@email.com"
                    required
                  />
                </div>
              </div>
            </div>

            {/* Delivery Information */}
            <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                <MapPin className="w-6 h-6 text-orange-500" />
                {orderData.orderType === 'delivery' ? 'Delivery' : 'Pickup'} Information
              </h3>
              
              {orderData.orderType === 'delivery' ? (
                <div className="space-y-4">
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="block text-sm font-bold text-gray-800">Delivery Address *</label>
                      <button
                        type="button"
                        onClick={getCurrentLocation}
                        disabled={locationLoading}
                        className="flex items-center gap-2 px-3 py-1 text-sm bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors disabled:opacity-50"
                      >
                        {locationLoading ? (
                          <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-white"></div>
                        ) : (
                          <Navigation className="w-4 h-4" />
                        )}
                        {locationLoading ? 'Getting Location...' : 'Use Current Location'}
                      </button>
                    </div>
                    <textarea
                      value={orderData.deliveryAddress || ''}
                      onChange={(e) => setOrderData(prev => ({ ...prev, deliveryAddress: e.target.value }))}
                      className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 min-h-[120px] text-gray-900 font-bold"
                      rows={4}
                      placeholder="Enter your complete delivery address or click 'Use Current Location' to auto-detect"
                      required
                    />
                    <p className="text-xs text-gray-600 mt-2">
                      💡 Click "Use Current Location" to automatically detect and fill your address
                    </p>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-bold text-gray-800 mb-2">Preferred Delivery Time</label>
                    <select
                      value={orderData.deliveryTime || ''}
                      onChange={(e) => setOrderData(prev => ({ ...prev, deliveryTime: e.target.value }))}
                      className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 h-14 text-gray-900 font-bold"
                    >
                      <option value="">Select delivery time</option>
                      <option value="asap">As soon as possible (30-45 mins)</option>
                      <option value="1hour">In 1 hour</option>
                      <option value="2hours">In 2 hours</option>
                      <option value="3hours">In 3 hours</option>
                    </select>
                  </div>
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="bg-gradient-to-r from-orange-100 to-red-100 rounded-2xl p-6 border border-orange-200">
                    <div className="flex items-start gap-4">
                      <MapPin className="w-6 h-6 text-orange-600 mt-1" />
                      <div>
                        <div className="font-bold text-lg text-gray-900">Taste of African Cuisine</div>
                        <div className="text-gray-800 font-bold mb-2">200 Hartford Turnpike, Vernon, CT</div>
                        <div className="text-sm text-gray-700 font-bold bg-white/50 rounded-lg px-3 py-2 inline-block">
                          Open: Tue-Sat 11:00 AM - 8:00 PM
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-bold text-gray-800 mb-2">Preferred Pickup Time</label>
                    <select
                      value={orderData.deliveryTime || ''}
                      onChange={(e) => setOrderData(prev => ({ ...prev, deliveryTime: e.target.value }))}
                      className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white/80 h-14 text-gray-900 font-bold"
                    >
                      <option value="">Select pickup time</option>
                      <option value="asap">As soon as possible (15-20 mins)</option>
                      <option value="30mins">In 30 minutes</option>
                      <option value="1hour">In 1 hour</option>
                      <option value="2hours">In 2 hours</option>
                    </select>
                  </div>
                </div>
              )}
            </div>

            {/* Payment Method */}
            <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                <CreditCard className="w-6 h-6 text-orange-500" />
                Payment Method
              </h3>
              
              {/* Promo Code Section */}
              <div className="mb-6">
                <PromoCode
                  orderTotal={subtotal + deliveryFee}
                  onPromoApplied={(promotion, discount) => setAppliedPromo({ promotion, discount })}
                  onPromoRemoved={() => setAppliedPromo(undefined)}
                  appliedPromo={appliedPromo}
                />
              </div>
              
              <div className="grid grid-cols-2 gap-4 mb-6">
                <button
                  type="button"
                  onClick={() => setOrderData(prev => ({ ...prev, paymentMethod: 'card' }))}
                  className={`p-4 rounded-2xl border-2 transition-all ${
                    orderData.paymentMethod === 'card'
                      ? 'border-orange-500 bg-gradient-to-br from-orange-50 to-red-50'
                      : 'border-orange-200 hover:border-orange-400 bg-white'
                  }`}
                >
                  <CreditCard className="w-6 h-6 mx-auto mb-2 text-orange-500" />
                  <div className="font-bold text-gray-900">Card Payment</div>
                  <div className="text-xs text-gray-600 mt-1">Credit, Debit, Amazon Pay, Klarna & more</div>
                </button>
                <button
                  type="button"
                  onClick={() => setOrderData(prev => ({ ...prev, paymentMethod: 'cash' }))}
                  className={`p-4 rounded-2xl border-2 transition-all ${
                    orderData.paymentMethod === 'cash'
                      ? 'border-orange-500 bg-gradient-to-br from-orange-50 to-red-50'
                      : 'border-orange-200 hover:border-orange-400 bg-white'
                  }`}
                >
                  <div className="w-6 h-6 mx-auto mb-2 text-orange-500 font-bold text-lg">$</div>
                  <div className="font-bold text-gray-900">Cash Payment</div>
                  <div className="text-xs text-gray-600 mt-1">Pay on {orderData.orderType === 'delivery' ? 'delivery' : 'pickup'}</div>
                </button>
              </div>

              {orderData.paymentMethod === 'card' ? (
                clientSecret ? (
                  <Elements stripe={stripePromise} options={{ clientSecret }}>
                    <StripePaymentForm 
                      onPaymentSuccess={handlePaymentSuccess}
                      total={total}
                      processing={processing}
                      orderData={orderData}
                    />
                  </Elements>
                ) : (
                  <div className="text-center py-4 text-gray-800 font-bold">Loading payment form...</div>
                )
              ) : (
                <button
                  onClick={handleCashOrder}
                  disabled={processing || !orderData.customerInfo.name || !orderData.customerInfo.phone || (orderData.orderType === 'delivery' && !orderData.deliveryAddress)}
                  className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-2xl font-bold text-lg hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
                >
                  {processing ? (
                    <>
                      <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-white"></div>
                      Processing...
                    </>
                  ) : (
                    <>
                      <Lock className="w-5 h-5" />
                      Place Order (Cash)
                    </>
                  )}
                </button>
              )}
            </div>
          </div>

          {/* Right Column - Order Summary */}
          <div className="lg:col-span-1">
            <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 sticky top-8">
              <h3 className="text-2xl font-bold text-gray-900 mb-8">Order Summary</h3>
              
              {/* Items */}
              <div className="space-y-4 mb-6">
                {cartItems.map((item) => (
                  <div key={item.id} className="flex gap-3">
                    <div className="relative w-12 h-12 rounded-lg overflow-hidden flex-shrink-0">
                      <img
                        src={item.imageUrl?.replace(/&amp;/g, '&') || '/assets/images/logo.png'}
                        alt={item.name}
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          e.currentTarget.src = '/assets/images/logo.png'
                        }}
                      />
                    </div>
                    <div className="flex-1">
                      <div className="font-medium text-gray-800">{item.name}</div>
                      <div className="text-sm text-gray-600">Qty: {item.quantity}</div>
                    </div>
                    <div className="font-bold text-gray-800">
                      ${(item.price * item.quantity).toFixed(2)}
                    </div>
                  </div>
                ))}
              </div>

              {/* Totals */}
              <div className="space-y-3 mb-8 border-t border-orange-200 pt-6">
                <div className="flex justify-between">
                  <span className="text-gray-800 font-bold">Subtotal</span>
                  <span className="font-bold text-gray-900">${subtotal.toFixed(2)}</span>
                </div>
                {orderData.orderType === 'delivery' && (
                  <div className="flex justify-between">
                    <span className="text-gray-800 font-bold">Delivery Fee</span>
                    <span className="font-bold text-gray-900">${deliveryFee.toFixed(2)}</span>
                  </div>
                )}
                {appliedPromo && (
                  <div className="flex justify-between">
                    <span className="text-gray-800 font-bold">Discount ({appliedPromo.promotion.code})</span>
                    <span className="font-bold text-green-600">-${appliedPromo.discount.toFixed(2)}</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="text-gray-800 font-bold">Tax (7.35%)</span>
                  <span className="font-bold text-gray-900">${tax.toFixed(2)}</span>
                </div>
                <div className="border-t border-orange-200 pt-3">
                  <div className="flex justify-between text-xl font-bold">
                    <span className="text-gray-900">Total</span>
                    <span className="text-orange-600">${total.toFixed(2)}</span>
                  </div>
                </div>
              </div>
              
              <p className="text-xs text-gray-500 text-center">
                Your payment information is secure and encrypted
              </p>
            </div>
          </div>
        </div>
      </div>
      <Toaster />
      </div>
    </div>
  )
}

export default function CheckoutPage() {
  return (
    <Elements stripe={stripePromise}>
      <CheckoutContent />
    </Elements>
  )
}