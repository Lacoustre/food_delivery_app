'use client'

import { useState, useEffect } from 'react'
import { ShoppingCart, Heart, Plus, Clock, Phone, MapPin, Search, Menu, X, ChevronLeft, ChevronRight, User, LogOut, Instagram, Facebook } from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'
import { mealsService, type Meal } from '@/lib/mealsService'
import { restaurantService, type RestaurantStatus } from '@/lib/restaurantService'
import { orderService } from '@/lib/orderService'
import { favoritesService } from '@/lib/favoritesService'
import { useAuth } from '@/lib/AuthContext'
import OrderNotifications from '@/components/OrderNotifications'

interface CartItem extends Meal {
  quantity: number
}

export default function AfricanCuisineWebsite() {
  const [cart, setCart] = useState<CartItem[]>([])
  const [favorites, setFavorites] = useState(new Set<string>())
  const [meals, setMeals] = useState<Meal[]>([])
  const [loading, setLoading] = useState(true)
  const [scrolled, setScrolled] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [currentSlide, setCurrentSlide] = useState(0)
  const [currentReview, setCurrentReview] = useState(0)
  const [addingToCart, setAddingToCart] = useState<string | null>(null)
  const [navigating, setNavigating] = useState(false)
  const [signingOut, setSigningOut] = useState(false)
  const [restaurantStatus, setRestaurantStatus] = useState<RestaurantStatus>({ isOpen: true, message: '', updatedAt: new Date() })
  
  const { user, userProfile, signOut } = useAuth()

  // Auto-listen for order status changes to send emails
  useEffect(() => {
    if (user) {
      const unsubscribe = orderService.listenForStatusUpdates(user.uid)
      return () => unsubscribe()
    }
  }, [user])

  // Load favorites from Firebase
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
    
    // If it's a Firebase Storage URL, use it directly
    if (meal.imageUrl.startsWith('https://firebasestorage.googleapis.com')) {
      return meal.imageUrl.replace(/&amp;/g, '&')
    }
    // If it's a local asset path, use it
    if (meal.imageUrl.startsWith('/assets/')) {
      return meal.imageUrl
    }
    // If it's just a filename, assume it's a local asset
    if (!meal.imageUrl.startsWith('http')) {
      return `/assets/images/${meal.imageUrl}`
    }
    // Fallback to logo
    return '/assets/images/logo.png'
  }

  const heroImages = [
    { src: '/assets/images/jollof.png', title: 'Jollof Rice', subtitle: 'Aromatic & Flavorful' },
    { src: '/assets/images/waakye.png', title: 'Waakye', subtitle: 'Traditional & Authentic' },
    { src: '/assets/images/banku_tilapia.avif', title: 'Banku & Tilapia', subtitle: 'Fresh & Delicious' },
    { src: '/assets/images/fufu_and_light_soup.avif', title: 'Fufu & Light Soup', subtitle: 'Comfort & Tradition' }
  ]

  const reviews = [
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
    },
    {
      name: "Marcus Johnson",
      review: "The jollof rice here is incredible! Perfectly seasoned and cooked to perfection. The atmosphere is warm and welcoming, and the staff treats you like family. Will definitely be back!",
      dish: "Jollof Rice",
      date: "3 months ago",
      rating: 5
    },
    {
      name: "Aisha Thompson",
      review: "Best African food in the area! The plantains are sweet and perfectly fried, and the stews are rich with authentic flavors. You can taste the love in every bite.",
      dish: "Plantains & Stew",
      date: "6 months ago",
      rating: 5
    }
  ]

  useEffect(() => {
    // Load cart from localStorage on component mount
    const savedCart = localStorage.getItem('cart')
    if (savedCart) {
      setCart(JSON.parse(savedCart))
    }
  }, [])

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

  const addToCart = async (meal: Meal) => {
    if (!restaurantStatus.isOpen) {
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
      const existing = prev.find(item => item.id === meal.id)
      let updatedCart
      if (existing) {
        updatedCart = prev.map(item => 
          item.id === meal.id ? { ...item, quantity: item.quantity + 1 } : item
        )
      } else {
        updatedCart = [...prev, { ...meal, quantity: 1 }]
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

  const cartCount = cart.reduce((sum, item) => sum + item.quantity, 0)

  const filteredMeals = meals.filter(meal => 
    meal.name.toLowerCase().includes(searchQuery.toLowerCase())
  )

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

  return (
    <div className="min-h-screen bg-amber-50">
      {/* Restaurant Status Banner */}
      {!restaurantStatus.isOpen && (
        <div className="bg-red-600 text-white py-3 px-4 text-center font-bold">
          🔒 Restaurant is currently closed. {restaurantStatus.message || 'We will be back soon!'}
        </div>
      )}
      
      {/* Navigation */}
      <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled ? 'bg-white/95 backdrop-blur-md shadow-lg' : 'bg-black/20 backdrop-blur-sm'
      }`}>
        <div className="w-full px-4 sm:px-6 lg:px-8">
          <div className="flex items-center h-16">
            {/* Logo & Brand - Far Left */}
            <div className="flex items-center space-x-3">
              <Image
                src="/assets/images/logo.png"
                alt="Logo"
                width={48}
                height={48}
                className="object-contain"
                unoptimized
              />
              <div>
                <h1 className={`text-lg font-bold italic ${scrolled ? 'text-gray-900' : 'text-white'}`}>
                  Taste of African Cuisine
                </h1>
                <p className={`text-xs italic flex items-center gap-2 ${scrolled ? 'text-orange-600' : 'text-orange-300'}`}>
                  <span className={`w-2 h-2 rounded-full ${restaurantStatus.isOpen ? 'bg-green-500' : 'bg-red-500'}`}></span>
                  {restaurantStatus.isOpen ? 'Open Now' : 'Closed'} • Authentic Ghanaian Food
                </p>
              </div>
            </div>

            {/* Centered Search Bar */}
            <div className="flex-1 flex justify-center">
              <div className="relative w-full max-w-md">
                <Search className={`absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 ${
                  scrolled ? 'text-gray-400' : 'text-white/70'
                }`} />
                <input
                  type="text"
                  placeholder="Search dishes..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className={`w-full pl-10 pr-4 py-2 rounded-full border-2 border-orange-500 transition-all ${
                    scrolled 
                      ? 'bg-white text-gray-900 placeholder-gray-500 focus:border-orange-600' 
                      : 'bg-white/10 text-white placeholder-white/70 focus:border-orange-400'
                  } focus:outline-none focus:ring-2 focus:ring-orange-500/20`}
                />
              </div>
            </div>

            {/* Right Side - Menu, Cart, Order Button */}
            <div className="flex items-center space-x-6 ml-auto">
              {/* Desktop Menu */}
              <div className="hidden md:flex items-center space-x-6">
                {['Menu', 'About', 'Contact'].map(item => (
                  <a key={item} href={`#${item.toLowerCase()}`} 
                     className={`font-medium transition-colors ${
                       scrolled ? 'text-gray-700 hover:text-orange-600' : 'text-white hover:text-orange-300'
                     }`}>
                    {item}
                  </a>
                ))}
                
                <Link href="/cart" className={`relative p-2 rounded-full transition-colors ${
                  scrolled ? 'text-gray-700 hover:bg-gray-100' : 'text-white hover:bg-white/10'
                }`}>
                  <ShoppingCart className="w-5 h-5" />
                  {cartCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-orange-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center font-medium">
                      {cartCount}
                    </span>
                  )}
                </Link>
                
                <button 
                  onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
                  className="bg-gradient-to-r from-orange-500 to-red-500 text-white px-6 py-2 rounded-full font-medium hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
                >
                  Order Now
                </button>
                
                {/* Auth Buttons */}
                {user ? (
                  <div className="flex items-center space-x-3">
                    <OrderNotifications />
                    <Link href="/orders" className={`p-2 rounded-full transition-colors ${
                      scrolled ? 'text-gray-700 hover:bg-gray-100' : 'text-white hover:bg-white/10'
                    }`} title="My Orders">
                      <Clock className="w-5 h-5" />
                    </Link>
                    <div className="flex items-center space-x-2">
                      <User className="w-5 h-5 text-gray-600" />
                      <Link href="/profile" className={`text-sm font-medium hover:text-orange-600 transition-colors ${
                        scrolled ? 'text-gray-700' : 'text-white'
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
                        scrolled ? 'text-gray-600 hover:text-red-600' : 'text-white hover:text-red-400'
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
                      className={`font-medium transition-colors flex items-center gap-2 ${
                        scrolled ? 'text-gray-700 hover:text-orange-600' : 'text-white hover:text-orange-300'
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
                      className="bg-orange-500 text-white px-4 py-2 rounded-full font-medium hover:bg-orange-600 transition-colors flex items-center gap-2"
                    >
                      {navigating ? (
                        <div className="animate-spin rounded-full h-4 w-4 border-t-2 border-white"></div>
                      ) : null}
                      Sign Up
                    </Link>
                  </div>
                )}
              </div>

              {/* Mobile Menu Button */}
              <div className="md:hidden flex items-center space-x-2">
                <Link href="/cart" className={`relative p-2 rounded-full ${
                  scrolled ? 'text-gray-700' : 'text-white'
                }`}>
                  <ShoppingCart className="w-5 h-5" />
                  {cartCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-orange-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
                      {cartCount}
                    </span>
                  )}
                </Link>
                <button 
                  onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
                  className={`p-2 rounded-full ${
                    scrolled ? 'text-gray-700' : 'text-white'
                  }`}
                >
                  {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
                </button>
              </div>
            </div>
          </div>

          {/* Mobile Menu */}
          {mobileMenuOpen && (
            <div className={`md:hidden border-t ${
              scrolled ? 'border-gray-200 bg-white' : 'border-white/20 bg-black/40'
            }`}>
              <div className="px-4 py-4 space-y-4">
                {/* Mobile Navigation */}
                {['Menu', 'About', 'Contact'].map(item => (
                  <a key={item} href={`#${item.toLowerCase()}`} 
                     className={`block py-2 font-medium ${
                       scrolled ? 'text-gray-700' : 'text-white'
                     }`}
                     onClick={() => setMobileMenuOpen(false)}>
                    {item}
                  </a>
                ))}
                
                <button 
                  onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
                  className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-3 rounded-full font-medium"
                >
                  Order Now
                </button>
              </div>
            </div>
          )}
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative h-screen flex items-center justify-center overflow-hidden">
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
              className="object-cover brightness-50"
              priority={index === 0}
              unoptimized
            />
          </div>
        ))}
        
        {/* Navigation Arrows */}
        <button
          onClick={prevSlide}
          className="absolute left-6 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/20 hover:bg-white/30 rounded-full backdrop-blur-sm transition-all"
        >
          <ChevronLeft className="w-6 h-6 text-white" />
        </button>
        <button
          onClick={nextSlide}
          className="absolute right-6 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/20 hover:bg-white/30 rounded-full backdrop-blur-sm transition-all"
        >
          <ChevronRight className="w-6 h-6 text-white" />
        </button>
        
        {/* Content */}
        <div className="relative z-10 text-center text-white px-6 max-w-4xl">
          <h1 className="text-5xl md:text-7xl font-bold mb-6">
            Authentic African
            <span className="block text-orange-400">Cuisine</span>
          </h1>
          <p className="text-xl md:text-2xl mb-8 opacity-90">
            Experience the rich taste of Ghana with our traditional recipes passed down through generations
          </p>
          <button 
            onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
            className="bg-orange-500 text-white px-8 py-4 rounded-lg text-lg font-semibold hover:bg-orange-600 transition-colors"
          >
            Explore Our Menu
          </button>
        </div>

        {/* Dots Indicator */}
        <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2 z-20 flex space-x-2">
          {heroImages.map((_, index) => (
            <button
              key={index}
              onClick={() => setCurrentSlide(index)}
              className={`w-3 h-3 rounded-full transition-all ${
                index === currentSlide ? 'bg-orange-500' : 'bg-white/50'
              }`}
            />
          ))}
        </div>
      </section>

      {/* Features */}
      <section className="py-20 bg-amber-50 relative">
        {/* Logo Background Pattern */}
        <div className="absolute inset-0 opacity-5 pointer-events-none" style={{
          backgroundImage: `url('/assets/images/logo.png')`,
          backgroundSize: '150px 150px',
          backgroundRepeat: 'repeat',
          backgroundPosition: 'center'
        }}></div>
        
        <div className="max-w-6xl mx-auto px-6 relative z-10">
          <div className="text-center mb-16">
            <h2 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6">Why Choose Our Authentic African Cuisine</h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">We are passionate about bringing you the most authentic taste of Ghana through traditional recipes, premium ingredients, and exceptional service that honors our rich West African heritage.</p>
          </div>
          
          <div className="grid md:grid-cols-3 gap-12">
            {[
              { 
                icon: '🍽️', 
                title: 'Premium Fresh Ingredients', 
                desc: 'We carefully source the finest, freshest ingredients daily from trusted local suppliers and authentic African markets to ensure every dish captures the true essence of traditional Ghanaian flavors.'
              },
              { 
                icon: '👨‍🍳', 
                title: 'Master Chefs & Traditional Methods', 
                desc: 'Our experienced chefs bring decades of culinary expertise and generations of family recipes, using time-honored cooking techniques passed down through West African traditions.'
              },
              { 
                icon: '⭐', 
                title: 'Award-Winning Excellence', 
                desc: 'Proudly rated 4.9/5 stars by thousands of satisfied customers who trust us to deliver exceptional authentic African cuisine with outstanding service and unmatched quality.'
              },
            ].map((item, index) => (
              <div key={item.title} className="group text-center">
                <div className="w-24 h-24 bg-gradient-to-br from-orange-50 to-red-100 rounded-3xl flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-all duration-300 shadow-lg group-hover:shadow-xl">
                  <span className="text-4xl relative z-10">{item.icon}</span>
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-4">{item.title}</h3>
                <p className="text-gray-600 leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Popular Items Section */}
      <section className="py-20 bg-gradient-to-br from-orange-50 to-red-50 relative overflow-hidden">
        <div className="absolute inset-0 opacity-5 pointer-events-none" style={{
          backgroundImage: `url('/assets/images/logo.png')`,
          backgroundSize: '120px 120px',
          backgroundRepeat: 'repeat',
          backgroundPosition: 'center'
        }}></div>
        
        <div className="max-w-6xl mx-auto px-6 relative z-10">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-3 bg-gradient-to-r from-red-500 to-orange-500 text-white px-6 py-3 rounded-full shadow-lg mb-6">
              <span className="text-2xl">🔥</span>
              <span className="font-bold">POPULAR ITEMS</span>
            </div>
            <h2 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6">Customer Favorites</h2>
            <p className="text-xl text-gray-700 max-w-3xl mx-auto leading-relaxed">Discover the dishes our customers can't get enough of!</p>
          </div>

          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500 mx-auto"></div>
            </div>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
              {getPopularItems().map((meal, index) => (
                <div key={meal.id} className="relative bg-white rounded-xl shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer transform hover:scale-105"
                     onClick={() => {
                       const mealData = encodeURIComponent(JSON.stringify(meal))
                       window.location.href = `/meal?meal=${mealData}`
                     }}>
                  {/* Popular Badge */}
                  <div className="absolute top-4 left-4 z-10 bg-gradient-to-r from-red-500 to-orange-500 text-white px-3 py-1 rounded-full text-sm font-bold shadow-lg">
                    #{index + 1} Popular
                  </div>
                  
                  <div className="relative h-48 overflow-hidden rounded-t-xl">
                    <Image
                      src={getImageUrl(meal)}
                      alt={meal.name}
                      fill
                      className="object-cover group-hover:scale-105 transition-transform duration-300"
                      unoptimized
                    />
                    
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        toggleFavorite(meal.id)
                      }}
                      className="absolute top-4 right-4 p-2 bg-white/90 backdrop-blur rounded-full shadow-md hover:shadow-lg transition-all"
                    >
                      <Heart className={`w-4 h-4 ${favorites.has(meal.id) ? 'fill-red-500 text-red-500' : 'text-gray-600'}`} />
                    </button>
                  </div>

                  <div className="p-6">
                    <h3 className="text-xl font-bold text-gray-900 mb-2">{meal.name}</h3>
                    <p className="text-gray-600 mb-4 text-sm leading-relaxed line-clamp-2">{meal.description}</p>

                    <div className="flex items-center justify-between">
                      <span className="text-2xl font-bold text-orange-600">${meal.price?.toFixed(2)}</span>
                      <button
                        onClick={async (e) => {
                          e.stopPropagation()
                          setNavigating(true)
                          const mealData = encodeURIComponent(JSON.stringify(meal))
                          window.location.href = `/meal?meal=${mealData}`
                        }}
                        disabled={navigating}
                        className="px-4 py-2 bg-orange-500 text-white rounded-lg font-medium text-sm hover:bg-orange-600 transition-all flex items-center gap-2 disabled:opacity-70"
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
          
          <div className="text-center mt-12">
            <button 
              onClick={() => document.getElementById('menu')?.scrollIntoView({ behavior: 'smooth' })}
              className="inline-flex items-center gap-2 bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-4 rounded-2xl font-bold hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
            >
              <span>🍽️</span> View Full Menu
            </button>
          </div>
        </div>
      </section>

      {/* Menu Section */}
      <section id="menu" className="py-20 bg-amber-50 relative">
        {/* Logo Background Pattern */}
        <div className="absolute inset-0 opacity-3 pointer-events-none" style={{
          backgroundImage: `url('/assets/images/logo.png')`,
          backgroundSize: '200px 200px',
          backgroundRepeat: 'repeat',
          backgroundPosition: 'center'
        }}></div>
        
        <div className="max-w-6xl mx-auto px-6 relative z-10">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-3 bg-orange-500 text-white px-6 py-3 rounded-full shadow-lg mb-6">
              <span className="text-2xl">🍽️</span>
              <span className="font-bold">SIGNATURE DISHES</span>
            </div>
            <h2 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6">Our Authentic Menu</h2>
            <p className="text-xl text-gray-700 max-w-3xl mx-auto leading-relaxed">Traditional Ghanaian dishes prepared with authentic spices and time-honored cooking methods.</p>
            <button 
              onClick={refreshMeals}
              className="mt-4 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 transition-colors"
            >
              Refresh Menu
            </button>
          </div>

          {loading ? (
            <div className="text-center py-20">
              <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500 mx-auto"></div>
            </div>
          ) : meals.length === 0 ? (
            <p className="text-center text-gray-500 py-20">No meals available at the moment.</p>
          ) : searchQuery && filteredMeals.length === 0 ? (
            <div className="text-center py-20">
              <p className="text-xl text-gray-600 mb-4">No meals found for &ldquo;{searchQuery}&rdquo;</p>
              <p className="text-gray-500">Try searching for a different dish name.</p>
            </div>
          ) : (
            <div className="space-y-16">
              {/* Group meals by category dynamically */}
              {(() => {
                const mealsToShow = searchQuery ? filteredMeals : meals
                const categorizedMeals = mealsToShow.reduce((acc, meal) => {
                  const category = meal.category || 'Main Dishes'
                  if (!acc[category]) acc[category] = []
                  acc[category].push(meal)
                  return acc
                }, {} as Record<string, Meal[]>)
                
                const sortedCategories = Object.keys(categorizedMeals).sort((a, b) => {
                  const order = ['Main Dishes', 'Side Dishes', 'Appetizer', 'Appetizers', 'Starters', 'Dessert', 'Desserts', 'Beverage', 'Beverages', 'Drinks']
                  const aIndex = order.indexOf(a)
                  const bIndex = order.indexOf(b)
                  if (aIndex === -1 && bIndex === -1) return a.localeCompare(b)
                  if (aIndex === -1) return 1
                  if (bIndex === -1) return -1
                  return aIndex - bIndex
                })
                
                return sortedCategories.map((category) => (
                  <div key={category} className="">
                    <div className="text-center mb-12">
                      <h3 className="text-3xl font-bold text-gray-900 mb-2">{category}</h3>
                      <div className="w-24 h-1 bg-orange-500 mx-auto rounded-full"></div>
                    </div>
                    
                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
                      {categorizedMeals[category].map((meal, index) => (
                          <div key={meal.id} className="relative bg-white rounded-xl shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer"
                               onClick={() => {
                                 const mealData = encodeURIComponent(JSON.stringify(meal))
                                 window.location.href = `/meal?meal=${mealData}`
                               }}>
                            <div className="relative h-48 overflow-hidden rounded-t-xl">
                              <Image
                                src={getImageUrl(meal)}
                                alt={meal.name}
                                fill
                                className="object-cover group-hover:scale-105 transition-transform duration-300"
                                unoptimized
                                onError={(e) => {
                                  const target = e.currentTarget as HTMLImageElement
                                  if (target) {
                                    target.src = '/assets/images/logo.png'
                                  }
                                }}
                              />
                              {meal.available === false && (
                                <div className="absolute inset-0 bg-black/60 flex items-center justify-center">
                                  <span className="bg-red-500 text-white px-4 py-2 rounded-full font-bold text-sm">
                                    Out of Stock
                                  </span>
                                </div>
                              )}
                              <button
                                onClick={(e) => {
                                  e.stopPropagation()
                                  toggleFavorite(meal.id)
                                }}
                                className="absolute top-4 right-4 p-2 bg-white/90 backdrop-blur rounded-full shadow-md hover:shadow-lg transition-all"
                              >
                                <Heart className={`w-4 h-4 ${favorites.has(meal.id) ? 'fill-red-500 text-red-500' : 'text-gray-600'}`} />
                              </button>
                            </div>

                            <div className="p-6">
                              <h3 className="text-xl font-bold text-gray-900 mb-2">{meal.name}</h3>
                              <p className="text-gray-600 mb-4 text-sm leading-relaxed line-clamp-2">{meal.description}</p>

                              <div className="flex items-center justify-between">
                                <div>
                                  <span className="text-2xl font-bold text-orange-600">${meal.price?.toFixed(2)}</span>
                                  {meal.preparationTime && (
                                    <div className="flex items-center mt-1">
                                      <Clock className="w-3 h-3 mr-1 text-gray-400" />
                                      <span className="text-xs text-gray-500">{meal.preparationTime} min</span>
                                    </div>
                                  )}
                                </div>
                                <button
                                  onClick={async (e) => {
                                    e.stopPropagation()
                                    const mealData = encodeURIComponent(JSON.stringify(meal))
                                    window.location.href = `/meal?meal=${mealData}`
                                  }}
                                  disabled={meal.available === false || !restaurantStatus.isOpen}
                                  className={`px-4 py-2 rounded-lg font-medium text-sm flex items-center gap-2 transition-all ${
                                    meal.available !== false && restaurantStatus.isOpen
                                      ? 'bg-orange-500 text-white hover:bg-orange-600'
                                      : 'bg-gray-200 text-gray-500 cursor-not-allowed'
                                  } disabled:opacity-70`}
                                >
                                  <Plus className="w-4 h-4" />
                                  {!restaurantStatus.isOpen ? 'Closed' : 'Add'}
                                </button>
                              </div>
                            </div>
                          </div>
                      ))}
                    </div>
                  </div>
                ))
              })()}
            </div>
          )}
        </div>
      </section>

      {/* About Section */}
      <section id="about" className="py-20 bg-gray-900 text-white">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid md:grid-cols-3 gap-12 text-center mb-16">
            <div className="group">
              <div className="w-20 h-20 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-all">
                <span className="text-3xl">🇬🇭</span>
              </div>
              <h3 className="text-2xl font-bold text-orange-400 mb-2">Born in Ghana</h3>
              <p className="text-gray-300">Authentic recipes from Accra, brought to Connecticut with love and tradition</p>
            </div>
            <div className="group">
              <div className="w-20 h-20 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-all">
                <span className="text-3xl">👨‍👩‍👧‍👦</span>
              </div>
              <h3 className="text-2xl font-bold text-orange-400 mb-2">Family Legacy</h3>
              <p className="text-gray-300">Three generations of culinary wisdom passed down through our family kitchen</p>
            </div>
            <div className="group">
              <div className="w-20 h-20 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-all">
                <span className="text-3xl">🌶️</span>
              </div>
              <h3 className="text-2xl font-bold text-orange-400 mb-2">Authentic Spices</h3>
              <p className="text-gray-300">Imported seasonings and traditional cooking methods for genuine West African flavors</p>
            </div>
          </div>

          <div className="grid lg:grid-cols-2 gap-16 items-center">
            <div>
              <h2 className="text-4xl font-bold mb-6">About Us</h2>
              <p className="text-gray-300 mb-6 text-lg">
                At Taste of African Cuisine, we take pride in serving the most authentic West African foods. Our dishes are prepared using traditional recipes that have been passed down from generation to generation.
              </p>
              <p className="text-gray-300 mb-6 text-lg">
                We use only the freshest ingredients to ensure that every dish is bursting with flavor. Whether you're a fan of jollof rice, Waakye or Banku we have something for everyone.
              </p>
              <p className="text-gray-300 text-lg">
                Come and experience the taste of West Africa today!
              </p>
            </div>
            <div className="space-y-6">
              <div className="bg-gradient-to-r from-orange-500/20 to-red-500/20 rounded-2xl p-6 border border-orange-500/30">
                <h4 className="text-xl font-bold text-orange-400 mb-3">🏆 Community Recognition</h4>
                <p className="text-gray-300">Featured in Hartford Courant as "Connecticut's Hidden Gem for Authentic African Cuisine"</p>
              </div>
              <div className="bg-gradient-to-r from-orange-500/20 to-red-500/20 rounded-2xl p-6 border border-orange-500/30">
                <h4 className="text-xl font-bold text-orange-400 mb-3">🌍 Cultural Bridge</h4>
                <p className="text-gray-300">Proudly serving both homesick Africans and curious food adventurers since opening</p>
              </div>
              <div className="bg-gradient-to-r from-orange-500/20 to-red-500/20 rounded-2xl p-6 border border-orange-500/30">
                <h4 className="text-xl font-bold text-orange-400 mb-3">💚 Fresh Daily</h4>
                <p className="text-gray-300">Every sauce, stew, and seasoning made fresh each morning using traditional methods</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Customer Reviews Section */}
      <section className="py-20 bg-gradient-to-br from-yellow-50 to-orange-50 relative overflow-hidden">
        <div className="absolute inset-0 opacity-5 pointer-events-none" style={{
          backgroundImage: `url('/assets/images/logo.png')`,
          backgroundSize: '100px 100px',
          backgroundRepeat: 'repeat',
          backgroundPosition: 'center'
        }}></div>
        
        <div className="max-w-6xl mx-auto px-6 relative z-10">
          <div className="text-center mb-16">
            <div className="inline-flex items-center gap-3 bg-gradient-to-r from-yellow-500 to-orange-500 text-white px-6 py-3 rounded-full shadow-lg mb-6">
              <span className="text-2xl">⭐</span>
              <span className="font-bold">CUSTOMER REVIEWS</span>
            </div>
            <h2 className="text-4xl md:text-5xl font-bold text-gray-900 mb-6">What Our Customers Say</h2>
            <p className="text-xl text-gray-600 max-w-3xl mx-auto">Real reviews from our valued customers who love our authentic African cuisine</p>
          </div>

          {/* Reviews Carousel */}
          <div className="relative">
            {/* Navigation Arrows */}
            <button
              onClick={prevReview}
              className="absolute left-0 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/90 hover:bg-white rounded-full shadow-lg hover:shadow-xl transition-all backdrop-blur-sm border border-orange-200"
            >
              <ChevronLeft className="w-6 h-6 text-orange-600" />
            </button>
            <button
              onClick={nextReview}
              className="absolute right-0 top-1/2 transform -translate-y-1/2 z-20 p-3 bg-white/90 hover:bg-white rounded-full shadow-lg hover:shadow-xl transition-all backdrop-blur-sm border border-orange-200"
            >
              <ChevronRight className="w-6 h-6 text-orange-600" />
            </button>

            {/* Reviews Container */}
            <div className="overflow-hidden rounded-3xl">
              <div 
                className="flex transition-transform duration-700 ease-in-out"
                style={{ transform: `translateX(-${currentReview * 100}%)` }}
              >
                {reviews.map((review, index) => (
                  <div key={index} className="w-full flex-shrink-0 px-4">
                    <div className="bg-white/80 backdrop-blur-sm rounded-3xl p-8 shadow-xl border border-orange-200 mx-auto max-w-4xl">
                      <div className="text-center">
                        {/* Stars */}
                        <div className="flex justify-center mb-6">
                          {[...Array(review.rating)].map((_, i) => (
                            <span key={i} className="text-3xl text-yellow-500">⭐</span>
                          ))}
                        </div>
                        
                        {/* Review Text */}
                        <blockquote className="text-xl md:text-2xl text-gray-700 mb-8 leading-relaxed font-medium italic">
                          "{review.review}"
                        </blockquote>
                        
                        {/* Customer Info */}
                        <div className="flex items-center justify-center space-x-4">
                          <div className="w-16 h-16 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center text-white font-bold text-xl shadow-lg">
                            {review.name.charAt(0)}
                          </div>
                          <div className="text-left">
                            <h4 className="text-xl font-bold text-gray-900">{review.name}</h4>
                            <div className="flex items-center space-x-3 text-sm text-gray-600">
                              <span className="bg-orange-500 text-white px-3 py-1 rounded-full font-medium">{review.dish}</span>
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
            <div className="flex justify-center mt-8 space-x-2">
              {reviews.map((_, index) => (
                <button
                  key={index}
                  onClick={() => setCurrentReview(index)}
                  className={`w-3 h-3 rounded-full transition-all duration-300 ${
                    index === currentReview 
                      ? 'bg-orange-500 w-8' 
                      : 'bg-orange-200 hover:bg-orange-300'
                  }`}
                />
              ))}
            </div>
          </div>
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
      <footer id="contact" className="bg-gray-800 text-white py-16">
        <div className="max-w-6xl mx-auto px-6">
          <div className="grid md:grid-cols-3 gap-12">
            <div>
              <div className="flex items-center space-x-3 mb-6">
                <Image
                  src="/assets/images/logo.png"
                  alt="Logo"
                  width={50}
                  height={50}
                  className="object-contain"
                  unoptimized
                />
                <div>
                  <h3 className="text-2xl font-bold">Taste of African Cuisine</h3>
                  <p className="text-orange-400">Authentic Ghanaian Food</p>
                </div>
              </div>
              <p className="text-gray-300 leading-relaxed">
                Bringing authentic West African flavors to your doorstep with love and tradition.
              </p>
            </div>

            <div>
              <h4 className="text-xl font-bold mb-6 text-orange-400">Contact Us</h4>
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <Phone className="w-5 h-5 text-orange-400" />
                  <a href="tel:(929) 456-3215" className="text-gray-300 hover:text-orange-400 transition-colors font-medium underline decoration-dotted">
                    (929) 456-3215
                  </a>
                </div>
                <div className="flex items-start gap-3">
                  <MapPin className="w-5 h-5 text-orange-400 mt-0.5" />
                  <a href="https://maps.google.com/?q=200+Hartford+Turnpike,+Vernon,+CT" target="_blank" rel="noopener noreferrer" className="text-gray-300 hover:text-orange-400 transition-colors font-medium underline decoration-dotted">
                    200 Hartford Turnpike<br />Vernon, CT
                  </a>
                </div>
                <div className="text-gray-300">
                  tasteofafricancuisine01@gmail.com
                </div>
              </div>
            </div>

            <div>
              <h4 className="text-xl font-bold mb-6 text-orange-400">Hours & Social</h4>
              <div className="space-y-3 mb-6">
                <div className="text-gray-300">
                  <span className="font-medium text-white">Tue–Sat:</span> 11:00 AM – 8:00 PM
                </div>
                <div className="text-gray-300">
                  <span className="font-medium text-white">Sun & Mon:</span> <span className="text-red-400">Closed</span>
                </div>
              </div>
              
              <div className="flex items-center gap-4">
                <a href="https://www.instagram.com/tasteofafrican_cuisinee/?hl=en" target="_blank" rel="noopener noreferrer" className="bg-orange-500 hover:bg-orange-600 p-3 rounded-full transition-colors">
                  <Instagram className="w-6 h-6 text-white" />
                </a>
                <a href="https://www.facebook.com/people/Taste-Africa-Cuisine/pfbid01DpatNS1oHWsXCiHAEXQHirTRAyHbYqbRxhXVqw8htbCLe8H5S4CkspKmGnAhmgLl/?mibextid=7cd5pb" target="_blank" rel="noopener noreferrer" className="bg-blue-600 hover:bg-blue-700 p-3 rounded-full transition-colors">
                  <Facebook className="w-6 h-6 text-white" />
                </a>
              </div>
            </div>
          </div>

          <div className="border-t border-gray-700 mt-12 pt-8 text-center">
            <p className="text-gray-400">
              © 2025 Taste of African Cuisine. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  )
}