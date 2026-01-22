'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { Minus, Plus, Trash2, ArrowLeft, ShoppingBag, MapPin, Clock, Store, Navigation } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { getDownloadURL, ref } from 'firebase/storage'
import { storage } from '@/lib/firebase'

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
  const [calculatedDistance, setCalculatedDistance] = useState<number>(0)
  const { user } = useAuth()
  const router = useRouter()

  // Restaurant location - 200 Hartford Turnpike, Vernon, CT (matches mobile app)
  const restaurantLocation = { lat: 41.82457, lng: -72.4978 }
  const maxDeliveryDistance = 15 // miles

  const calculateDeliveryFee = (distance: number) => {
    const baseTierMaxDistance = 3.0
    const midTierMaxDistance = 10.0
    const baseFee = 3.99
    const midTierRatePerMile = 0.50
    const extendedTierBase = 7.49
    const extendedTierRatePerMile = 0.75

    if (distance <= baseTierMaxDistance) {
      return baseFee // Base tier: $3.99
    } else if (distance <= midTierMaxDistance) {
      return baseFee + (distance - baseTierMaxDistance) * midTierRatePerMile // Mid tier
    } else {
      return extendedTierBase + (distance - midTierMaxDistance) * extendedTierRatePerMile // Extended tier
    }
  }

  // Load image URLs for cart items
  useEffect(() => {
    const loadImageUrls = async () => {
      const urls: Record<string, string> = {}
      for (const item of cartItems) {
        if (item.imagePath && !urls[item.id]) {
          try {
            const url = await getDownloadURL(ref(storage, item.imagePath))
            urls[item.id] = url
          } catch (error) {
            console.error('Failed to load image for', item.name, error)
            urls[item.id] = '/assets/images/logo.png'
          }
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
    
    // Wait for Google Maps to load, then get user location
    const checkGoogleMaps = () => {
      if (window.google && window.google.maps) {
        getUserLocation()
      } else {
        setTimeout(checkGoogleMaps, 100)
      }
    }
    
    const getUserLocation = () => {
      if (navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
          async (position) => {
            const { latitude, longitude } = position.coords
            setUserLocation({ lat: latitude, lng: longitude })
            
            try {
              const distance = await calculateDistance(latitude, longitude)
              setCalculatedDistance(distance)
              
              if (distance > maxDeliveryDistance) {
                setDeliveryAvailable(false)
                setOrderType('pickup')
                setLocationError(`Delivery not available. You're ${distance.toFixed(1)} miles away (max: ${maxDeliveryDistance} miles)`)
              }
            } catch (error) {
              console.error('Distance calculation failed:', error)
              setLocationError('Unable to calculate delivery distance. Delivery may not be available.')
            }
          },
          (error) => {
            console.error('Geolocation error:', error)
            switch(error.code) {
              case error.PERMISSION_DENIED:
                setLocationError('Location access denied. Please enable location or use pickup.')
                break
              case error.POSITION_UNAVAILABLE:
                setLocationError('Location unavailable. Please use pickup or enter address manually.')
                break
              case error.TIMEOUT:
                setLocationError('Location request timed out. Please try again or use pickup.')
                break
              default:
                setLocationError('Location error. Delivery may not be available.')
                break
            }
          },
          {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 300000
          }
        )
      } else {
        setLocationError('Geolocation not supported. Delivery may not be available.')
      }
    }
    
    checkGoogleMaps()
    setLoading(false)
  }, [user, router])

  const calculateDistance = async (userLat: number, userLng: number) => {
    try {
      const service = new google.maps.DistanceMatrixService()
      
      return new Promise<number>((resolve, reject) => {
        service.getDistanceMatrix({
          origins: [{ lat: userLat, lng: userLng }],
          destinations: [{ lat: restaurantLocation.lat, lng: restaurantLocation.lng }],
          travelMode: google.maps.TravelMode.DRIVING,
          unitSystem: google.maps.UnitSystem.IMPERIAL,
          avoidHighways: false,
          avoidTolls: false
        }, (response, status) => {
          if (status === google.maps.DistanceMatrixStatus.OK && response) {
            const distance = response.rows[0].elements[0].distance
            if (distance) {
              // Convert meters to miles
              const miles = distance.value * 0.000621371
              resolve(miles)
            } else {
              reject(new Error('No distance data'))
            }
          } else {
            reject(new Error('Distance Matrix request failed'))
          }
        })
      })
    } catch (error) {
      console.error('Google Maps error:', error)
      throw error
    }
  }

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
  const deliveryFee = orderType === 'delivery' ? calculateDeliveryFee(calculatedDistance) : 0
  const tax = (subtotal + deliveryFee) * 0.0735
  const total = subtotal + deliveryFee + tax

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500"></div>
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
            <Link href="/" className="p-3 hover:bg-orange-100 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-orange-600" />
            </Link>
            <div>
              <h1 className="text-3xl font-bold bg-gradient-to-r from-orange-600 to-red-600 bg-clip-text text-transparent">
                Your Cart
              </h1>
              <p className="text-gray-700 font-medium">Review your order</p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8">
        {cartItems.length === 0 ? (
          <div className="text-center py-20">
            <div className="bg-white/60 backdrop-blur-sm rounded-3xl p-12 shadow-xl border border-orange-200">
              <ShoppingBag className="w-20 h-20 text-orange-400 mx-auto mb-6" />
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Your cart is empty</h2>
              <p className="text-gray-700 mb-8 text-lg font-medium">Add some delicious meals to get started!</p>
              <Link
                href="/#menu"
                className="inline-flex items-center gap-3 bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-4 rounded-2xl font-semibold hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
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
              <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
                <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center gap-3">
                  <Navigation className="w-6 h-6 text-orange-500" />
                  Order Type
                </h3>
                <div className="grid grid-cols-2 gap-6">
                  <button
                    onClick={() => deliveryAvailable && setOrderType('delivery')}
                    disabled={!deliveryAvailable}
                    className={`p-6 rounded-2xl border-3 transition-all transform hover:scale-105 ${
                      orderType === 'delivery'
                        ? 'border-orange-500 bg-gradient-to-br from-orange-50 to-red-50 shadow-lg'
                        : deliveryAvailable
                        ? 'border-gray-200 hover:border-orange-300 bg-white'
                        : 'border-gray-200 bg-gray-100 opacity-50 cursor-not-allowed'
                    }`}
                  >
                    <MapPin className={`w-8 h-8 mx-auto mb-3 ${
                      orderType === 'delivery' ? 'text-orange-500' : 'text-gray-400'
                    }`} />
                    <div className="font-bold text-lg mb-1 text-gray-900">Delivery</div>
                    <div className="text-sm text-gray-700 font-medium">
                      {deliveryAvailable ? `$${calculateDeliveryFee(calculatedDistance).toFixed(2)}` : 'Not Available'}
                    </div>
                    {locationError && !deliveryAvailable && (
                      <div className="text-xs text-red-500 mt-2">{locationError}</div>
                    )}
                  </button>
                  <button
                    onClick={() => setOrderType('pickup')}
                    className={`p-6 rounded-2xl border-3 transition-all transform hover:scale-105 ${
                      orderType === 'pickup'
                        ? 'border-orange-500 bg-gradient-to-br from-orange-50 to-red-50 shadow-lg'
                        : 'border-gray-200 hover:border-orange-300 bg-white'
                    }`}
                  >
                    <Store className={`w-8 h-8 mx-auto mb-3 ${
                      orderType === 'pickup' ? 'text-orange-500' : 'text-gray-400'
                    }`} />
                    <div className="font-bold text-lg mb-1 text-gray-900">Pickup</div>
                    <div className="text-sm text-gray-700 font-medium">Free</div>
                  </button>
                </div>
              </div>

              {/* Pickup Location */}
              {orderType === 'pickup' && (
                <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
                  <h3 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-3">
                    <Store className="w-6 h-6 text-orange-500" />
                    Pickup Location
                  </h3>
                  <div className="bg-gradient-to-r from-orange-100 to-red-100 rounded-2xl p-6 border border-orange-200">
                    <div className="flex items-start gap-4">
                      <MapPin className="w-6 h-6 text-orange-600 mt-1" />
                      <div>
                        <div className="font-bold text-lg text-gray-800">Taste of African Cuisine</div>
                        <div className="text-gray-700 mb-2">200 Hartford Turnpike, Vernon, CT</div>
                        <div className="text-sm text-gray-600 bg-white/50 rounded-lg px-3 py-2 inline-block">
                          Open: Tue-Sat 11:00 AM - 8:00 PM
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Cart Items */}
              <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
                <div className="flex items-center justify-between mb-8">
                  <h2 className="text-2xl font-bold text-gray-900">Your Items ({cartItems.length})</h2>
                  <button
                    onClick={clearCart}
                    className="text-red-500 hover:text-red-700 font-medium transition-colors bg-red-50 hover:bg-red-100 px-4 py-2 rounded-xl"
                  >
                    Clear All
                  </button>
                </div>

                <div className="space-y-6">
                  {cartItems.map((item) => (
                    <div key={item.id} className="bg-white/80 rounded-2xl p-6 shadow-lg border border-orange-100 hover:shadow-xl transition-all">
                      <div className="flex gap-6">
                        <div className="relative w-20 h-20 rounded-2xl overflow-hidden flex-shrink-0 shadow-md">
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
                          <h3 className="font-bold text-xl text-gray-900 mb-2">{item.name}</h3>
                          <p className="text-orange-600 font-bold mb-3">{item.category}</p>
                          <p className="text-2xl font-bold text-orange-600">${item.price.toFixed(2)}</p>
                        </div>

                        <div className="flex flex-col items-end gap-4">
                          <button
                            onClick={() => removeItem(item.id)}
                            className="p-2 text-red-500 hover:bg-red-50 rounded-xl transition-colors"
                          >
                            <Trash2 className="w-5 h-5" />
                          </button>
                          
                          <div className="flex items-center gap-3 bg-orange-100 rounded-2xl p-1">
                            <button
                              onClick={() => updateQuantity(item.id, item.quantity - 1)}
                              className="p-3 hover:bg-orange-200 rounded-xl transition-colors"
                            >
                              <Minus className="w-4 h-4 text-orange-600" />
                            </button>
                            <span className="px-4 py-2 font-bold text-lg min-w-[3rem] text-center text-gray-900">
                              {item.quantity}
                            </span>
                            <button
                              onClick={() => updateQuantity(item.id, item.quantity + 1)}
                              className="p-3 hover:bg-orange-200 rounded-xl transition-colors"
                            >
                              <Plus className="w-4 h-4 text-orange-600" />
                            </button>
                          </div>
                        </div>
                      </div>
                      
                      <div className="mt-6 pt-4 border-t border-orange-200 flex justify-between items-center">
                        <span className="text-gray-700 font-bold">Item Total:</span>
                        <span className="font-bold text-xl text-gray-900">
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
              <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 sticky top-8">
                <h3 className="text-2xl font-bold text-gray-900 mb-8">Order Summary</h3>
                
                <div className="space-y-4 mb-8">
                  <div className="flex justify-between items-center py-2">
                    <span className="text-gray-800 font-bold">Subtotal</span>
                    <span className="font-bold text-lg text-gray-900">${subtotal.toFixed(2)}</span>
                  </div>
                  {orderType === 'delivery' && (
                    <div className="flex justify-between items-center py-2">
                      <span className="text-gray-800 font-bold">
                        Delivery Fee {calculatedDistance > 0 && `(${calculatedDistance.toFixed(1)} mi)`}
                      </span>
                      <span className="font-bold text-lg text-gray-900">${deliveryFee.toFixed(2)}</span>
                    </div>
                  )}
                  <div className="flex justify-between items-center py-2">
                    <span className="text-gray-800 font-bold">Tax (7.35%)</span>
                    <span className="font-bold text-lg text-gray-900">${tax.toFixed(2)}</span>
                  </div>
                  <div className="border-t-2 border-orange-200 pt-4">
                    <div className="flex justify-between items-center">
                      <span className="text-xl font-bold text-gray-900">Total</span>
                      <span className="text-2xl font-bold text-orange-600">${total.toFixed(2)}</span>
                    </div>
                  </div>
                </div>

                <button 
                  onClick={() => {
                    localStorage.setItem('orderType', orderType)
                    localStorage.setItem('calculatedDistance', calculatedDistance.toString())
                    if (orderType === 'delivery' && userLocation) {
                      localStorage.setItem('deliveryAddress', 'Auto-detected location')
                    }
                    router.push('/checkout')
                  }}
                  className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-2xl font-bold text-lg hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg mb-4"
                >
                  Proceed to Checkout
                </button>
                
                <Link
                  href="/#menu"
                  className="w-full block text-center border-2 border-orange-500 text-orange-600 py-4 rounded-2xl font-bold hover:bg-orange-50 transition-colors"
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