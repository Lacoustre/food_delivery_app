'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { Minus, Plus, Trash2, ArrowLeft, ShoppingBag, MapPin, Clock, Store, Navigation } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { DEFAULT_TAX_RATE } from '@/lib/pricing'
import { supabase } from '@/lib/supabase'

interface CartItem {
  id: string
  name: string
  price: number
  quantity: number
  imageUrl?: string
  imagePath?: string
  category: string
  description?: string
}

export default function CartPage() {
  const [cartItems, setCartItems] = useState<CartItem[]>([])
  const [imageUrls, setImageUrls] = useState<Record<string, string>>({})
  const [loading, setLoading] = useState(true)
  const [orderType, setOrderType] = useState<'delivery' | 'pickup'>('delivery')
  const [userLocation, setUserLocation] = useState<{lat: number, lng: number} | null>(null)
  const [locationError, setLocationError] = useState('')
  const [deliveryAvailable, setDeliveryAvailable] = useState(true)
  const { user } = useAuth()
  const router = useRouter()

  // Restaurant location - 200 Hartford Turnpike, Vernon, CT (matches mobile app)
  const restaurantLocation = { lat: 41.82457, lng: -72.4978 }
  // Coarse straight-line pre-filter only — the Uber quote at checkout is the
  // authority on whether an address is deliverable. Uber stops quoting past
  // ~10 road miles, which is the default when no radius is configured.
  const [maxDeliveryDistance, setMaxDeliveryDistance] = useState<number>(10)

  useEffect(() => {
    supabase
      .from('settings')
      .select('value')
      .eq('key', 'restaurant')
      .maybeSingle()
      .then(({ data }: { data: { value?: { deliveryRadius?: number } } | null }) => {
        const r = data?.value?.deliveryRadius
        if (typeof r === 'number' && r > 0) setMaxDeliveryDistance(r)
      })
  }, [])


  // Load image URLs for cart items
  useEffect(() => {
    const loadImageUrls = async () => {
      // Legacy Firebase Storage imagePath entries can't resolve anymore —
      // meals carry full image_url strings now, so just fall back to the logo.
      const urls: Record<string, string> = {}
      for (const item of cartItems) {
        if (item.imagePath && !urls[item.id]) {
          urls[item.id] = '/assets/images/logo.png'
        }
      }
      setImageUrls(prev => ({ ...prev, ...urls }))
    }
    
    if (cartItems.length > 0) {
      loadImageUrls()
    }
  }, [cartItems])

  useEffect(() => {
    if (!user) {
      router.push('/login')
      return
    }
    
    const savedCart = localStorage.getItem('cart')
    if (savedCart) {
      setCartItems(JSON.parse(savedCart))
    }
    
    // The cart used to ask for the browser's location and run a Google
    // Distance Matrix lookup to decide whether delivery was available. That
    // needed billing enabled on the Maps project (it isn't, so every call
    // failed), and it is now redundant: Uber decides deliverability when the
    // address is quoted at checkout, and answers for the real address rather
    // than wherever the phone happens to be.
    setLoading(false)
  }, [user, router])


  const updateQuantity = (id: string, newQuantity: number) => {
    if (newQuantity <= 0) {
      removeItem(id)
      return
    }
    
    const updatedCart = cartItems.map(item =>
      item.id === id ? { ...item, quantity: newQuantity } : item
    )
    setCartItems(updatedCart)
    localStorage.setItem('cart', JSON.stringify(updatedCart))
  }

  const removeItem = (id: string) => {
    const updatedCart = cartItems.filter(item => item.id !== id)
    setCartItems(updatedCart)
    localStorage.setItem('cart', JSON.stringify(updatedCart))
  }

  const clearCart = () => {
    setCartItems([])
    localStorage.removeItem('cart')
  }

  const subtotal = cartItems.reduce((sum, item) => sum + (item.price * item.quantity), 0)
  // Delivery is quoted by Uber against a real address, which the cart doesn't
  // have yet — so the fee lands at checkout. Tax is on the subtotal only.
  const tax = subtotal * DEFAULT_TAX_RATE
  const total = subtotal + tax

  if (loading) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold"></div>
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
            <Link href="/" className="p-3 hover:bg-gold-50 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-gold-600" />
            </Link>
            <div>
              <h1 className="font-display text-3xl bg-gold-600 bg-clip-text text-transparent">
                Your Cart
              </h1>
              <p className="text-sand-700 font-medium">Review your order</p>
            </div>
          </div>
        </div>
      </div>

      <div className="page-shell px-4 py-8">
        {cartItems.length === 0 ? (
          <div className="text-center py-20">
            <div className="bg-white/60 backdrop-blur-sm rounded-card p-12 shadow-card border border-gold-300">
              <ShoppingBag className="w-20 h-20 text-gold-300 mx-auto mb-6" />
              <h2 className="font-display text-3xl text-ink mb-4">Your cart is empty</h2>
              <p className="text-sand-700 mb-8 text-lg font-medium">Add some delicious meals to get started!</p>
              <Link
                href="/#menu"
                className="inline-flex items-center gap-3 bg-gold text-white px-8 py-4 rounded-card font-semibold hover:bg-gold-600 transition-all shadow-card"
              >
                <ShoppingBag className="w-6 h-6" />
                Browse Menu
              </Link>
            </div>
          </div>
        ) : (
          <div className="grid lg:grid-cols-3 gap-8">
            {/* Left Column */}
            <div className="lg:col-span-2 space-y-6">
              {/* Order Type Selection */}
              <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
                <h3 className="font-display text-2xl text-ink mb-6 flex items-center gap-3">
                  <Navigation className="w-6 h-6 text-gold" />
                  Order Type
                </h3>
                <div className="grid grid-cols-2 gap-6">
                  <button
                    onClick={() => deliveryAvailable && setOrderType('delivery')}
                    disabled={!deliveryAvailable}
                    className={`p-6 rounded-card border-3 transition-all  ${
                      orderType === 'delivery'
                        ? 'border-gold bg-sand-100 shadow-card'
                        : deliveryAvailable
                        ? 'border-sand-200 hover:border-gold-300 bg-white'
                        : 'border-sand-200 bg-sand-100 opacity-50 cursor-not-allowed'
                    }`}
                  >
                    <MapPin className={`w-8 h-8 mx-auto mb-3 ${
                      orderType === 'delivery' ? 'text-gold' : 'text-sand-500'
                    }`} />
                    <div className="font-bold text-lg mb-1 text-ink">Delivery</div>
                    <div className="text-sm text-sand-700 font-medium">
                      {deliveryAvailable ? 'Quoted at checkout' : 'Not Available'}
                    </div>
                    {locationError && !deliveryAvailable && (
                      <div className="text-xs text-clay mt-2">{locationError}</div>
                    )}
                  </button>
                  <button
                    onClick={() => setOrderType('pickup')}
                    className={`p-6 rounded-card border-3 transition-all  ${
                      orderType === 'pickup'
                        ? 'border-gold bg-sand-100 shadow-card'
                        : 'border-sand-200 hover:border-gold-300 bg-white'
                    }`}
                  >
                    <Store className={`w-8 h-8 mx-auto mb-3 ${
                      orderType === 'pickup' ? 'text-gold' : 'text-sand-500'
                    }`} />
                    <div className="font-bold text-lg mb-1 text-ink">Pickup</div>
                    <div className="text-sm text-sand-700 font-medium">Free</div>
                  </button>
                </div>
              </div>

              {/* Pickup Location */}
              {orderType === 'pickup' && (
                <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
                  <h3 className="font-display text-2xl text-ink-soft mb-6 flex items-center gap-3">
                    <Store className="w-6 h-6 text-gold" />
                    Pickup Location
                  </h3>
                  <div className="bg-sand-200 rounded-card p-6 border border-gold-300">
                    <div className="flex items-start gap-4">
                      <MapPin className="w-6 h-6 text-gold-600 mt-1" />
                      <div>
                        <div className="font-bold text-lg text-ink-soft">Taste of African Cuisine</div>
                        <div className="text-sand-700 mb-2">200 Hartford Turnpike, Vernon, CT</div>
                        <div className="text-sm text-sand-700 bg-white/50 rounded-lg px-3 py-2 inline-block">
                          Open: Tue-Sat 11:00 AM - 9:00 PM (Fri to 8:00 PM)
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Cart Items */}
              <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
                <div className="flex items-center justify-between mb-8">
                  <h2 className="font-display text-2xl text-ink">Your Items ({cartItems.length})</h2>
                  <button
                    onClick={clearCart}
                    className="text-clay hover:text-clay font-medium transition-colors bg-clay-50 hover:bg-clay-50 px-4 py-2 rounded-xl"
                  >
                    Clear All
                  </button>
                </div>

                <div className="space-y-6">
                  {cartItems.map((item) => (
                    <div key={item.id} className="bg-white/80 rounded-card p-6 shadow-card border border-gold-50 hover:shadow-card transition-all">
                      <div className="flex gap-6">
                        <div className="relative w-20 h-20 rounded-card overflow-hidden flex-shrink-0 shadow-card">
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
                          <h3 className="font-bold text-xl text-ink mb-2">{item.name}</h3>
                          <p className="text-gold-600 font-bold mb-3">{item.category}</p>
                          <p className="font-display text-2xl text-gold-600">${item.price.toFixed(2)}</p>
                        </div>

                        <div className="flex flex-col items-end gap-4">
                          <button
                            onClick={() => removeItem(item.id)}
                            className="p-2 text-clay hover:bg-clay-50 rounded-xl transition-colors"
                          >
                            <Trash2 className="w-5 h-5" />
                          </button>
                          
                          <div className="flex items-center gap-3 bg-gold-50 rounded-card p-1">
                            <button
                              onClick={() => updateQuantity(item.id, item.quantity - 1)}
                              className="p-3 hover:bg-gold-300 rounded-xl transition-colors"
                            >
                              <Minus className="w-4 h-4 text-gold-600" />
                            </button>
                            <span className="px-4 py-2 font-bold text-lg min-w-[3rem] text-center text-ink">
                              {item.quantity}
                            </span>
                            <button
                              onClick={() => updateQuantity(item.id, item.quantity + 1)}
                              className="p-3 hover:bg-gold-300 rounded-xl transition-colors"
                            >
                              <Plus className="w-4 h-4 text-gold-600" />
                            </button>
                          </div>
                        </div>
                      </div>
                      
                      <div className="mt-6 pt-4 border-t border-gold-300 flex justify-between items-center">
                        <span className="text-sand-700 font-bold">Item Total:</span>
                        <span className="font-bold text-xl text-ink">
                          ${(item.price * item.quantity).toFixed(2)}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            {/* Order Summary */}
            <div className="lg:col-span-1">
              <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 sticky top-8">
                <h3 className="font-display text-2xl text-ink mb-8">Order Summary</h3>
                
                <div className="space-y-4 mb-8">
                  <div className="flex justify-between items-center py-2">
                    <span className="text-ink-soft font-bold">Subtotal</span>
                    <span className="font-bold text-lg text-ink">${subtotal.toFixed(2)}</span>
                  </div>
                  {orderType === 'delivery' && (
                    <div className="flex justify-between items-center py-2">
                      <span className="text-ink-soft font-bold">Delivery Fee</span>
                      <span className="font-medium text-sm text-sand-700">Quoted at checkout</span>
                    </div>
                  )}
                  <div className="flex justify-between items-center py-2">
                    <span className="text-ink-soft font-bold">Tax (7.35%)</span>
                    <span className="font-bold text-lg text-ink">${tax.toFixed(2)}</span>
                  </div>
                  <div className="border-t-2 border-gold-300 pt-4">
                    <div className="flex justify-between items-center">
                      <span className="text-xl font-bold text-ink">Total</span>
                      <span className="font-display text-2xl text-gold-600">${total.toFixed(2)}</span>
                    </div>
                  </div>
                </div>

                <button 
                  onClick={() => {
                    localStorage.setItem('orderType', orderType)
                    router.push('/checkout')
                  }}
                  className="w-full bg-gold text-white py-4 rounded-card font-bold text-lg hover:bg-gold-600 transition-all shadow-card mb-4"
                >
                  Proceed to Checkout
                </button>
                
                <Link
                  href="/#menu"
                  className="w-full block text-center border-2 border-gold text-gold-600 py-4 rounded-card font-bold hover:bg-gold-50 transition-colors"
                >
                  Continue Shopping
                </Link>
              </div>
            </div>
          </div>
        )}
      </div>
      </div>
    </div>
  )
}