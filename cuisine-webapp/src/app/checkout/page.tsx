'use client'

import { useState, useEffect, useRef } from 'react'
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
import { getAuthHeaders } from '@/lib/authHeaders'
import { computeOrderTotals } from '@/lib/pricing'
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

const StripePaymentForm = ({ onPaymentSuccess, total, processing }: {
  onPaymentSuccess: (paymentIntentId: string) => void
  total: number
  processing: boolean
}) => {
  const stripe = useStripe()
  const elements = useElements()
  const [error, setError] = useState<string | null>(null)
  const [isProcessing, setIsProcessing] = useState(false)

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()

    if (!stripe || !elements || isProcessing || processing) return

    setIsProcessing(true)
    setError(null)

    try {
      const { error: submitError } = await elements.submit()
      if (submitError) {
        setError(submitError.message || 'Payment validation failed')
        setIsProcessing(false)
        return
      }

      // `elements` already carries the clientSecret it was initialized with
      // via the parent <Elements options={{ clientSecret }}> — no need to
      // create or pass a second one here.
      const { error, paymentIntent } = await stripe.confirmPayment({
        elements,
        redirect: 'if_required'
      })

      if (error) {
        setError(error.message || 'Payment failed')
      } else if (paymentIntent?.status === 'succeeded') {
        // The id is the only handle on this charge. Without it stored against
        // the order, nothing can find the payment later to refund it.
        onPaymentSuccess(paymentIntent.id)
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
      <div className="p-6 border-2 border-gold-300 rounded-card bg-white/80">
        <PaymentElement />
      </div>
      {error && (
        <div className="text-clay text-sm bg-clay-50 p-3 rounded-lg border border-clay-50">
          {error}
        </div>
      )}
      <button
        type="submit"
        disabled={!stripe || isProcessing || processing}
        className="w-full bg-gold text-white py-4 rounded-card font-bold text-lg hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
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
  const [cartItems, setCartItems] = useState<CartItem[]>([])
  const [loading, setLoading] = useState(true)
  const [processing, setProcessing] = useState(false)
  // Held in a ref so updating it cannot retrigger the effect that sets it.
  const intentIdRef = useRef<string | null>(null)
  const [clientSecret, setClientSecret] = useState<string | null>(null)
  const [paymentError, setPaymentError] = useState<string | null>(null)
  const [locationLoading, setLocationLoading] = useState(false)
  const [paymentSuccess, setPaymentSuccess] = useState(false)
  const [appliedPromo, setAppliedPromo] = useState<{ promotion: Promotion, discount: number } | undefined>()
  const [orderData, setOrderData] = useState<OrderData>({
    orderType: 'delivery',
    customerInfo: { name: '', email: '', phone: '' },
    paymentMethod: 'card'
  })
  
  const { user, userProfile, loading: authLoading } = useAuth()
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
    // AuthContext is still restoring the session on the first render, so user
    // is null then whether or not the customer is signed in. Acting on it
    // early sent someone with a full cart back to the login page on a refresh
    // — at the last step before paying.
    //
    // The old guard also read a localStorage key called "authToken", which
    // nothing writes: supabase-js stores its session under
    // sb-<project>-auth-token. That condition was always true, so the redirect
    // rested entirely on the race.
    if (authLoading) return

    if (!user && typeof window !== 'undefined') {
      const hasCart = localStorage.getItem('cart')
      if (hasCart) {
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
      // Uber couriers do not collect cash, so delivery is card-only. This is
      // the only place orderType is decided — it arrives from the cart page.
      paymentMethod: savedOrderType === 'delivery' ? 'card' : prev.paymentMethod,
      deliveryAddress: savedDeliveryAddress,
      customerInfo: {
        name: userProfile?.name || '',
        email: user.email || '',
        phone: userProfile?.phone || ''
      }
    }))
    
    // Auto-detect location if delivery and no saved address
    if (savedOrderType === 'delivery' && !savedDeliveryAddress) {
      getCurrentLocation()
    }
    
    setLoading(false)
  }, [user, userProfile, router])


  const subtotal = cartItems.reduce((sum, item) => sum + (item.price * item.quantity), 0)
  const promoDiscount = appliedPromo?.discount || 0

  // Delivery is priced by Uber, so the fee has to be fetched once there is an
  // address to quote against. Display only — create-payment-intent re-quotes
  // before charging.
  const [quotedDeliveryFee, setQuotedDeliveryFee] = useState<number>(0)
  const [quoteError, setQuoteError] = useState<string | null>(null)
  const [quoting, setQuoting] = useState(false)

  const quoteAddress =
    orderData.orderType === 'delivery' ? orderData.deliveryAddress : undefined

  useEffect(() => {
    if (!quoteAddress) {
      setQuotedDeliveryFee(0)
      setQuoteError(null)
      return
    }
    let cancelled = false
    setQuoting(true)
    setQuoteError(null)
    fetch('/api/quote-delivery', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ deliveryAddress: quoteAddress, subtotal })
    })
      .then(async (res) => {
        const data = await res.json()
        if (cancelled) return
        if (!res.ok) {
          setQuotedDeliveryFee(0)
          setQuoteError(data.error || 'Delivery is not available to that address.')
          return
        }
        setQuotedDeliveryFee(data.fee ?? 0)
      })
      .catch(() => {
        if (!cancelled) setQuoteError('Unable to price delivery right now.')
      })
      .finally(() => {
        if (!cancelled) setQuoting(false)
      })
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [quoteAddress])

  const { deliveryFee, tax, total } = computeOrderTotals({
    subtotal,
    orderType: orderData.orderType,
    deliveryFee: quotedDeliveryFee,
    promoDiscount,
  })

  // Cash pickup orders never touch Stripe, so they must not reserve a payment
  // for it. Without this check a cash order still created a PaymentIntent —
  // pickup defaults to card, so one was raised before the customer had even
  // chosen how to pay, and it sat in Stripe as Incomplete forever along with a
  // pending_orders row the webhook could later have turned into a duplicate.
  const readyToPay =
    orderData.paymentMethod === 'card' &&
    total > 0 && (orderData.orderType !== 'delivery' || (!!quoteAddress && !quoteError && !quoting))

  useEffect(() => {
    if (!readyToPay) {
      // Switching to cash drops any intent already prepared, so a stale
      // client secret cannot be confirmed by a card form reappearing later.
      setClientSecret(null)
      return
    }
    let cancelled = false
    setPaymentError(null)

    createPaymentIntent({
      items: cartItems.map(item => ({ id: item.id, quantity: item.quantity })),
      orderType: orderData.orderType,
      deliveryAddress: orderData.deliveryAddress,
      promoCode: appliedPromo?.promotion.code,
      // This effect re-runs whenever the total or address moves — a delivery
      // quote arriving is enough. Handing back the intent we already have
      // reprices it; without this, one checkout left nine abandoned payment
      // intents in Stripe and a pending_orders row behind each.
      existingIntentId: intentIdRef.current ?? undefined,
      // Recorded against the intent so the webhook can build the order if this
      // browser never reaches create-order.
      customerInfo: orderData.customerInfo
    })
      .then(({ clientSecret, paymentIntentId }) => {
        if (cancelled) return
        if (paymentIntentId) intentIdRef.current = paymentIntentId
        setClientSecret(clientSecret)
      })
      .catch((error: Error) => {
        if (cancelled) return
        // Show the server's reason — "the restaurant is closed", "we could not
        // quote delivery to that address" — rather than leaving the spinner up.
        setClientSecret(null)
        setPaymentError(error.message)
      })

    return () => { cancelled = true }
    // Re-runs on address changes too: the fee can move without the total
    // changing, and a previously refused address may now be quotable.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [total, readyToPay, orderData.deliveryAddress, orderData.orderType, orderData.paymentMethod])

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
      
      // No BigDataCloud fallback: its reverse geocode returns only locality,
      // region and postcode, so it produced addresses like
      // "Vernon, Connecticut 06066" with no street. Uber rejects those, which
      // is where the 422 at checkout came from — better to ask than to fill
      // the field with something that cannot be delivered to.
      if (!address) {
        throw new Error('Could not determine your street address')
      }
      
      setOrderData(prev => ({ ...prev, deliveryAddress: address }))
      localStorage.setItem('deliveryAddress', address)
    } catch (error) {
      console.error('Location error:', error)
      let errorMessage = 'Could not fill in your address. Please type it below. '
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

  // Re-validates items/prices/promo server-side and creates the order in
  // Supabase, returning the authoritative data. The Firestore order (and
  // the confirmation email) are built from THIS response, not from raw
  // client cart state — otherwise a tampered cart could still get a
  // different order fulfilled than what was actually paid for.
  const createValidatedOrder = async (paymentIntentId?: string) => {
    const response = await fetch('/api/create-order', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
      body: JSON.stringify({
        items: cartItems.map(item => ({ id: item.id, quantity: item.quantity })),
        orderType: orderData.orderType,
        promoCode: appliedPromo?.promotion.code,
        customerInfo: orderData.customerInfo,
        deliveryAddress: orderData.deliveryAddress,
        deliveryTime: orderData.deliveryTime,
        paymentMethod: orderData.paymentMethod,
        paymentIntentId
      })
    })
    const validated = await response.json()
    if (!response.ok) {
      throw new Error(validated.error || 'Failed to create order')
    }
    return validated as {
      orderId: string
      orderNumber: string
      items: { id: string; name: string; price: number; quantity: number }[]
      subtotal: number
      deliveryFee: number
      tax: number
      total: number
    }
  }

  const handlePaymentSuccess = async (paymentIntentId: string) => {
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

      // Re-validates items/prices/promo server-side; the order that gets
      // fulfilled and emailed is built from this response, not raw cart state.
      const validated = await createValidatedOrder(paymentIntentId)

      const orderPayload = {
        orderNumber: validated.orderNumber,
        userId: user?.uid || '',
        customerInfo: orderData.customerInfo,
        items: validated.items,
        orderType: orderData.orderType,
        deliveryAddress: orderData.deliveryAddress,
        deliveryTime: orderData.deliveryTime,
        subtotal: validated.subtotal,
        deliveryFee: validated.deliveryFee,
        tax: validated.tax,
        total: validated.total,
        paymentMethod: orderData.paymentMethod,
        status: 'confirmed' as const
      }

      await orderService.createOrder(orderPayload)

      // Send confirmation email
      try {
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
          body: JSON.stringify({
            type: 'confirmation',
            orderData: {
              customerEmail: orderData.customerInfo.email,
              customerName: orderData.customerInfo.name,
              orderNumber: orderPayload.orderNumber,
              orderType: orderData.orderType,
              items: validated.items.map(item => ({
                name: item.name,
                quantity: item.quantity,
                price: item.price
              })),
              subtotal: validated.subtotal,
              deliveryFee: validated.deliveryFee,
              tax: validated.tax,
              total: validated.total,
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

      // Re-validates items/prices/promo server-side; the order that gets
      // fulfilled and emailed is built from this response, not raw cart state.
      const validated = await createValidatedOrder()

      const orderPayload = {
        orderNumber: validated.orderNumber,
        userId: user?.uid || '',
        customerInfo: orderData.customerInfo,
        items: validated.items,
        orderType: orderData.orderType,
        deliveryAddress: orderData.deliveryAddress,
        deliveryTime: orderData.deliveryTime,
        subtotal: validated.subtotal,
        deliveryFee: validated.deliveryFee,
        tax: validated.tax,
        total: validated.total,
        paymentMethod: orderData.paymentMethod,
        status: 'confirmed' as const
      }

      await orderService.createOrder(orderPayload)

      // Send confirmation email
      try {
        await fetch('/api/send-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
          body: JSON.stringify({
            type: 'confirmation',
            orderData: {
              customerEmail: orderData.customerInfo.email,
              customerName: orderData.customerInfo.name,
              orderNumber: orderPayload.orderNumber,
              orderType: orderData.orderType,
              items: validated.items.map(item => ({
                name: item.name,
                quantity: item.quantity,
                price: item.price
              })),
              subtotal: validated.subtotal,
              deliveryFee: validated.deliveryFee,
              tax: validated.tax,
              total: validated.total,
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
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold"></div>
      </div>
    )
  }

  // Show success state if payment completed
  if (paymentSuccess) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 text-center max-w-md">
          <div className="w-16 h-16 bg-kente rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h2 className="font-display text-2xl text-ink mb-2">Payment Successful!</h2>
          <p className="text-sand-700 mb-4">Your order has been confirmed. Redirecting...</p>
          <div className="animate-spin rounded-full h-6 w-6 border-t-2 border-gold mx-auto"></div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-sand-100 relative overflow-hidden">
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
      <div className="bg-white/80 backdrop-blur-md shadow-card border-b border-gold-50">
        <div className="page-shell px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/cart" className="p-3 hover:bg-gold-50 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-gold-600" />
            </Link>
            <div>
              <h1 className="font-display text-3xl bg-gold-600 bg-clip-text text-transparent">
                Checkout
              </h1>
              <p className="text-sand-700 font-bold">Complete your order</p>
            </div>
          </div>
        </div>
      </div>

      <div className="page-shell px-4 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Left Column - Forms */}
          <div className="lg:col-span-2 space-y-6">
            {/* Customer Information */}
            <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
              <h3 className="font-display text-2xl text-ink mb-6 flex items-center gap-3">
                <User className="w-6 h-6 text-gold" />
                Customer Information
              </h3>
              <div className="grid md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-bold text-ink-soft mb-2">Full Name *</label>
                  <input
                    type="text"
                    value={orderData.customerInfo.name}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, name: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 h-14 text-ink font-bold"
                    placeholder="Enter your full name"
                    required
                  />
                </div>
                <div>
                  <label className="block text-sm font-bold text-ink-soft mb-2">Phone Number *</label>
                  <input
                    type="tel"
                    value={orderData.customerInfo.phone}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, phone: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 h-14 text-ink font-bold"
                    placeholder="(555) 123-4567"
                    required
                  />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-bold text-ink-soft mb-2">Email Address *</label>
                  <input
                    type="email"
                    value={orderData.customerInfo.email}
                    onChange={(e) => setOrderData(prev => ({
                      ...prev,
                      customerInfo: { ...prev.customerInfo, email: e.target.value }
                    }))}
                    className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 h-14 text-ink font-bold"
                    placeholder="your@email.com"
                    required
                  />
                </div>
              </div>
            </div>

            {/* Delivery Information */}
            <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
              <h3 className="font-display text-2xl text-ink mb-6 flex items-center gap-3">
                <MapPin className="w-6 h-6 text-gold" />
                {orderData.orderType === 'delivery' ? 'Delivery' : 'Pickup'} Information
              </h3>
              
              {orderData.orderType === 'delivery' ? (
                <div className="space-y-4">
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <label className="block text-sm font-bold text-ink-soft">Delivery Address *</label>
                      <button
                        type="button"
                        onClick={getCurrentLocation}
                        disabled={locationLoading}
                        className="flex items-center gap-2 px-3 py-1 text-sm bg-gold text-white rounded-lg hover:bg-gold-600 transition-colors disabled:opacity-50"
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
                      className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 min-h-[120px] text-ink font-bold"
                      rows={4}
                      placeholder="Enter your complete delivery address or click 'Use Current Location' to auto-detect"
                      required
                    />
                    <p className="text-xs text-sand-700 mt-2">
                      💡 Click "Use Current Location" to automatically detect and fill your address
                    </p>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-bold text-ink-soft mb-2">Preferred Delivery Time</label>
                    <select
                      value={orderData.deliveryTime || ''}
                      onChange={(e) => setOrderData(prev => ({ ...prev, deliveryTime: e.target.value }))}
                      className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 h-14 text-ink font-bold"
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
                  <div className="bg-sand-200 rounded-card p-6 border border-gold-300">
                    <div className="flex items-start gap-4">
                      <MapPin className="w-6 h-6 text-gold-600 mt-1" />
                      <div>
                        <div className="font-bold text-lg text-ink">Taste of African Cuisine</div>
                        <div className="text-ink-soft font-bold mb-2">200 Hartford Turnpike, Vernon, CT</div>
                        <div className="text-sm text-sand-700 font-bold bg-white/50 rounded-lg px-3 py-2 inline-block">
                          Open: Tue-Sat 11:00 AM - 9:00 PM (Fri to 8:00 PM)
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-bold text-ink-soft mb-2">Preferred Pickup Time</label>
                    <select
                      value={orderData.deliveryTime || ''}
                      onChange={(e) => setOrderData(prev => ({ ...prev, deliveryTime: e.target.value }))}
                      className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white/80 h-14 text-ink font-bold"
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
            <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
              <h3 className="font-display text-2xl text-ink mb-6 flex items-center gap-3">
                <CreditCard className="w-6 h-6 text-gold" />
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
              
              <div className={`grid ${orderData.orderType === 'delivery' ? 'grid-cols-1' : 'grid-cols-2'} gap-4 mb-6`}>
                <button
                  type="button"
                  onClick={() => setOrderData(prev => ({ ...prev, paymentMethod: 'card' }))}
                  className={`p-4 rounded-card border-2 transition-all ${
                    orderData.paymentMethod === 'card'
                      ? 'border-gold bg-sand-100'
                      : 'border-gold-300 hover:border-gold-300 bg-white'
                  }`}
                >
                  <CreditCard className="w-6 h-6 mx-auto mb-2 text-gold" />
                  <div className="font-bold text-ink">Card Payment</div>
                  <div className="text-xs text-sand-700 mt-1">Credit, Debit, Amazon Pay, Klarna & more</div>
                </button>
                {/* Cash is pickup-only: an Uber courier cannot take money at
                    the door, so a cash delivery would be handed over unpaid. */}
                {orderData.orderType === 'pickup' && (
                  <button
                    type="button"
                    onClick={() => setOrderData(prev => ({ ...prev, paymentMethod: 'cash' }))}
                    className={`p-4 rounded-card border-2 transition-all ${
                      orderData.paymentMethod === 'cash'
                        ? 'border-gold bg-sand-100'
                        : 'border-gold-300 hover:border-gold-300 bg-white'
                    }`}
                  >
                    <div className="w-6 h-6 mx-auto mb-2 text-gold font-bold text-lg">$</div>
                    <div className="font-bold text-ink">Cash Payment</div>
                    <div className="text-xs text-sand-700 mt-1">Pay at the counter</div>
                  </button>
                )}
              </div>

              {orderData.paymentMethod === 'card' ? (
                clientSecret ? (
                  <Elements stripe={stripePromise} options={{ clientSecret }}>
                    <StripePaymentForm
                      onPaymentSuccess={handlePaymentSuccess}
                      total={total}
                      processing={processing}
                    />
                  </Elements>
                ) : paymentError ? (
                  <div className="rounded-control border border-clay-50 bg-clay-50 p-4">
                    <p className="text-clay font-semibold text-sm mb-1">Payment unavailable</p>
                    <p className="text-sand-700 text-sm">{paymentError}</p>
                    <p className="text-sand-500 text-xs mt-2">
                      {orderData.orderType === 'pickup'
                        ? 'You can still place this order and pay cash at the counter.'
                        : 'Please try again, or switch to pickup to pay cash.'}
                    </p>
                  </div>
                ) : !readyToPay ? (
                  <div className="rounded-control border border-sand-200 bg-sand-100 p-4 text-sand-700 text-sm">
                    {/* Say which of the four reasons it is. Falling through to
                        "add something to your order" whenever the quote failed
                        told the customer their cart was empty when it wasn't. */}
                    {cartItems.length === 0
                      ? 'Your order is empty. Add a dish to continue.'
                      : orderData.orderType === 'delivery' && !quoteAddress
                        ? 'Enter your delivery address to continue.'
                        : quoting
                          ? 'Checking delivery for that address…'
                          : quoteError
                            ? quoteError
                            : 'Add something to your order to continue.'}
                  </div>
                ) : (
                  <div className="text-center py-4 text-sand-700 text-sm">Loading payment form…</div>
                )
              ) : (
                <button
                  onClick={handleCashOrder}
                  disabled={processing || !orderData.customerInfo.name || !orderData.customerInfo.phone || (orderData.orderType === 'delivery' && !orderData.deliveryAddress)}
                  className="w-full bg-gold text-white py-4 rounded-card font-bold text-lg hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
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
            <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 sticky top-8">
              <h3 className="font-display text-2xl text-ink mb-8">Order Summary</h3>
              
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
                      <div className="font-medium text-ink-soft">{item.name}</div>
                      <div className="text-sm text-sand-700">Qty: {item.quantity}</div>
                    </div>
                    <div className="font-bold text-ink-soft">
                      ${(item.price * item.quantity).toFixed(2)}
                    </div>
                  </div>
                ))}
              </div>

              {/* Totals */}
              <div className="space-y-3 mb-8 border-t border-gold-300 pt-6">
                <div className="flex justify-between">
                  <span className="text-ink-soft font-bold">Subtotal</span>
                  <span className="font-bold text-ink">${subtotal.toFixed(2)}</span>
                </div>
                {orderData.orderType === 'delivery' && (
                  <div className="flex justify-between">
                    <span className="text-ink-soft font-bold">Delivery Fee</span>
                    <span className="font-bold text-ink">${deliveryFee.toFixed(2)}</span>
                  </div>
                )}
                {appliedPromo && (
                  <div className="flex justify-between">
                    <span className="text-ink-soft font-bold">Discount ({appliedPromo.promotion.code})</span>
                    <span className="font-bold text-kente">-${appliedPromo.discount.toFixed(2)}</span>
                  </div>
                )}
                <div className="flex justify-between">
                  <span className="text-ink-soft font-bold">Tax (7.35%)</span>
                  <span className="font-bold text-ink">${tax.toFixed(2)}</span>
                </div>
                <div className="border-t border-gold-300 pt-3">
                  <div className="flex justify-between text-xl font-bold">
                    <span className="text-ink">Total</span>
                    <span className="text-gold-600">${total.toFixed(2)}</span>
                  </div>
                </div>
              </div>
              
              <p className="text-xs text-sand-500 text-center">
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