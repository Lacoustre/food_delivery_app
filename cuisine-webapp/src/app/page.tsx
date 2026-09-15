'use client'

import { useState, useEffect, useRef } from 'react'
import { ShoppingCart, Heart, Plus, Clock, Phone, MapPin, Mail, Search, Menu, X, ChevronLeft, ChevronRight, User, LogOut, Instagram, Facebook, Star, Check } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { googleReviewsService, relativeDate, GOOGLE_REVIEWS_URL, type GoogleReview } from '@/lib/googleReviewsService'
import { reviewsService, type ApprovedReview } from '@/lib/reviewsService'
import { mealsService, type Meal } from '@/lib/mealsService'
import { restaurantService, type RestaurantStatus } from '@/lib/restaurantService'
import { orderService } from '@/lib/orderService'
import { favoritesService } from '@/lib/favoritesService'
import { useAuth } from '@/lib/AuthContext'
import OrderNotifications from '@/components/OrderNotifications'
import { mealImageSrc } from '@/lib/mealImage'
import { DishPhoto } from '@/components/DishPhoto'
import { ModifierPicker } from '@/components/ModifierPicker'
import { fetchModifiers, modifiersFor, lineKey, keyOf, type Modifier, type ChosenModifier } from '@/lib/modifiers'


interface CartItem extends Meal {
  lineKey?: string
  basePrice?: number
  modifiers?: ChosenModifier[]
  notes?: string
  quantity: number
}

