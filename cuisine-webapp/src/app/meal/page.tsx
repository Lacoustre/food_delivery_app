'use client'

import { useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { ArrowLeft, Plus, Minus } from 'lucide-react'
import { useAuth } from '@/lib/AuthContext'
import { mealExtras } from '@/lib/mealExtras'

interface Extra {
  name: string
  price: number
  required: boolean
  group?: string
}

interface Meal {
  id: string
  name: string
  price: number
  imageUrl: string
  category: string
  description: string
  available: boolean
}

export default function MealDetailPage() {
  const [meal, setMeal] = useState<Meal | null>(null)
  const [selectedExtras, setSelectedExtras] = useState<Record<string, Extra>>({})
  const [instructions, setInstructions] = useState('')
  const [quantity, setQuantity] = useState(1)
  const [loading, setLoading] = useState(true)
  const [addingToCart, setAddingToCart] = useState(false)
  const [toast, setToast] = useState<{message: string, type: 'success' | 'error'} | null>(null)
  
  const { user } = useAuth()
  const router = useRouter()
  const searchParams = useSearchParams()
  
  // Function to decode HTML entities in URLs
  const decodeImageUrl = (url: string) => {
    if (!url) return '/assets/images/logo.png'
    // Decode HTML entities and fix any URL issues
    let decoded = url
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
    
    // Test if this is a Firebase Storage URL and try to access it
    if (decoded.includes('firebasestorage.googleapis.com')) {
      console.log('Testing Firebase Storage URL access...')
      fetch(decoded, { method: 'HEAD' })
        .then(response => {
          console.log('Firebase Storage URL status:', response.status)
          if (!response.ok) {
            console.log('Firebase Storage URL is not accessible:', response.statusText)
          }
        })
        .catch(error => {
          console.log('Firebase Storage URL fetch error:', error)
        })
    }
    
    console.log('Meal detail - Original URL:', url)
    console.log('Meal detail - Decoded URL:', decoded)
    return decoded
  }
  
  useEffect(() => {
    const mealData = searchParams.get('meal')
    if (mealData) {
      try {
        const parsedMeal = JSON.parse(decodeURIComponent(mealData))
        setMeal(parsedMeal)
      } catch (error) {
        console.error('Error parsing meal data:', error)
        router.push('/')
      }
    } else {
      router.push('/')
    }
    setLoading(false)
  }, [searchParams, router])

  if (loading || !meal) {
    return (
      <div className="min-h-screen bg-amber-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500"></div>
      </div>
    )
  }

  const extras = mealExtras[meal.name] || []
  const groupedExtras = extras.reduce((acc, extra) => {
    const group = extra.group || 'optional'
    if (!acc[group]) acc[group] = []
    acc[group].push(extra)
    return acc
  }, {} as Record<string, Extra[]>)

  const extrasTotal = Object.values(selectedExtras).reduce((sum, extra) => sum + extra.price, 0)
  const totalPrice = (meal.price + extrasTotal) * quantity

  const validateRequiredExtras = () => {
    const requiredGroups = extras
      .filter(e => e.required && e.group)
      .map(e => e.group!)
      .filter((group, index, arr) => arr.indexOf(group) === index)

    if (requiredGroups.includes('Protein')) {
      const selectedProteins = Object.values(selectedExtras).filter(e => e.group === 'Protein')
      if (selectedProteins.length === 0) return false
    }

    return true
  }

  const handleExtraToggle = (extra: Extra) => {
    setSelectedExtras(prev => {
      const newExtras = { ...prev }
      
      if (extra.required && extra.group) {
        if (extra.group === 'Protein') {
          // Allow multiple protein selections
          if (newExtras[extra.name]) {
            delete newExtras[extra.name]
          } else {
            newExtras[extra.name] = extra
          }
        } else {
          // Single selection for other required groups
          Object.keys(newExtras).forEach(key => {
            if (newExtras[key].group === extra.group) {
              delete newExtras[key]
            }
          })
          if (!newExtras[extra.name]) {
            newExtras[extra.name] = extra
          }
        }
      } else {
        // Optional extras
        if (newExtras[extra.name]) {
          delete newExtras[extra.name]
        } else {
          newExtras[extra.name] = extra
        }
      }
      
      return newExtras
    })
  }

  const addToCart = async () => {
    if (!user) {
      router.push('/login')
      return
    }

    if (!validateRequiredExtras()) {
      setToast({message: 'Please select required extras first', type: 'error'})
      setTimeout(() => setToast(null), 3000)
      return
    }

    setAddingToCart(true)
    
    try {
      // Simulate loading for better UX
      await new Promise(resolve => setTimeout(resolve, 800))
      
      const cartItem = {
        id: meal.id,
        name: meal.name,
        price: meal.price,
        quantity,
        imageUrl: meal.imageUrl,
        category: meal.category,
        extras: Object.values(selectedExtras),
        instructions,
        extrasTotal
      }

      // Get existing cart
      const existingCart = JSON.parse(localStorage.getItem('cart') || '[]')
      
      // Check if same item with same extras exists
      const existingIndex = existingCart.findIndex((item: any) => 
        item.id === cartItem.id && 
        JSON.stringify(item.extras) === JSON.stringify(cartItem.extras) &&
        item.instructions === cartItem.instructions
      )

      if (existingIndex !== -1) {
        existingCart[existingIndex].quantity += quantity
      } else {
        existingCart.push(cartItem)
      }

      localStorage.setItem('cart', JSON.stringify(existingCart))
      
      setToast({message: `${meal.name} added to cart!`, type: 'success'})
      setTimeout(() => {
        setToast(null)
        router.push('/cart')
      }, 1500)
      
    } catch (error) {
      setToast({message: 'Failed to add to cart. Please try again.', type: 'error'})
      setTimeout(() => setToast(null), 3000)
    } finally {
      setAddingToCart(false)
    }
  }

  return (
    <div className="min-h-screen bg-amber-50 relative">
      {/* Logo Background Pattern */}
      <div className="absolute inset-0 opacity-5 pointer-events-none" style={{
        backgroundImage: `url('/assets/images/logo.png')`,
        backgroundSize: '150px 150px',
        backgroundRepeat: 'repeat',
        backgroundPosition: 'center'
      }}></div>
      
      {/* Header */}
      <div className="bg-white shadow-sm border-b relative z-10">
        <div className="max-w-4xl mx-auto px-4 py-4">
          <div className="flex items-center h-16">
            <Link href="/" className="p-2 hover:bg-gray-100 rounded-full transition-colors">
              <ArrowLeft className="w-5 h-5 text-black" />
            </Link>
            <div className="flex items-center space-x-3 ml-3">
              <Image
                src="/assets/images/logo.png"
                alt="Logo"
                width={48}
                height={48}
                className="object-contain"
                unoptimized
              />
              <div>
                <h1 className="text-lg font-bold italic text-gray-900">
                  Taste of African Cuisine
                </h1>
                <p className="text-xs italic text-orange-600">
                  Authentic Ghanaian Food
                </p>
              </div>
            </div>
            <h2 className="text-xl font-semibold text-black ml-auto">{meal.name}</h2>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 py-8 relative z-10">
        <div className="grid lg:grid-cols-2 gap-8">
          {/* Image */}
          <div className="relative aspect-square rounded-xl overflow-hidden shadow-lg">
            <img
              src={decodeImageUrl(meal.imageUrl)}
              alt={meal.name}
              className="w-full h-full object-cover"
              onError={(e) => {
                // Try the local asset as fallback
                const mealNameMap: Record<string, string> = {
                  'jollof rice': 'jollof',
                  'waakye': 'waakye',
                  'fried rice': 'fried_rice',
                  'fried yam': 'fried_yam'
                }
                const localName = mealNameMap[meal.name.toLowerCase()] || meal.name.toLowerCase().replace(/\s+/g, '_')
                const localImagePath = `/assets/images/${localName}.png`
                e.currentTarget.src = localImagePath
                
                // If local also fails, use logo
                e.currentTarget.onerror = () => {
                  e.currentTarget.src = '/assets/images/logo.png'
                }
              }}
            />
          </div>

          {/* Details */}
          <div className="space-y-6 bg-white p-6 rounded-xl shadow-lg">
            <div>
              <h2 className="text-3xl font-bold text-black mb-2">{meal.name}</h2>
              <p className="text-black mb-4">{meal.description}</p>
              <p className="text-2xl font-bold text-orange-600">${meal.price.toFixed(2)}</p>
            </div>

            {/* Extras */}
            {Object.entries(groupedExtras).map(([group, groupExtras]) => (
              <div key={group} className="space-y-3">
                <h3 className="text-lg font-semibold text-black">
                  {group === 'optional' ? 'Optional Extras' : 
                   group === 'Protein' ? `${group} (Required - Choose at least 1)` :
                   `${group} (Required - Choose 1)`}
                </h3>
                <div className="flex flex-wrap gap-2">
                  {groupExtras.map((extra) => (
                    <button
                      key={extra.name}
                      onClick={() => handleExtraToggle(extra)}
                      className={`px-4 py-2 rounded-full border transition-colors ${
                        selectedExtras[extra.name]
                          ? 'bg-orange-500 text-white border-orange-500'
                          : 'bg-white text-black border-gray-300 hover:border-orange-500'
                      }`}
                    >
                      {extra.price > 0 ? `${extra.name} +$${extra.price.toFixed(2)}` : extra.name}
                    </button>
                  ))}
                </div>
              </div>
            ))}

            {/* Instructions */}
            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-black">Special Instructions</h3>
              <textarea
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                placeholder="e.g. No onions, sauce on the side"
                className="w-full p-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500 outline-none text-black"
                rows={3}
              />
            </div>

            {/* Quantity */}
            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-black">Quantity</h3>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setQuantity(Math.max(1, quantity - 1))}
                  className="p-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  <Minus className="w-4 h-4 text-black" />
                </button>
                <span className="text-xl font-semibold px-4 text-black">{quantity}</span>
                <button
                  onClick={() => setQuantity(quantity + 1)}
                  className="p-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
                >
                  <Plus className="w-4 h-4 text-black" />
                </button>
              </div>
            </div>

            {/* Total & Add to Cart */}
            <div className="space-y-4 pt-6 border-t">
              <div className="text-2xl font-bold text-black">
                Total: ${totalPrice.toFixed(2)}
              </div>
              <button
                onClick={addToCart}
                disabled={!meal.available || addingToCart}
                className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-xl font-semibold hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
              >
                {addingToCart ? (
                  <>
                    <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-white"></div>
                    Adding to Cart...
                  </>
                ) : (
                  !meal.available ? 'Unavailable' : 'Add to Cart'
                )}
              </button>
            </div>
          </div>
        </div>
      </div>
      
      {/* Toast Notification */}
      {toast && (
        <div className={`fixed top-20 right-4 z-50 px-6 py-4 rounded-lg shadow-lg transform transition-all duration-300 ${
          toast.type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'
        }`}>
          <div className="flex items-center gap-2">
            <span className="text-lg">{toast.type === 'success' ? '✅' : '❌'}</span>
            <span className="font-medium">{toast.message}</span>
          </div>
        </div>
      )}
    </div>
  )
}