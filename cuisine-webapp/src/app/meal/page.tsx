'use client'

import { useState, useEffect, Suspense } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Image from 'next/image'
import Link from 'next/link'
import { ArrowLeft, Plus, Minus } from 'lucide-react'
import { fetchModifiers, modifiersFor, lineKey, keyOf, type Modifier } from '@/lib/modifiers'
import { ModifierPicker } from '@/components/ModifierPicker'
import { mealImageSrc } from '@/lib/mealImage'
import { DishPhoto } from '@/components/DishPhoto'

interface Meal {
  id: string
  name: string
  price: number
  imageUrl: string
  category: string
  description: string
  available: boolean
  baseSlug?: string
  isVegetarian?: boolean
}

interface CartItem {
  id: string
  lineKey?: string
  quantity: number
}

function MealDetailContent() {
  const [meal, setMeal] = useState<Meal | null>(null)
  // Every add-on and request offered for this dish, and which are ticked.
  const [offered, setOffered] = useState<Modifier[]>([])
  const [chosenIds, setChosenIds] = useState<string[]>([])
  const [instructions, setInstructions] = useState('')
  const [quantity, setQuantity] = useState(1)
  const [loading, setLoading] = useState(true)
  const [addingToCart, setAddingToCart] = useState(false)
  const [toast, setToast] = useState<{message: string, type: 'success' | 'error'} | null>(null)
  
  const router = useRouter()
  const searchParams = useSearchParams()
  
  // Function to get image URL from database with local fallback
  const getImageUrl = (meal: Meal) => {
    if (!meal.imageUrl) {
      return '/assets/images/logo.png'
    }
    // Remote URL. Supabase photos go through our own /menu-images/ route,
    // because Supabase marks them noindex and Google Images skipped them.
    if (meal.imageUrl.startsWith('http')) {
      return mealImageSrc(meal.imageUrl)
    }
    // If it's a local asset path, use it
    if (meal.imageUrl.startsWith('/assets/')) {
      return meal.imageUrl
    }
    // If it's just a filename, assume it's a local asset
    return `/assets/images/${meal.imageUrl}`
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

  useEffect(() => {
    if (!meal) return
    fetchModifiers().then(all =>
      setOffered(modifiersFor(all, { baseSlug: meal.baseSlug ?? meal.id, isVegetarian: !!meal.isVegetarian }))
    )
  }, [meal])

  if (loading || !meal) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold"></div>
      </div>
    )
  }

  const chosen = offered.filter(m => chosenIds.includes(m.id))
  const extrasTotal = chosen.reduce((sum, m) => sum + m.price, 0)
  const unitPrice = Math.round((meal.price + extrasTotal) * 100) / 100
  const totalPrice = unitPrice * quantity

  const addToCart = async () => {
    // No sign-in needed to fill a cart — checkout asks for it.
    setAddingToCart(true)
    
    try {
      // Simulate loading for better UX
      await new Promise(resolve => setTimeout(resolve, 800))
      
      // The note used to be saved here and then dropped at checkout, so the
      // kitchen never saw it. It now travels with the line to the order.
      const note = instructions.trim().slice(0, 200)
      const key = lineKey(meal.id, chosen.map(m => m.id), note)
      // price is per unit with the add-ons included, so the cart and checkout
      // total it correctly; the server prices it again from the database.
      const cartItem = {
        id: meal.id,
        name: meal.name,
        price: unitPrice,
        basePrice: meal.price,
        quantity,
        imageUrl: getImageUrl(meal), // Use proper URL handling
        category: meal.category,
        modifiers: chosen.map(({ id, name, price }) => ({ id, name, price })),
        notes: note || undefined,
        lineKey: key
      }

      // Get existing cart
      const existingCart = JSON.parse(localStorage.getItem('cart') || '[]')

      // The same dish with the same choices and note is one line.
      const existingIndex = existingCart.findIndex((item: CartItem) => keyOf(item) === key)

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
    <div className="min-h-screen bg-sand-100 relative">
      {/* Logo Background Pattern */}
      
      {/* Header */}
      <div className="bg-white shadow-sm border-b relative z-10">
        <div className="page-shell px-4 py-3">
          {/* One fixed-height row used to hold the arrow, the logo, the
              restaurant name and the dish name, with nothing allowed to shrink
              or wrap — so on a phone they ran into each other. min-w-0 lets the
              text truncate instead of pushing its neighbour over. */}
          <div className="flex items-center gap-3 min-h-16">
            <Link
              href="/"
              className="shrink-0 p-2 -ml-2 hover:bg-sand-100 rounded-full transition-colors"
              aria-label="Back to the menu"
            >
              <ArrowLeft className="w-5 h-5 text-black" />
            </Link>

            <div className="flex items-center gap-3 min-w-0">
              <Image
                src="/assets/images/logo.png"
                alt="Logo"
                width={48}
                height={48}
                className="object-contain shrink-0 w-10 h-10 sm:w-12 sm:h-12"
                unoptimized
              />
              <div className="min-w-0">
                <h1 className="text-base sm:text-lg font-bold italic text-ink truncate">
                  Taste of African Cuisine
                </h1>
                <p className="text-xs italic text-gold-600 truncate">
                  Authentic African Cooking
                </p>
              </div>
            </div>

            {/* The dish name is the first thing in the body below, so on a
                phone it is repetition that costs the header its layout. */}
            <h2 className="hidden lg:block text-xl font-semibold text-black ml-auto truncate max-w-[40%]">
              {meal.name}
            </h2>
          </div>
        </div>
      </div>

      <div className="page-shell max-w-5xl px-4 py-6 sm:py-8 relative z-10">
        <div className="grid lg:grid-cols-2 gap-6 lg:gap-8">
          {/* Image */}
          <div className="relative aspect-[4/3] max-h-[420px] rounded-card overflow-hidden border border-sand-200">
            <DishPhoto
              src={getImageUrl(meal)}
              alt={`${meal.name} at Taste of African Cuisine`}
              onError={(e) => { (e.currentTarget as HTMLImageElement).src = '/assets/images/logo.png' }}
            />
          </div>

          {/* Details */}
          <div className="space-y-6 bg-white p-4 sm:p-6 rounded-xl shadow-card">
            <div>
              <h2 className="font-display text-2xl sm:text-3xl text-black mb-2">{meal.name}</h2>
              <p className="text-black mb-4">{meal.description}</p>
              <p className="font-display text-2xl text-gold-600">${meal.price.toFixed(2)}</p>
            </div>

            <ModifierPicker offered={offered} selected={chosenIds} onChange={setChosenIds} />

            {/* Instructions */}
            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-black">Special Instructions</h3>
              <textarea
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                placeholder="e.g. No onions, sauce on the side"
                className="w-full p-3 text-base border border-sand-200 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-gold outline-none text-black"
                rows={3}
              />
            </div>

            {/* Quantity */}
            <div className="space-y-3">
              <h3 className="text-lg font-semibold text-black">Quantity</h3>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setQuantity(Math.max(1, quantity - 1))}
                  className="p-3 bg-sand-100 hover:bg-sand-200 rounded-lg transition-colors"
                  aria-label="One fewer"
                >
                  <Minus className="w-5 h-5 text-black" />
                </button>
                <span className="text-xl font-semibold px-4 text-black">{quantity}</span>
                <button
                  onClick={() => setQuantity(quantity + 1)}
                  className="p-3 bg-sand-100 hover:bg-sand-200 rounded-lg transition-colors"
                  aria-label="One more"
                >
                  <Plus className="w-5 h-5 text-black" />
                </button>
              </div>
            </div>

            {/* Total & Add to Cart */}
            <div className="space-y-4 pt-6 border-t">
              <div className="font-display text-2xl text-black">
                Total: ${totalPrice.toFixed(2)}
              </div>
              <button
                onClick={addToCart}
                disabled={!meal.available || addingToCart}
                className="w-full bg-gold text-white py-4 rounded-xl font-semibold hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
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
        <div className={`fixed top-20 right-4 z-50 px-6 py-4 rounded-lg shadow-card transform transition-all duration-300 ${
          toast.type === 'success' ? 'bg-kente text-white' : 'bg-clay text-white'
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

export default function MealDetailPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-sand-50 flex items-center justify-center">
          <div className="w-8 h-8 border-2 border-sand-300 border-t-gold rounded-full animate-spin" />
        </div>
      }
    >
      <MealDetailContent />
    </Suspense>
  )
}