export default function AfricanCuisineWebsite() {
  const [cart, setCart] = useState<CartItem[]>([])
  const [favorites, setFavorites] = useState(new Set<string>())
  const [meals, setMeals] = useState<Meal[]>([])
  const [loading, setLoading] = useState(true)
  const [scrolled, setScrolled] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  // Which variant is selected per menu card, keyed by baseSlug.
  const [selectedVariant, setSelectedVariant] = useState<Record<string, string>>({})
  // Sections the customer has opened past the preview. Everything starts
  // collapsed to its first few dishes; see PREVIEW below.
  const [expandedSections, setExpandedSections] = useState<Record<string, boolean>>({})
  const [vegOnly, setVegOnly] = useState(false)
  const [year, setYear] = useState(2025)
  useEffect(() => setYear(new Date().getFullYear()), [])
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [currentSlide, setCurrentSlide] = useState(0)
  const [currentReview, setCurrentReview] = useState(0)
  const [addingToCart, setAddingToCart] = useState<string | null>(null)

  // Phone menu. Every dish used to get a full-width, 610px card, so the menu
  // ran to roughly fifty screens on an iPhone and Drinks started 37 screens
  // down. Phones now get two compact cards per row; choosing and adding
  // happens in a sheet that slides up, and a sticky bar jumps between
  // sections.
  const [sheetSlug, setSheetSlug] = useState<string | null>(null)
  // Where to go once an overlay has closed. The page is frozen while the
  // drawer is open, so a link inside it can't move the page itself — the
  // unlock would put you straight back where you were.
  const pendingScrollId = useRef<string | null>(null)
  // Where a swipe on the reviews started. The arrows are hidden on phones,
  // where they sat on top of the review text, so swiping replaces them.
  const reviewTouchX = useRef<number | null>(null)
  const [sheetAdded, setSheetAdded] = useState(false)
  // True while the sheet plays its drop-away animation, just before it unmounts.
  const [sheetClosing, setSheetClosing] = useState(false)
  // Add-ons and requests for every dish, and those ticked in the open sheet.
  const [modifiers, setModifiers] = useState<Modifier[]>([])
  const [sheetMods, setSheetMods] = useState<string[]>([])
  // The exact dish a sheet was opened on, when it came from outside the menu
  // grid — a favourite. Without it the sheet matched by dish family, so
  // tapping "Waakye with Fried Chicken" with the vegetarian filter on offered
  // vegetarian Waakye instead of the dish that was tapped.
  const [sheetPinned, setSheetPinned] = useState<string | null>(null)
  const [activeSection, setActiveSection] = useState<string | null>(null)
  // The fixed header grows when the closed banner shows, so the sticky bar
  // is placed from its measured height rather than a guess.
  const headerRef = useRef<HTMLElement>(null)
  const [headerH, setHeaderH] = useState(64)
  const [navigating, setNavigating] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  // Starts unknown rather than open. Defaulting to open meant the page said
  // "Open now" before it had checked, and went on saying it if the check
  // failed — telling customers the restaurant was open while it was shut.
  const [restaurantStatus, setRestaurantStatus] = useState<RestaurantStatus | null>(null)
  const statusKnown = restaurantStatus !== null
  const isOpen = restaurantStatus?.isOpen ?? false
  
  const { user, userProfile, signOut } = useAuth()

  // Auto-listen for order status changes to send emails
  useEffect(() => {
    if (user) {
      const unsubscribe = orderService.listenForStatusUpdates(user.uid)
      return () => unsubscribe()
    }
  }, [user])

  // Favourites live in Supabase, behind owner-only RLS.
  useEffect(() => {
    if (user) {
      const unsubscribe = favoritesService.onFavoritesChange(user.uid, setFavorites)
      return () => unsubscribe()
    }
  }, [user])

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

  const heroImages = [
    { src: '/assets/images/jollof.png', title: 'Jollof Rice', subtitle: 'Aromatic & Flavorful' },
    { src: '/assets/images/waakye.png', title: 'Waakye', subtitle: 'Traditional & Authentic' },
    { src: '/assets/images/banku_tilapia.avif', title: 'Banku & Tilapia', subtitle: 'Fresh & Delicious' },
    { src: '/assets/images/fufu_and_light_soup.avif', title: 'Fufu & Light Soup', subtitle: 'Comfort & Tradition' }
  ]

  // Shown only while google_reviews is empty — i.e. until Google approves API
  // access and the sync runs. Two of these could not be verified against the
  // Business Profile and should come out regardless.
  const fallbackReviews = [
    {
      name: "Shanay Hall",
      review: "Beyond the food, the service was outstanding. The owner made me feel like family. The portions were generous, the prices were fair, and the customer service was outstanding. Highly recommend - this place deserves ALL the stars!",
      dish: "Customer Service",
      date: "4 months ago",
      rating: 5
    },
    {
      name: "Godfred K.Y Junior", 
      review: "I had waakye and it was delicious. I couldn't eat all because the food was a lot. She has a very nice interpersonal skills. Definitely buying from her again.",
      dish: "Waakye",
      date: "4 months ago",
      rating: 5
    },
    {
      name: "Loretta Prempeh",
      review: "AMAZING FOOD! Legitimately the best African restaurant Connecticut! Doesn't matter what I order, I end up liking it. My family and I have been eating here ever since it opened. The chefs are always so friendly and kind.",
      dish: "Various Dishes",
      date: "2 years ago",
      rating: 5
    },
    {
      name: "Zuley",
      review: "I just tried the fufu and egusi from taste of African cuisine, and I was absolutely delighted! The fufu was perfectly smooth and stretchy, just the way it should be, and the egusi soup was rich, flavorful, and full of that authentic taste that warms your heart.",
      dish: "Fufu & Egusi",
      date: "5 months ago",
      rating: 5
    }
  ]

  // Reviews customers left on their orders here, once the restaurant has
  // approved them, then Google's when the sync has run (the hardcoded list
  // until then). The carousel reads `reviews`, so no change is needed below.
  const [googleReviews, setGoogleReviews] = useState<GoogleReview[]>([])
  const [siteReviews, setSiteReviews] = useState<ApprovedReview[]>([])

  useEffect(() => {
    googleReviewsService.getReviews().then(setGoogleReviews).catch(() => {})
    reviewsService.getApprovedReviews().then(setSiteReviews).catch(() => {})
  }, [])

  const reviews = [
    ...siteReviews.map(r => {
      const dishes = r.dishes ? r.dishes.split(', ') : []
      return {
        name: r.reviewer,
        review: r.comment,
        dish: dishes.length ? dishes[0] + (dishes.length > 1 ? ` +${dishes.length - 1}` : '') : 'Order review',
        date: relativeDate(r.createdAt),
        rating: r.rating
      }
    }),
    ...(googleReviews.length
      ? googleReviews.map(r => ({
          name: r.reviewerName,
          review: r.comment,
          dish: 'Google review',
          date: relativeDate(r.createdAt),
          rating: r.rating
        }))
      : fallbackReviews)
  ]


  useEffect(() => {
    // Load cart from localStorage on component mount
    const savedCart = localStorage.getItem('cart')
    if (savedCart) {
      setCart(JSON.parse(savedCart))
    }
  }, [])

  useEffect(() => { fetchModifiers().then(setModifiers) }, [])

  useEffect(() => {
    try {
      const unsubscribe = restaurantService.onStatusChange((status) => {
        console.log('Restaurant status updated:', status)
        setRestaurantStatus(status)
      })
      return () => unsubscribe()
    } catch (error) {
      console.log('Restaurant service not available, using default status')
      // Keep default status if service fails
    }
  }, [])

  useEffect(() => {
    try {
      const unsubscribe = mealsService.onMealsChange((fetchedMeals) => {
        console.log('Meals updated:', fetchedMeals.length)
        const mealsWithAvailability = fetchedMeals
          .filter(meal => meal.active !== false)
          .map(meal => ({
            ...meal,
            available: meal.active !== false && meal.available !== false
          }))
        setMeals(mealsWithAvailability)
        setLoading(false)
      })
      return () => unsubscribe()
    } catch (error) {
      console.log('Meals service not available')
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 50)
    window.addEventListener('scroll', handleScroll)
    return () => window.removeEventListener('scroll', handleScroll)
  }, [])

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentSlide((prev) => (prev + 1) % heroImages.length)
    }, 8000)
    return () => clearInterval(interval)
  }, [heroImages.length])

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentReview((prev) => (prev + 1) % reviews.length)
    }, 5000)
    return () => clearInterval(interval)
  }, [reviews.length])

  const addToCart = async (meal: Meal, chosen: Modifier[] = []) => {
    if (statusKnown && !isOpen) {
      alert('Restaurant is currently closed. Please check back later.')
      return
    }
    
    if (!user) {
      window.location.href = '/login'
      return
    }
    
    setAddingToCart(meal.id)
    
    // Simulate loading for better UX
    await new Promise(resolve => setTimeout(resolve, 500))
    
    setCart(prev => {
      // A dish with add-ons is its own line; the same dish plain is another.
      const key = lineKey(meal.id, chosen.map(m => m.id))
      const existing = prev.find(item => keyOf(item) === key)
      let updatedCart
      if (existing) {
        updatedCart = prev.map(item => 
          keyOf(item) === key ? { ...item, quantity: item.quantity + 1 } : item
        )
      } else {
        const extras = chosen.map(({ id, name, price }) => ({ id, name, price }))
        // price is per unit with the add-ons in, so the cart and checkout
        // total it correctly; the server prices it again from the database.
        const price = Math.round((meal.price + extras.reduce((s, m) => s + m.price, 0)) * 100) / 100
        updatedCart = [...prev, { ...meal, price, basePrice: meal.price, modifiers: extras, lineKey: key, quantity: 1 }]
      }
      
      // Save to localStorage
      localStorage.setItem('cart', JSON.stringify(updatedCart))
      return updatedCart
    })
    
    setAddingToCart(null)
  }

  const toggleFavorite = async (id: string) => {
    if (!user) {
      alert('Please sign in to save favorites')
      return
    }
    
    try {
      if (favorites.has(id)) {
        await favoritesService.removeFavorite(user.uid, id)
      } else {
        await favoritesService.addFavorite(user.uid, id)
      }
    } catch (error) {
      console.error('Error updating favorites:', error)
    }
  }

  useEffect(() => {
    const el = headerRef.current
    if (!el) return
    const update = () => setHeaderH(el.offsetHeight)
    update()
    const ro = new ResizeObserver(update)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  // Escape closes the dish sheet the way every other sheet on a phone behaves.
  useEffect(() => {
    if (!sheetSlug) return
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') closeSheet() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [sheetSlug])

  // Freezes the page while the drawer or the dish sheet is open. The drawer
  // had no lock at all, so the page scrolled behind it. The sheet used
  // overflow:hidden on the body, which iOS Safari ignores for touch
  // scrolling — so the body is pinned in place instead, and the scroll
  // position put back exactly when it is released.
  const pageLocked = mobileMenuOpen || sheetSlug !== null
  useEffect(() => {
    if (!pageLocked) return
    const y = window.scrollY
    const b = document.body.style
    const prev = { position: b.position, top: b.top, width: b.width, overflow: b.overflow }
    b.position = 'fixed'
    b.top = `-${y}px`
    b.width = '100%'
    b.overflow = 'hidden'
    return () => {
      Object.assign(b, prev)
      window.scrollTo({ top: y, behavior: 'instant' as ScrollBehavior })
      const target = pendingScrollId.current
      pendingScrollId.current = null
      if (target) document.getElementById(target)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [pageLocked])

  // Highlights the section you are scrolling through in the sticky bar.
  useEffect(() => {
    let frame = 0
    const onScroll = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        const edge = headerH + 72
        let current: string | null = null
        document.querySelectorAll<HTMLElement>('[data-menu-section]').forEach(el => {
          if (el.getBoundingClientRect().top <= edge) current = el.dataset.menuSection ?? null
        })
        setActiveSection(current)
      })
    }
    window.addEventListener('scroll', onScroll, { passive: true })
    onScroll()
    return () => {
      cancelAnimationFrame(frame)
      window.removeEventListener('scroll', onScroll)
    }
  }, [headerH])

  const isPhone = () =>
    typeof window !== 'undefined' && window.matchMedia('(max-width: 639px)').matches

  // Close the drawer, then — once the page is unlocked — go to a section.
  const closeDrawerTo = (id?: string) => {
    pendingScrollId.current = id ?? null
    setMobileMenuOpen(false)
  }

  // Every way of dismissing the sheet goes through here, so it always drops
  // away rather than vanishing: tapping outside, the close button, Escape, and
  // the automatic close after adding to the cart.
  // One pending timer at a time (the close after adding, or the drop-away), so
  // a stale one can never close a sheet opened in the meantime.
  const sheetTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const closeSheet = () => {
    if (!sheetSlug || sheetClosing) return
    setSheetClosing(true)
    if (sheetTimer.current) clearTimeout(sheetTimer.current)
    sheetTimer.current = setTimeout(() => {
      sheetTimer.current = null
      setSheetSlug(null)
      setSheetClosing(false)
      setSheetAdded(false)
    }, 320)
  }

  const openSheet = (slug: string, pinnedId: string | null = null) => {
    if (sheetTimer.current) { clearTimeout(sheetTimer.current); sheetTimer.current = null }
    setSheetClosing(false)
    setSheetAdded(false)
    setSheetMods([])
    setSheetPinned(pinnedId)
    setSheetSlug(slug)
  }

  // The header is light-on-transparent over the hero; with the mobile sheet
  // open it sits on cream instead, so it has to switch to its solid styling
  // or the brand and icons disappear.
  const navSolid = scrolled || mobileMenuOpen

  const cartCount = cart.reduce((sum, item) => sum + item.quantity, 0)

  // Match category and description too — searching "drinks" or "vegetarian"
  // returned nothing when only the dish name was considered.
  const filteredMeals = (() => {
    const q = searchQuery.trim().toLowerCase()
    if (!q) return meals
    return meals.filter(meal =>
      meal.name?.toLowerCase().includes(q) ||
      meal.category?.toLowerCase().includes(q) ||
      meal.description?.toLowerCase().includes(q)
    )
  })()

  // Typing in the header filtered a section far below the fold, so it looked
  // like search did nothing. Jump to the menu when a query first appears.
  const hadQuery = useRef(false)
  useEffect(() => {
    const has = searchQuery.trim().length > 0
    if (has && !hadQuery.current) {
      if (mobileMenuOpen) pendingScrollId.current = 'menu'
      else document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
    hadQuery.current = has
  }, [searchQuery])

  // Get popular items (hardcoded favorites)
  const getPopularItems = () => {
    const orderedNames = ['waakye', 'jollof', 'fried rice']
    const result = []
    
    // Find meals in specific order
    for (const name of orderedNames) {
      const meal = meals.find(meal => 
        meal.name.toLowerCase().includes(name) && meal.available !== false
      )
      if (meal) result.push(meal)
    }
    
    return result
  }

  const refreshMeals = async () => {
    setLoading(true)
    try {
      const fetchedMeals = await mealsService.getAllMeals()
      const mealsWithAvailability = fetchedMeals.map(meal => ({
        ...meal,
        available: meal.active !== false && meal.available !== false
      }))
      setMeals(mealsWithAvailability)
    } catch (error) {
      console.error('Error refreshing meals:', error)
    } finally {
      setLoading(false)
    }
  }

  const nextSlide = () => {
    setCurrentSlide((prev) => (prev + 1) % heroImages.length)
  }

  const prevSlide = () => {
    setCurrentSlide((prev) => (prev - 1 + heroImages.length) % heroImages.length)
  }

  const nextReview = () => {
    setCurrentReview((prev) => (prev + 1) % reviews.length)
  }

  const prevReview = () => {
    setCurrentReview((prev) => (prev - 1 + reviews.length) % reviews.length)
  }

  const HEADINGS: Record<string, string> = {
    protein: 'Choose your protein',
    soup: 'Choose your soup',
    preparation: 'Choose your preparation',
    side: 'Served with',
    portion: 'How many pieces',
  }

  // One place that works out which variant a card is showing, so
  // the card and the phone sheet can never disagree about it.
  const resolveGroup = (group: Meal[], slug: string) => {
    const variants = group.filter(m => m.variantLabel)
      .sort((a, b) => a.price - b.price)
    const chosenId = selectedVariant[slug]
    // Prefer a variant that can actually be ordered. Picking
    // purely by "first non-vegetarian" made a whole card read
    // "Sold out" whenever that one option happened to be off —
    // Fried Rice looked unavailable while five proteins were fine.
    const defaultVariant =
      variants.find(v => !v.isVegetarian && v.available !== false)
      ?? variants.find(v => v.available !== false)
      ?? variants.find(v => !v.isVegetarian)
      ?? variants[0]
    const active = group.find(m => m.id === chosenId)
      ?? (variants.length ? defaultVariant : group[0])
    const cheapest = Math.min(...group.map(m => m.price))
    const soldOut = active.available === false
    const allSoldOut = group.every(m => m.available === false)
    return { group, variants, active, cheapest, soldOut, allSoldOut }
  }

  // The dish sheet lives up here, not inside the menu render, so anything can
  // open it — a customer favourite as well as a menu card. It shows what the
  // menu is showing for that dish, so a vegetarian with the filter on sees only
  // vegetarian options; a dish opened from outside the filtered view falls
  // back to every option it has, rather than opening nothing at all.
  const sheet = (() => {
    if (!sheetSlug) return null
    const inView = (vegOnly ? filteredMeals.filter(m => m.isVegetarian) : filteredMeals)
      .filter(m => m.baseSlug === sheetSlug)
    // A pinned dish the filtered view doesn't include means the sheet was
    // opened from outside it, so it shows every option the dish has.
    const outsideView = !inView.length || (sheetPinned !== null && !inView.some(m => m.id === sheetPinned))
    const group = outsideView ? meals.filter(m => m.baseSlug === sheetSlug) : inView
    return group.length ? resolveGroup(group, sheetSlug) : null
  })()

  const sheetOffered = sheet ? modifiersFor(modifiers, sheet.active) : []
  const sheetChosen = sheetOffered.filter(m => sheetMods.includes(m.id))
  const sheetPrice = sheet ? sheet.active.price + sheetChosen.reduce((s, m) => s + m.price, 0) : 0

  const addFromSheet = async () => {
    if (!sheet) return
    await addToCart(sheet.active, sheetChosen)
    setSheetAdded(true)
    sheetTimer.current = setTimeout(closeSheet, 900)
  }

  return (
    <div className="min-h-screen bg-sand-50">
      {/* Banner and nav share one fixed stack. Previously the banner sat in
          normal flow while the nav was fixed on top of it, so the closed
          notice rendered straight through the middle of the header. */}
      <header ref={headerRef} className="fixed top-0 left-0 right-0 z-50">
        {statusKnown && !isOpen && (
          <div className="bg-clay-700 text-sand-50 py-2 px-4 text-center text-[13px]">
            {/* One line. It used to read "We're closed right now." followed by
                "The restaurant is closed today." — the same thing twice — and
                on a closed day fell back to offering to schedule an order,
                which the schedule check refuses. */}
            {restaurantStatus.opensAt ? (
              <>
                <span className="font-semibold">Closed now</span>
                {' · '}Opens {restaurantStatus.opensAt}
              </>
            ) : (
              <span className="font-semibold">{restaurantStatus.message || 'Closed right now'}</span>
            )}
          </div>
        )}

        <nav className={`transition-colors duration-300 ${
          navSolid ? 'bg-sand-50/95 backdrop-blur-md border-b border-sand-200' : 'bg-gradient-to-b from-ink/80 via-ink/40 to-transparent'
        }`}>
          {/* Full-bleed: the brand belongs at the left edge of the screen, not
              floating in the middle of a centred container. The controls stay
              grouped on the right so the gap between reads as deliberate
              rather than as three scattered clusters. */}
          <div className="chrome-shell">
            <div className="flex items-center gap-3 lg:gap-8 h-16">
            {/* Brand. The full name is two lines of text next to a 48px mark —
                far too wide to share a 375px row with a search field, which is
                what broke the mobile header. Below sm it becomes the mark plus
                a short wordmark. */}
            <Link href="/" className="flex items-center gap-3 shrink-0">
              <Image
                src="/assets/images/logo.png"
                alt="Taste of African Cuisine"
                width={40}
                height={40}
                className="object-cover w-9 h-9 sm:w-11 sm:h-11 rounded-card"
                unoptimized
              />
              <div className="min-w-0">
                <span className={`block font-display tracking-tight leading-[1.05] text-[15px] sm:text-xl ${navSolid ? 'text-ink' : 'text-sand-50'}`}>
                  Taste of African Cuisine
                </span>
                {/* When closed, the banner directly above already says so —
                    repeating it here just crowds the mark. */}
                {statusKnown && isOpen && (
                  <span className={`hidden sm:flex items-center gap-1.5 mt-0.5 text-[11px] tracking-[0.12em] uppercase ${navSolid ? 'text-sand-500' : 'text-sand-200/75'}`}>
                    <span className="w-1.5 h-1.5 rounded-full bg-kente-300"></span>
                    Open now
                  </span>
                )}
              </div>
            </Link>

            {/* Search is desktop-only. On mobile it lives in the menu sheet,
                where it has room to be usable rather than a 90px stub. */}
            <div className="hidden lg:flex flex-1 justify-end">
              <div className="relative w-full max-w-xs">
                <Search className={`absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 ${
                  navSolid ? 'text-sand-500' : 'text-sand-200/70'
                }`} />
                <input
                  type="text"
                  placeholder="Search dishes"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className={`w-full pl-10 pr-4 py-2 text-base rounded-control border transition-colors focus:outline-none ${
                    scrolled
                      ? 'bg-sand-50 border-sand-200 text-ink placeholder-sand-500 focus:border-gold'
                      : 'bg-white/10 border-white/20 text-white placeholder-white/60 focus:border-gold-300'
                  }`}
                />
              </div>
            </div>

            {/* Right Side - Menu, Cart, Order Button */}
            <div className="flex items-center gap-3 ml-auto">
              {/* Desktop Menu */}
              <div className="hidden md:flex items-center gap-5">
                {['Menu', 'About', 'Contact'].map(item => (
                  <a key={item} href={`#${item.toLowerCase()}`} 
                     className={`text-sm font-medium transition-colors ${
                       navSolid ? 'text-ink-soft hover:text-gold-600' : 'text-sand-100 hover:text-gold-300'
                     }`}>
                    {item}
                  </a>
                ))}
                
                <Link href="/cart" className={`relative p-2 rounded-full transition-colors ${
                  navSolid ? 'text-sand-700 hover:bg-sand-100' : 'text-white hover:bg-white/10'
                }`}>
                  <ShoppingCart className="w-5 h-5" />
                  {cartCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-clay text-white text-[11px] rounded-full w-5 h-5 flex items-center justify-center font-semibold">
                      {cartCount}
                    </span>
                  )}
                </Link>
                
                <button 
                  onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
                  className="bg-gold text-ink px-5 py-2 rounded-control text-sm font-semibold hover:bg-gold-600 hover:text-sand-50 transition-colors"
                >
                  Order now
                </button>
                
                {/* Auth Buttons */}
                {user ? (
                  <div className="flex items-center space-x-3">
                    <OrderNotifications />
                    <Link href="/orders" className={`p-2 rounded-full transition-colors ${
                      navSolid ? 'text-sand-700 hover:bg-sand-100' : 'text-white hover:bg-white/10'
                    }`} title="My Orders">
                      <Clock className="w-5 h-5" />
                    </Link>
                    <div className="flex items-center space-x-2">
                      <User className="w-5 h-5 text-sand-700" />
                      <Link href="/profile" className={`text-sm font-medium hover:text-gold-600 transition-colors ${
                        navSolid ? 'text-sand-700' : 'text-white'
                      }`}>
                        {userProfile?.name || user.email}
                      </Link>
                    </div>
                    <button
                      onClick={async () => {
                        setSigningOut(true)
                        await new Promise(resolve => setTimeout(resolve, 500))
                        signOut()
                      }}
                      disabled={signingOut}
                      className={`p-2 transition-all duration-300 disabled:opacity-70 transform hover:scale-110 ${
                        navSolid ? 'text-sand-700 hover:text-clay' : 'text-white hover:text-clay-300'
                      }`}
                      title="Sign Out"
                    >
                      {signingOut ? (
                        <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-current"></div>
                      ) : (
                        <LogOut className="w-5 h-5" />
                      )}
                    </button>
                  </div>
                ) : (
                  <div className="flex items-center space-x-3">
                    <Link
                      href="/login"
                      onClick={() => setNavigating(true)}
                      className={`text-sm font-medium transition-colors flex items-center gap-2 ${
                        navSolid ? 'text-ink-soft hover:text-gold-600' : 'text-sand-100 hover:text-gold-300'
                      }`}
                    >
                      {navigating ? (
                        <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-current"></div>
                      ) : null}
                      Sign In
                    </Link>
                    <Link
                      href="/register"
                      onClick={() => setNavigating(true)}
                      className="bg-kente text-sand-50 px-4 py-2 rounded-control text-sm font-semibold hover:bg-kente-800 transition-colors flex items-center gap-2"
                    >
                      {navigating ? (
                        <div className="animate-spin rounded-full h-4 w-4 border-2 border-ink/30 border-t-ink"></div>
                      ) : null}
                      Sign Up
                    </Link>
                  </div>
                )}
              </div>

              {/* Mobile Menu Button */}
              <div className="md:hidden flex items-center space-x-2">
                <Link href="/cart" className={`relative p-2 rounded-full ${
                  navSolid ? 'text-sand-700' : 'text-white'
                }`}>
                  <ShoppingCart className="w-5 h-5" />
                  {cartCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-clay text-white text-[11px] rounded-full w-5 h-5 flex items-center justify-center font-semibold">
                      {cartCount}
                    </span>
                  )}
                </Link>
                <button 
                  onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                  className={`p-2 rounded-full ${
                    navSolid ? 'text-sand-700' : 'text-white'
                  }`}
                >
                  {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
                </button>
              </div>
            </div>
          </div>

          {/* Mobile Menu */}
          </div>
        </nav>
      </header>

      {/* Side drawer. It carries what the old dropdown didn't — there was no
          way to reach an account on mobile at all, and tap-to-call and
          directions matter more on a restaurant site than a hamburger does.
          It sits alongside the page rather than replacing it. */}
      {mobileMenuOpen && (
        <>
          <div
            onClick={() => setMobileMenuOpen(false)}
            className={`md:hidden fixed inset-x-0 bottom-0 z-40 bg-ink/45 touch-none ${
              statusKnown && !isOpen ? 'top-[6.25rem]' : 'top-16'
            }`}
          />
          <div
            className={`md:hidden fixed right-0 bottom-0 z-40 w-[80%] max-w-xs flex flex-col bg-sand-50 border-l border-sand-200 shadow-lift ${
              statusKnown && !isOpen ? 'top-[6.25rem]' : 'top-16'
            }`}
          >
          <div className="flex-1 overflow-y-auto overscroll-contain px-5 pb-8">

            <div className="relative mt-4">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-sand-500" />
              <input
                type="text"
                placeholder="Search dishes"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') closeDrawerTo(searchQuery.trim() ? 'menu' : undefined) }}
                className="w-full pl-10 pr-4 py-3 text-[15px] rounded-control border border-sand-200 bg-white text-ink placeholder-sand-500 focus:outline-none focus:border-gold"
              />
            </div>

            <button
              onClick={() => closeDrawerTo('menu')}
              className="mt-4 w-full bg-gold text-ink py-3.5 rounded-control font-semibold hover:bg-gold-300 transition-colors"
            >
              Order now
            </button>

            <p className="mt-8 mb-1 text-[11px] font-semibold tracking-[0.14em] uppercase text-sand-500">Browse</p>
            {[
              { label: 'Menu', href: '#menu' },
              { label: 'About', href: '#about' },
              { label: 'Contact', href: '#contact' },
            ].map(item => (
              <a
                key={item.label}
                href={item.href}
                onClick={(e) => { e.preventDefault(); closeDrawerTo(item.href.slice(1)) }}
                className="flex items-center justify-between py-3.5 border-b border-sand-200 text-ink font-medium"
              >
                {item.label}
                <ChevronRight className="w-4 h-4 text-sand-300" />
              </a>
            ))}

            <p className="mt-8 mb-1 text-[11px] font-semibold tracking-[0.14em] uppercase text-sand-500">Account</p>
            {user ? (
              <>
                <Link href="/orders" onClick={() => setMobileMenuOpen(false)}
                  className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
                  <Clock className="w-4 h-4 text-sand-500" /> My orders
                </Link>
                <Link href="/profile" onClick={() => setMobileMenuOpen(false)}
                  className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
                  <User className="w-4 h-4 text-sand-500" /> Profile
                </Link>
                <Link href="/profile#favorites" onClick={() => setMobileMenuOpen(false)}
                  className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
                  <Heart className="w-4 h-4 text-sand-500" /> Favorites
                </Link>
                <button
                  onClick={() => { setMobileMenuOpen(false); signOut() }}
                  disabled={signingOut}
                  className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-clay font-medium disabled:opacity-60 w-full"
                >
                  <LogOut className="w-4 h-4" /> {signingOut ? 'Signing out…' : 'Sign out'}
                </button>
              </>
            ) : (
              <div className="flex gap-3 mt-3">
                <Link href="/login" onClick={() => setMobileMenuOpen(false)}
                  className="flex-1 text-center py-3 rounded-control border border-sand-300 text-ink font-semibold">
                  Sign in
                </Link>
                <Link href="/register" onClick={() => setMobileMenuOpen(false)}
                  className="flex-1 text-center py-3 rounded-control bg-kente text-sand-50 font-semibold">
                  Create account
                </Link>
              </div>
            )}

            <p className="mt-8 mb-1 text-[11px] font-semibold tracking-[0.14em] uppercase text-sand-500">Visit us</p>
            <a href="tel:+18608055121"
              className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
              <Phone className="w-4 h-4 text-sand-500" /> (860) 805-5121
            </a>
            <a href="https://maps.google.com/?q=200+Hartford+Turnpike,+Vernon,+CT+06066"
              target="_blank" rel="noopener noreferrer"
              className="flex items-start gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
              <MapPin className="w-4 h-4 text-sand-500 mt-0.5 shrink-0" />
              <span>200 Hartford Turnpike<br /><span className="text-sand-500 font-normal text-sm">Vernon, CT 06066</span></span>
            </a>
            <a href="mailto:orders@tasteofafricancuisine.com"
              className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
              <Mail className="w-4 h-4 text-sand-500 shrink-0" />
              <span className="break-all text-[15px]">orders@tasteofafricancuisine.com</span>
            </a>
            <a href={GOOGLE_REVIEWS_URL} target="_blank" rel="noopener noreferrer"
              className="flex items-center gap-3 py-3.5 border-b border-sand-200 text-ink font-medium">
              <Star className="w-4 h-4 text-sand-500 shrink-0" /> Google reviews
            </a>
            <div className="flex items-start gap-3 py-3.5 text-sand-700">
              <Clock className="w-4 h-4 text-sand-500 mt-0.5 shrink-0" />
              <span className="text-sm">
                Tue–Sat 11:00 AM – 9:00 PM<br />
                <span className="text-sand-500">Friday until 8:00 PM · Sun &amp; Mon closed</span>
              </span>
            </div>
          </div>
          </div>
        </>
      )}


      {/* Hero Section */}
      {/* h-screen pushed everything below the fold on phones and left a lot of
          dimmed photo doing nothing. A capped viewport height with a floor
          keeps the dish visible and the menu within reach. */}
      <section className="relative min-h-[560px] h-[86svh] max-h-[820px] flex items-end sm:items-center overflow-hidden">
        {/* Carousel Images */}
        {heroImages.map((image, index) => (
          <div
            key={index}
            className={`absolute inset-0 transition-opacity duration-1000 ${
              index === currentSlide ? 'opacity-100' : 'opacity-0'
            }`}
          >
            <Image
              src={image.src}
              alt={image.title}
              fill
              className="object-cover"
              priority={index === 0}
              unoptimized
            />
          </div>
        ))}

        {/* Scrim, not a global dim */}
        <div className="absolute inset-0 bg-gradient-to-t from-ink/90 via-ink/45 to-ink/25 sm:bg-gradient-to-r sm:from-ink/90 sm:via-ink/60 sm:to-transparent" />
        
        {/* Navigation Arrows */}
        {/* Paired in the corner rather than pinned to each edge, where they
            landed on top of the headline on narrow screens. */}
        <div className="absolute bottom-5 right-4 sm:right-6 z-20 flex gap-2">
          <button
            onClick={prevSlide}
            aria-label="Previous dish"
            className="p-2.5 bg-sand-50/15 hover:bg-sand-50/25 border border-sand-50/25 rounded-control backdrop-blur-sm transition-colors"
          >
            <ChevronLeft className="w-5 h-5 text-sand-50" />
          </button>
          <button
            onClick={nextSlide}
            aria-label="Next dish"
            className="p-2.5 bg-sand-50/15 hover:bg-sand-50/25 border border-sand-50/25 rounded-control backdrop-blur-sm transition-colors"
          >
            <ChevronRight className="w-5 h-5 text-sand-50" />
          </button>
        </div>
        
        {/* Left-aligned rather than centred: centred text over a photograph
            gives the eye no consistent starting point, and the type had to jump
            5xl -> 7xl with nothing in between. */}
        {/* Same horizontal padding as the header, so the headline starts on
            the same left edge as the brand instead of being indented by a
            centred container. */}
        <div className="relative z-10 w-full min-w-0 chrome-shell pb-16 sm:pb-0">
          <div className="min-w-0 max-w-2xl">
            <p className="text-gold-300 text-[11px] sm:text-xs font-semibold tracking-[0.18em] uppercase mb-4 break-words">
              {heroImages[currentSlide].title} · {heroImages[currentSlide].subtitle}
            </p>
            <h1 className="font-display text-sand-50 leading-[0.95] tracking-tight text-[2.6rem] sm:text-6xl lg:text-7xl mb-5 text-balance">
              African cooking,<br />
              <span className="text-gold">made from scratch</span>
            </h1>
            <p className="text-sand-100/85 text-base sm:text-lg leading-relaxed mb-8 max-w-md">
              Jollof, waakye, banku and fufu — the recipes our family has cooked
              for generations, served in Vernon.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 sm:items-center">
              <button
                onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
                className="bg-gold text-ink px-7 py-3.5 rounded-control font-semibold hover:bg-gold-300 transition-colors"
              >
                See the menu
              </button>
              <a
                href="#about"
                className="px-7 py-3.5 rounded-control font-semibold text-sand-50 border border-sand-50/30 hover:bg-sand-50/10 transition-colors text-center"
              >
                Our story
              </a>
            </div>
          </div>
        </div>

        {/* Dots Indicator */}
        <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2 z-20 flex space-x-2">
          {heroImages.map((_, index) => (
            <button
              key={index}
              onClick={() => setCurrentSlide(index)}
              aria-label={`Show slide ${index + 1}`}
              className={`h-1 rounded-full transition-all ${
                index === currentSlide ? 'w-7 bg-gold' : 'w-3 bg-sand-50/40 hover:bg-sand-50/70'
              }`}
            />
          ))}
        </div>
      </section>

      {/* On a phone the menu comes straight after the hero: someone opening
          the site on their phone has come to order, and the two sections
          below used to put the first dish five screens down. The desktop
          order is unchanged. */}
      <div className="flex flex-col">
      {/* Features */}
      <section className="order-2 sm:order-none py-20 bg-sand-100">
        <div className="page-shell">
          {/* Left-aligned to share the edge the header and hero sit on —
              centred headings above left-aligned content read as misaligned. */}
          <div className="mb-14 max-w-2xl">
            <p className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-600 mb-3">Why us</p>
            <h2 className="font-display text-4xl sm:text-5xl text-ink leading-[1.05] mb-4">
              Cooked in Vernon, the way it is done at home
            </h2>
            <p className="text-sand-700 leading-relaxed">
              Traditional African dishes made from scratch with the ingredients
              and methods they&rsquo;re meant to be made with.
            </p>
          </div>
          
          <div className="grid md:grid-cols-3 gap-8 lg:gap-12">
            {/* Kept to what is demonstrably true. The previous third card
                claimed "4.9/5 stars by thousands of satisfied customers" and
                "Award-Winning Excellence" — there are no reviews in the
                database and no award, and invented ratings are the kind of
                claim the FTC acts on. */}
            {[
              {
                title: 'Cooked to order',
                desc: 'Nothing sits under a lamp. Stews are simmered, plantain fried and fufu pounded once you order, which is why it takes a little longer.'
              },
              {
                title: 'The right ingredients',
                desc: 'Seasonings and staples from African markets, because the recipes do not work with substitutes.'
              },
              {
                title: 'Pickup or delivery',
                desc: 'Collect from Hartford Turnpike, or we deliver across Vernon and the towns around it.'
              },
            ].map((item, index) => (
              <div key={item.title} className="border-t border-sand-300 pt-6">
                <span className="block font-display text-3xl text-gold-600 mb-3 tabular-nums">
                  {String(index + 1).padStart(2, '0')}
                </span>
                <h3 className="font-display text-2xl text-ink mb-3 leading-tight">{item.title}</h3>
                <p className="text-sand-700 text-[15px] leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Popular Items Section */}
      <section className="order-3 sm:order-none py-12 sm:py-20 bg-sand-50">
        <div className="page-shell">
          <div className="mb-12 max-w-2xl">
            <p className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-600 mb-3">Popular right now</p>
            <h2 className="font-display text-4xl sm:text-5xl text-ink leading-[1.05] mb-3">Customer favorites</h2>
            <p className="text-sand-700 leading-relaxed">The dishes people come back for.</p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold mx-auto"></div>
            </div>
          ) : (
            <div className="grid grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-5 lg:gap-6">
              {getPopularItems().map((meal, index) => (
                // Two per row until the three-column desktop grid. With three
                // favourites that leaves one alone on the last row, so it is
                // centred at half width rather than stranded on the left.
                <div key={meal.id}
                     className="relative flex flex-col bg-white border border-sand-200 rounded-card overflow-hidden shadow-card cursor-pointer
                       last:odd:col-span-2 last:odd:justify-self-center last:odd:w-[calc(50%-0.375rem)] sm:last:odd:w-[calc(50%-0.625rem)]
                       lg:last:odd:col-span-1 lg:last:odd:w-auto lg:last:odd:justify-self-stretch"
                     onClick={() => {
                       // Phones open the same choose-and-add sheet as the menu,
                       // on this exact dish.
                       if (isPhone()) {
                         setSelectedVariant(prev => ({ ...prev, [meal.baseSlug]: meal.id }))
                         openSheet(meal.baseSlug, meal.id)
                         return
                       }
                       const mealData = encodeURIComponent(JSON.stringify(meal))
                       window.location.href = `/meal?meal=${mealData}`
                     }}>
                  {/* Popular Badge */}
                  <div className="absolute top-2 left-2 sm:top-3 sm:left-3 z-10 bg-ink text-sand-50 px-2 py-1 rounded text-[10px] sm:text-[11px] font-semibold tabular-nums">
                    {index + 1}
                  </div>
                  
                  <div className="relative aspect-square overflow-hidden bg-sand-100">
                    <DishPhoto
                      src={getImageUrl(meal)}
                      alt={`${meal.name} at Taste of African Cuisine`}
                    />
                    
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        toggleFavorite(meal.id)
                      }}
                      className="absolute top-2 right-2 sm:top-3 sm:right-3 p-1.5 sm:p-2 bg-sand-50/90 backdrop-blur rounded-full"
                    >
                      <Heart className={`w-4 h-4 ${favorites.has(meal.id) ? 'fill-clay text-clay' : 'text-sand-700'}`} />
                    </button>
                  </div>

                  {/* Phone: name and price. The card itself opens the sheet. */}
                  <div className="sm:hidden flex flex-col flex-1 p-3">
                    <span className="font-display text-base text-ink leading-tight line-clamp-2">{meal.name}</span>
                    <span className="mt-auto pt-2 text-sm font-semibold text-ink tabular-nums">${meal.price?.toFixed(2)}</span>
                  </div>

                  <div className="hidden sm:flex flex-col flex-1 p-5">
                    <h4 className="font-display text-xl text-ink leading-tight">{meal.name}</h4>
                    <p className="mt-1.5 text-sm text-sand-700 line-clamp-2 min-h-[2.5rem]">{meal.description}</p>

                    <div className="mt-auto pt-5 flex items-center justify-between">
                      <span className="text-xl font-semibold text-ink tabular-nums">${meal.price?.toFixed(2)}</span>
                      <button
                        onClick={async (e) => {
                          e.stopPropagation()
                          setNavigating(true)
                          const mealData = encodeURIComponent(JSON.stringify(meal))
                          window.location.href = `/meal?meal=${mealData}`
                        }}
                        disabled={navigating}
                        className="px-4 py-2 bg-gold text-ink rounded-control font-semibold text-sm hover:bg-gold-300 transition-colors flex items-center gap-1.5 disabled:opacity-70"
                      >
                        {navigating ? (
                          <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-white"></div>
                        ) : (
                          <Plus className="w-4 h-4" />
                        )}
                        {navigating ? 'Loading...' : 'Add'}
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
          
          {/* Points back up at the menu, which on a phone is now above it. */}
          <div className="hidden sm:block text-center mt-12">
            <button 
              onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
              className="inline-flex items-center gap-2 border border-sand-300 text-ink px-6 py-3 rounded-control font-semibold hover:bg-sand-100 transition-colors"
            >
              See the full menu
            </button>
          </div>
        </div>
      </section>

      {/* Menu Section */}
      <section id="menu" className="order-1 sm:order-none py-12 sm:py-20 bg-sand-50" style={{ scrollMarginTop: headerH }}>
        <div className="page-shell">
          <div className="mb-10 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-5">
            <div className="max-w-xl">
              <p className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-600 mb-3">The menu</p>
              <h2 className="font-display text-4xl sm:text-5xl text-ink leading-[1.05] mb-3">
                Cooked to order, the way it&rsquo;s made at home
              </h2>
              <p className="text-sand-700 leading-relaxed">
                Pick a dish, then choose how you want it — protein, soup or side.
              </p>
            </div>

            {/* Vegetarian is a flag on the dish now, so it filters the whole
                menu rather than hiding in a section of its own. */}
            <button
              onClick={() => setVegOnly(v => !v)}
              aria-pressed={vegOnly}
              className={`self-start shrink-0 px-4 py-2.5 rounded-control text-sm font-semibold border transition-colors ${
                vegOnly
                  ? 'bg-kente text-sand-50 border-kente'
                  : 'bg-white text-ink-soft border-sand-200 hover:border-sand-300'
              }`}
            >
              {vegOnly ? 'Showing vegetarian' : 'Vegetarian only'}
            </button>
          </div>

          {loading ? (
            <div className="text-center py-20">
              <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold mx-auto"></div>
            </div>
          ) : meals.length === 0 ? (
            <p className="text-center text-sand-500 py-20">No meals available at the moment.</p>
          ) : (searchQuery || vegOnly) && (vegOnly ? filteredMeals.filter(m => m.isVegetarian) : filteredMeals).length === 0 ? (
            <div className="text-center py-20">
              <p className="text-xl text-sand-700 mb-4">No meals found for &ldquo;{searchQuery}&rdquo;</p>
              <p className="text-sand-500">Try a dish, a category like &ldquo;drinks&rdquo;, or an ingredient.</p>
            </div>
          ) : (
            <div className="space-y-10 sm:space-y-14">
              {(() => {
                // One card per base dish. 126 dishes become 68 cards, because a
                // customer choosing jollof wants to pick a protein, not scroll
                // past seven near-identical tiles.
                const pool = vegOnly ? filteredMeals.filter(m => m.isVegetarian) : filteredMeals

                const cards = new Map<string, Meal[]>()
                for (const m of pool) {
                  const list = cards.get(m.baseSlug) ?? []
                  list.push(m)
                  cards.set(m.baseSlug, list)
                }

                const SECTIONS = ['Main Dishes', 'Side Dishes', 'Desserts', 'Drinks']
                const bySection = new Map<string, string[]>()
                for (const [slug, group] of cards) {
                  const s = group[0].menuSection
                  bySection.set(s, [...(bySection.get(s) ?? []), slug])
                }

                const resolve = (slug: string) => resolveGroup(cards.get(slug)!, slug)

                const sectionId = (s: string) => `menu-${s.toLowerCase().replace(/\s+/g, '-')}`


                const present = SECTIONS.filter(s => bySection.has(s))

                // Each section opens on its first few dishes with a "See all"
                // button, so a phone isn't scrolling through all 26 mains to
                // reach the drinks. The restaurant chose which lead each
                // section; the rest follow in their usual order.
                const PREVIEW = 6
                const FEATURED: Record<string, string[]> = {
                  'Main Dishes': ['jollof', 'waakye', 'fried-rice', 'kenkey', 'fufu', 'banku'],
                  'Side Dishes': ['fufu-ball', 'rice-ball-side', 'fried-plantain-individual-'],
                }
                // Searching or filtering means the customer is looking for
                // something specific, so every match is shown — hiding some of
                // their results behind a button would defeat the search.
                const browsing = !searchQuery.trim() && !vegOnly
                const orderedSlugs = (section: string) => {
                  const slugs = bySection.get(section)!
                  const lead = FEATURED[section] ?? []
                  const rank = (slug: string) =>
                    lead.includes(slug) ? lead.indexOf(slug) : lead.length + slugs.indexOf(slug)
                  return [...slugs].sort((a, b) => rank(a) - rank(b))
                }
                const visibleSlugs = (section: string) => {
                  const all = orderedSlugs(section)
                  return !browsing || expandedSections[section] || all.length <= PREVIEW ? all : all.slice(0, PREVIEW)
                }
                const toggleSection = (section: string) => {
                  const collapsing = !!expandedSections[section]
                  setExpandedSections(prev => ({ ...prev, [section]: !collapsing }))
                  // Folding a long section back up would otherwise leave you
                  // far below it, looking at the next one.
                  if (collapsing) {
                    setTimeout(() => document.getElementById(sectionId(section))
                      ?.scrollIntoView({ behavior: 'smooth', block: 'start' }), 0)
                  }
                }
                return (
                  <>
                  {/* Sticks under the header while you are in the menu.
                      Drinks used to be 37 screens down on a phone. */}
                  {present.length > 1 && (
                    <div
                      className="sticky z-30 -mx-4 sm:-mx-6 lg:-mx-10 px-4 sm:px-6 lg:px-10 py-2.5 bg-sand-50/95 backdrop-blur border-b border-sand-200"
                      style={{ top: headerH }}
                    >
                      <div className="flex gap-1.5 sm:gap-2 overflow-x-auto [scrollbar-width:none]">
                        {present.map(s => {
                          const on = (activeSection ?? present[0]) === s
                          return (
                            <button
                              key={s}
                              onClick={() => document.getElementById(sectionId(s))?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
                              aria-current={on ? 'true' : undefined}
                              className={`shrink-0 flex-auto sm:flex-none px-2 min-[390px]:px-2.5 sm:px-4 py-2 rounded-full text-xs min-[390px]:text-[13px] sm:text-sm font-semibold whitespace-nowrap border transition-colors ${
                                on ? 'bg-ink text-sand-50 border-ink' : 'bg-white text-ink-soft border-sand-200'
                              }`}
                            >
                              {s}
                            </button>
                          )
                        })}
                      </div>
                    </div>
                  )}

                  {present.map(section => (
                  <div
                    key={section}
                    id={sectionId(section)}
                    data-menu-section={section}
                    style={{ scrollMarginTop: headerH + 64 }}
                  >
                    <div className="flex items-baseline gap-3 mb-7">
                      <h3 className="font-display text-3xl sm:text-4xl text-ink">{section}</h3>
                      <div className="flex-1 h-px bg-sand-200" />
                    </div>

                    <div className="grid grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-5 lg:gap-6">
                      {visibleSlugs(section).map(slug => {
                        const { group, variants, active, soldOut, allSoldOut } = resolve(slug)

                        return (
                          <div key={slug} className="flex flex-col bg-white border border-sand-200 rounded-card overflow-hidden shadow-card transition-transform duration-150 active:scale-[0.98] motion-reduce:transform-none">
                            <div
                              className="relative aspect-square overflow-hidden bg-sand-100 cursor-pointer"
                              onClick={() => {
                                if (isPhone()) openSheet(slug)
                                else window.location.href = `/meal?meal=${encodeURIComponent(JSON.stringify(active))}`
                              }}
                            >
                              <DishPhoto
                                src={getImageUrl(active)}
                                alt={`${active.baseName} at Taste of African Cuisine`}
                                onError={(e) => { (e.currentTarget as HTMLImageElement).src = '/assets/images/logo.png' }}
                              />
                              {soldOut && (
                                <div className="absolute inset-0 bg-ink/65 flex items-center justify-center">
                                  <span className="bg-clay text-sand-50 px-3 py-1.5 rounded-control text-xs font-semibold">Sold out</span>
                                </div>
                              )}
                              <button
                                onClick={(e) => { e.stopPropagation(); toggleFavorite(active.id) }}
                                aria-label="Save this dish"
                                className="absolute top-2 right-2 sm:top-3 sm:right-3 p-1.5 sm:p-2 bg-sand-50/90 backdrop-blur rounded-full"
                              >
                                <Heart className={`w-4 h-4 ${favorites.has(active.id) ? 'fill-clay text-clay' : 'text-sand-700'}`} />
                              </button>
                              {group.every(m => m.isVegetarian) && (
                                <span className="absolute top-2 left-2 sm:top-3 sm:left-3 bg-kente text-sand-50 text-[10px] sm:text-[11px] font-semibold px-2 py-1 rounded">
                                  Vegetarian
                                </span>
                              )}
                            </div>

                            {/* Phone: name and price only. Choosing happens in the sheet. */}
                            <button
                              type="button"
                              onClick={() => openSheet(slug)}
                              className="sm:hidden flex flex-col flex-1 text-left p-3"
                            >
                              <span className="font-display text-base text-ink leading-tight line-clamp-2">{active.baseName}</span>
                              <span className="mt-auto pt-2 text-sm font-semibold text-ink tabular-nums">
                                {allSoldOut
                                  ? 'Sold out'
                                  : `$${active.price?.toFixed(2)}`}
                              </span>
                            </button>

                            <div className="hidden sm:flex flex-col flex-1 p-5">
                              <h4 className="font-display text-xl text-ink leading-tight">{active.baseName}</h4>
                              {/* Describe the dish, not the selected variant.
                                  Showing active.description put "Jollof rice
                                  served with fried chicken" directly above a
                                  dropdown already reading "Fried Chicken". */}
                              <p className="mt-1.5 text-sm text-sand-700 line-clamp-2 min-h-[2.5rem]">
                                {active.baseDescription ?? active.description}
                              </p>

                              {/* A wrapped grid of chips made cards with many
                                  options far taller than those with none, and
                                  grid stretches a whole row to its tallest
                                  card. One control keeps every card the same
                                  height whether it has eight options or one. */}
                              <div className="mt-3 min-h-[62px]">
                                {variants.length > 1 && (
                                  <>
                                    <label htmlFor={`v-${slug}`} className="block text-[11px] font-semibold tracking-[0.12em] uppercase text-sand-500 mb-1.5">
                                      {HEADINGS[active.variantType ?? 'protein'] ?? 'Choose an option'}
                                    </label>
                                    <select
                                      id={`v-${slug}`}
                                      value={active.id}
                                      onChange={(e) => setSelectedVariant(prev => ({ ...prev, [slug]: e.target.value }))}
                                      className="w-full px-2.5 py-2.5 rounded-control border border-sand-200 bg-sand-50 text-ink text-base focus:outline-none focus:border-gold"
                                    >
                                      {variants.map(v => (
                                        <option key={v.id} value={v.id}>
                                          {v.variantLabel}{v.isVegetarian && !/vegetarian/i.test(v.variantLabel ?? '') ? ' · vegetarian' : ''} — ${v.price.toFixed(2)}{v.available === false ? ' · sold out' : ''}
                                        </option>
                                      ))}
                                    </select>
                                  </>
                                )}
                              </div>

                              <div className="mt-auto pt-5 flex items-end justify-between gap-3">
                                <div>
                                  <span className="text-xl font-semibold text-ink tabular-nums">${active.price?.toFixed(2)}</span>
                                </div>
                                <button
                                  onClick={() => { window.location.href = `/meal?meal=${encodeURIComponent(JSON.stringify(active))}` }}
                                  disabled={soldOut || (statusKnown && !isOpen)}
                                  className={`px-4 py-2 rounded-control text-sm font-semibold flex items-center gap-1.5 transition-colors ${
                                    !soldOut && !(statusKnown && !isOpen)
                                      ? 'bg-gold text-ink hover:bg-gold-300'
                                      : 'bg-sand-200 text-sand-500 cursor-not-allowed'
                                  }`}
                                >
                                  <Plus className="w-4 h-4" />
                                  {statusKnown && !isOpen ? 'Closed' : 'Add'}
                                </button>
                              </div>
                            </div>
                          </div>
                        )
                      })}
                    </div>

                    {browsing && orderedSlugs(section).length > PREVIEW && (
                      <div className="mt-5 sm:mt-6 flex justify-center">
                        <button
                          type="button"
                          onClick={() => toggleSection(section)}
                          aria-expanded={!!expandedSections[section]}
                          className="px-6 py-3 rounded-full border border-sand-300 bg-white text-ink text-sm font-semibold hover:border-ink transition-colors"
                        >
                          {expandedSections[section]
                            ? 'Show fewer'
                            : `See all ${section.toLowerCase()}`}
                        </button>
                      </div>
                    )}
                  </div>
                ))}

                  </>
                )
              })()}
            </div>
          )}
        </div>
      </section>
      </div>

      {/* The phone's choose-and-add step. It adds straight to the
          cart; the old Add button opened a separate page where
          you had to choose and press Add a second time. */}
      {sheet && (
        <div className={`sm:hidden fixed inset-0 z-[60] ${sheetClosing ? 'pointer-events-none' : ''}`} role="dialog" aria-modal="true" aria-label={sheet.active.baseName}>
          {/* The page behind blurs and dims as the sheet rises. */}
          <div
            className={`absolute inset-0 bg-ink/40 backdrop-blur-[6px] touch-none ${
              sheetClosing ? 'animate-[veil-out_320ms_ease-in_both]' : 'animate-[veil-in_450ms_ease-out_both]'
            }`}
            onClick={closeSheet}
          />
          {/* Opening is choreographed rather than instant: the sheet glides up,
              the photo settles from a slight zoom, then the name, description,
              options and price arrive one after another. */}
          <div className={`absolute inset-x-0 bottom-0 bg-sand-50 rounded-t-2xl max-h-[88svh] overflow-y-auto overscroll-contain shadow-2xl pb-[max(1rem,env(safe-area-inset-bottom))] will-change-transform ${
            sheetClosing
              ? 'animate-[sheet-drop_320ms_cubic-bezier(0.4,0,1,1)_both]'
              : 'animate-[sheet-rise_620ms_cubic-bezier(0.22,1,0.36,1)_both]'
          }`}>
            <div className="relative aspect-[4/3] w-full overflow-hidden rounded-t-2xl bg-sand-100">
              <div className="absolute inset-0 animate-[photo-settle_900ms_cubic-bezier(0.22,1,0.36,1)_both]">
                <DishPhoto
                  src={getImageUrl(sheet.active)}
                  alt={`${sheet.active.baseName} at Taste of African Cuisine`}
                />
              </div>
              {/* Grab bar: the cue every phone sheet gives that it can be dismissed. */}
              <div aria-hidden className="absolute top-2 left-1/2 -translate-x-1/2 z-10 w-10 h-1 rounded-full bg-sand-50/85 shadow-sm" />
              <button
                onClick={closeSheet}
                aria-label="Close"
                className="absolute top-3 right-3 z-10 p-2 bg-sand-50/90 rounded-full"
              >
                <X className="w-5 h-5 text-ink" />
              </button>
            </div>

            <div className="p-5">
              <h3 className="font-display text-2xl text-ink leading-tight animate-[rise-in_560ms_cubic-bezier(0.22,1,0.36,1)_200ms_both]">{sheet.active.baseName}</h3>
              <p className="mt-1.5 text-sm text-sand-700 animate-[rise-in_560ms_cubic-bezier(0.22,1,0.36,1)_270ms_both]">
                {sheet.active.baseDescription ?? sheet.active.description}
              </p>

              {sheet.variants.length > 1 && (
                <div className="mt-4 animate-[rise-in_560ms_cubic-bezier(0.22,1,0.36,1)_340ms_both]">
                  <label htmlFor="sheet-variant" className="block text-[11px] font-semibold tracking-[0.12em] uppercase text-sand-500 mb-1.5">
                    {HEADINGS[sheet.active.variantType ?? 'protein'] ?? 'Choose an option'}
                  </label>
                  <select
                    id="sheet-variant"
                    value={sheet.active.id}
                    onChange={(e) => setSelectedVariant(prev => ({ ...prev, [sheetSlug!]: e.target.value }))}
                    className="w-full px-3 py-3 rounded-control border border-sand-200 bg-white text-ink text-base focus:outline-none focus:border-gold"
                  >
                    {sheet.variants.map(v => (
                      <option key={v.id} value={v.id}>
                        {v.variantLabel}{v.isVegetarian && !/vegetarian/i.test(v.variantLabel ?? '') ? ' · vegetarian' : ''} — ${v.price.toFixed(2)}{v.available === false ? ' · sold out' : ''}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <ModifierPicker
                offered={sheetOffered}
                selected={sheetMods}
                onChange={setSheetMods}
                className="mt-5 animate-[rise-in_560ms_cubic-bezier(0.22,1,0.36,1)_380ms_both]"
              />

              {/* With add-ons the sheet runs long, so the price and the button
                  stay pinned to the bottom rather than scrolling out of reach. */}
              <div className={`flex items-center justify-between gap-4 animate-[rise-in_560ms_cubic-bezier(0.22,1,0.36,1)_420ms_both] ${
                sheetOffered.length
                  ? 'sticky bottom-0 z-10 -mx-5 mt-4 px-5 pt-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] bg-sand-50/95 backdrop-blur border-t border-sand-200'
                  : 'mt-5'
              }`}>
                <span className="text-2xl font-semibold text-ink tabular-nums">${sheetPrice.toFixed(2)}</span>
                <button
                  onClick={addFromSheet}
                  disabled={sheet.soldOut || (statusKnown && !isOpen) || addingToCart === sheet.active.id || sheetAdded}
                  className={`flex-1 max-w-[13rem] py-3.5 rounded-control text-base font-semibold transition-colors ${
                    sheetAdded
                      ? 'bg-kente text-sand-50'
                      : !sheet.soldOut && !(statusKnown && !isOpen)
                        ? 'bg-gold text-ink active:bg-gold-300'
                        : 'bg-sand-200 text-sand-500'
                  }`}
                >
                  {sheetAdded ? (
                    <span className="inline-flex items-center justify-center gap-2 animate-[added-pop_420ms_cubic-bezier(0.34,1.56,0.64,1)_both]">
                      <Check className="w-5 h-5" /> Added
                    </span>
                  ) : addingToCart === sheet.active.id ? (
                    <span className="inline-flex items-center justify-center gap-2">
                      <span aria-hidden className="w-4 h-4 rounded-full border-2 border-ink/20 border-t-ink animate-spin" />
                      Adding…
                    </span>
                  ) : statusKnown && !isOpen
                        ? 'Closed'
                        : sheet.soldOut
                          ? 'Sold out'
                          : 'Add to cart'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* About Section.
          Rewritten as plain text. It was built from green icon cards and
          emoji, and it made claims nothing supports — a Hartford Courant
          feature, "three generations", sauces "made fresh each morning" — as
          well as "Born in Ghana", when the restaurant describes itself as
          African rather than Ghanaian. Everything here is said elsewhere on
          the site. Add the restaurant's own story when they give it. */}
      <section id="about" className="py-16 sm:py-20 bg-ink text-sand-100" style={{ scrollMarginTop: headerH }}>
        <div className="page-shell">
          <div className="grid lg:grid-cols-2 gap-10 lg:gap-16 items-center">
            <div className="max-w-xl">
              <p className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-300 mb-3">Our story</p>
              <h2 className="font-display text-4xl sm:text-5xl text-sand-50 leading-[1.05] mb-6">
                A family kitchen in Vernon
              </h2>
              <div className="space-y-4 text-sand-300 text-lg leading-relaxed">
                <p>
                  Taste of African Cuisine cooks African food the way it&rsquo;s made at
                  home: jollof, waakye, banku and fufu, with the soups and stews that go
                  with them, from family recipes.
                </p>
                <p>
                  Everything is cooked to order, with seasonings and staples from African
                  markets. Pick it up on Hartford Turnpike, or have it delivered around
                  Vernon.
                </p>
              </div>
            </div>
            <div className="relative aspect-[4/3] rounded-card overflow-hidden bg-ink">
              <DishPhoto src="/assets/images/jollof.png" alt="Jollof at Taste of African Cuisine" />
            </div>
          </div>
        </div>
      </section>

      {/* Customer Reviews Section */}
      <section className="py-12 sm:py-20 bg-sand-100 overflow-hidden">
        <div className="page-shell">
          <div className="mb-8 sm:mb-12 max-w-2xl">
            <p className="text-[11px] font-semibold tracking-[0.18em] uppercase text-gold-600 mb-3">Reviews</p>
            <h2 className="font-display text-4xl sm:text-5xl text-ink leading-[1.05] mb-3">What people say</h2>
            <p className="text-sand-700 leading-relaxed">From customers who order with us regularly.</p>
          </div>

          {/* Reviews Carousel */}
          <div className="relative">
            {/* Navigation Arrows */}
            <button
              onClick={prevReview}
              aria-label="Previous review"
              className="hidden sm:block absolute left-0 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/90 hover:bg-white rounded-full shadow-lg hover:shadow-xl transition-all backdrop-blur-sm border border-sand-200"
            >
              <ChevronLeft className="w-6 h-6 text-gold-600" />
            </button>
            <button
              onClick={nextReview}
              aria-label="Next review"
              className="hidden sm:block absolute right-0 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/90 hover:bg-white rounded-full shadow-lg hover:shadow-xl transition-all backdrop-blur-sm border border-sand-200"
            >
              <ChevronRight className="w-6 h-6 text-gold-600" />
            </button>

            {/* Reviews Container */}
            <div
              className="overflow-hidden rounded-3xl"
              onTouchStart={(e) => { reviewTouchX.current = e.touches[0].clientX }}
              onTouchEnd={(e) => {
                const start = reviewTouchX.current
                reviewTouchX.current = null
                if (start == null) return
                const dx = e.changedTouches[0].clientX - start
                if (dx > 40) prevReview()
                else if (dx < -40) nextReview()
              }}
            >
              <div 
                className="flex transition-transform duration-700 ease-in-out"
                style={{ transform: `translateX(-${currentReview * 100}%)` }}
              >
                {reviews.map((review, index) => (
                  <div key={index} className="w-full flex-shrink-0 px-1 sm:px-4">
                    {/* Sized down on phones, where one review used to take
                        two-thirds of the screen: 30px star emoji, 20px quote
                        text, a 64px avatar and 32px padding all round. */}
                    <div className="bg-white/80 backdrop-blur-sm rounded-2xl sm:rounded-3xl p-5 sm:p-8 shadow-md sm:shadow-xl border border-sand-200 mx-auto max-w-4xl">
                      <div className="text-center">
                        {/* Stars */}
                        <div className="flex justify-center mb-3 sm:mb-6">
                          {[...Array(review.rating)].map((_, i) => (
                            <span key={i} className="text-base sm:text-3xl text-gold">⭐</span>
                          ))}
                        </div>
                        
                        {/* Review Text */}
                        <blockquote className="text-base sm:text-xl md:text-2xl text-sand-700 mb-4 sm:mb-8 leading-relaxed font-medium italic">
                          "{review.review}"
                        </blockquote>
                        
                        {/* Customer Info */}
                        <div className="flex items-center justify-center gap-3 sm:gap-4">
                          <div className="w-10 h-10 sm:w-16 sm:h-16 shrink-0 bg-gold rounded-full flex items-center justify-center text-white font-bold text-base sm:text-xl shadow-lg">
                            {review.name.charAt(0)}
                          </div>
                          <div className="text-left">
                            <h4 className="text-base sm:text-xl font-bold text-ink">{review.name}</h4>
                            <div className="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs sm:text-sm text-sand-700">
                              <span className="bg-gold text-white px-2 sm:px-3 py-0.5 sm:py-1 rounded-full font-medium">{review.dish}</span>
                              <span>•</span>
                              <span>{review.date}</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Dots Indicator */}
            <div className="flex justify-center mt-5 sm:mt-8 space-x-2">
              {reviews.map((_, index) => (
                <button
                  key={index}
                  onClick={() => setCurrentReview(index)}
                  aria-label={`Review ${index + 1}`}
                  className={`w-3 h-3 rounded-full transition-all duration-300 ${
                    index === currentReview 
                      ? 'bg-gold w-8' 
                      : 'bg-sand-200 hover:bg-sand-300'
                  }`}
                />
              ))}
            </div>
          </div>
        </div>

          {/* Reviews on our own page are only as trustworthy as we are. This
              sends people to the source, where they can see all of them and
              the rating we actually have. Google's documented Maps URL format
              — no key, no account, nothing to expire. */}
          <div className="mt-10 text-center">
            <a
              href={GOOGLE_REVIEWS_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-sm font-semibold text-kente border-b border-gold pb-0.5 hover:text-gold transition-colors"
            >
              Read our reviews on Google
              <span aria-hidden="true">&rarr;</span>
            </a>
          </div>

        
        <style jsx>{`
          @keyframes scroll {
            0% {
              transform: translateX(0);
            }
            100% {
              transform: translateX(-50%);
            }
          }
          .animate-scroll {
            animation: scroll 30s linear infinite;
          }
          .animate-scroll:hover {
            animation-play-state: paused;
          }
        `}</style>
      </section>

      {/* Footer */}
      <footer id="contact" className="bg-ink text-sand-100 py-16" style={{ scrollMarginTop: headerH }}>
        <div className="page-shell">
          {/* Centred on phones to match the centred copyright line below.
              Left-aligned there, the short blocks hugged the left edge and
              left the right half of the screen empty. Desktop keeps its three
              left-aligned columns. */}
          <div className="grid md:grid-cols-3 gap-10 md:gap-12 text-center md:text-left">
            <div>
              <div className="flex items-center justify-center md:justify-start gap-3 mb-6">
                <Image
                  src="/assets/images/logo.png"
                  alt="Logo"
                  width={50}
                  height={50}
                  className="object-contain"
                  unoptimized
                />
                <div className="text-left">
                  <h3 className="font-display text-2xl text-sand-50">Taste of African Cuisine</h3>
                  <p className="text-gold-300 text-sm">Authentic African cooking</p>
                </div>
              </div>
              <p className="text-sand-300 leading-relaxed max-w-sm mx-auto md:mx-0">
                Bringing authentic West African flavors to your doorstep with love and tradition.
              </p>
            </div>

            <div>
              <h4 className="text-xl font-bold mb-6 text-gold-300">Contact Us</h4>
              {/* Centred as one group so the icons stay in a column; centring
                  each row on its own would scatter them, since the rows are
                  different widths. */}
              <div className="inline-block md:block text-left space-y-4">
                <div className="flex items-center gap-3">
                  <Phone className="w-5 h-5 text-gold-300" />
                  <a href="tel:+18608055121" className="text-sand-300 hover:text-gold-300 transition-colors font-medium underline decoration-dotted">
                    (860) 805-5121
                  </a>
                </div>
                <div className="flex items-start gap-3">
                  <MapPin className="w-5 h-5 text-gold-300 mt-0.5" />
                  <a href="https://maps.google.com/?q=200+Hartford+Turnpike,+Vernon,+CT" target="_blank" rel="noopener noreferrer" className="text-sand-300 hover:text-gold-300 transition-colors font-medium underline decoration-dotted">
                    200 Hartford Turnpike<br />Vernon, CT
                  </a>
                </div>
                <div className="flex items-center gap-3">
                  <Mail className="w-5 h-5 text-gold-300 shrink-0" />
                  <a href="mailto:orders@tasteofafricancuisine.com" className="text-sand-300 hover:text-gold-300 transition-colors font-medium underline decoration-dotted break-all">
                    orders@tasteofafricancuisine.com
                  </a>
                </div>
              </div>
            </div>

            <div>
              <h4 className="text-xl font-bold mb-6 text-gold-300">Hours & Social</h4>
              <div className="space-y-3 mb-6">
                <div className="text-sand-300">
                  <span className="font-medium text-white">Tue–Sat:</span> 11:00 AM – 9:00 PM<br /><span className="text-sand-500 text-sm">Friday until 8:00 PM</span>
                </div>
                <div className="text-sand-300">
                  <span className="font-medium text-white">Sun & Mon:</span> <span className="text-clay-300">Closed</span>
                </div>
              </div>
              
              <div className="flex items-center justify-center md:justify-start gap-4">
                <a href="https://www.instagram.com/tasteofafrican_cuisinee/?hl=en" target="_blank" rel="noopener noreferrer" className="bg-gold hover:bg-gold-600 p-3 rounded-full transition-colors">
                  <Instagram className="w-6 h-6 text-white" />
                </a>
                <a href="https://www.facebook.com/people/Taste-Africa-Cuisine/pfbid01DpatNS1oHWsXCiHAEXQHirTRAyHbYqbRxhXVqw8htbCLe8H5S4CkspKmGnAhmgLl/?mibextid=7cd5pb" target="_blank" rel="noopener noreferrer" className="bg-blue-600 hover:bg-blue-700 p-3 rounded-full transition-colors">
                  <Facebook className="w-6 h-6 text-white" />
                </a>
              </div>
            </div>
          </div>

          <div className="border-t border-sand-700/40 mt-12 pt-8 text-center">
            <p className="text-sand-500">
              © {year} Taste of African Cuisine. All rights reserved.
              <span className="mx-2 text-sand-500">·</span>
              <a href="/privacy" className="text-sand-300 hover:text-gold-300 underline">Privacy</a>
              <span className="mx-2 text-sand-500">·</span>
              <a href="/terms" className="text-sand-300 hover:text-gold-300 underline">Terms</a>
              <span className="mx-2 text-sand-500">·</span>
              <a href="/refunds" className="text-sand-300 hover:text-gold-300 underline">Refunds</a>
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}