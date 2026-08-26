'use client'

import { useState, useEffect, Suspense } from 'react'
import { useAuth } from '@/lib/AuthContext'
import { orderService, type Order } from '@/lib/orderService'
import { Clock, CheckCircle, Truck, Package, MapPin, Star, ArrowLeft, ChefHat, Phone } from 'lucide-react'
import Link from 'next/link'
import Reviews from '@/components/Reviews'
import { useSearchParams } from 'next/navigation'

function OrdersContent() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(true)
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null)
  const [trackingOrder, setTrackingOrder] = useState<string | null>(null)
  const { user } = useAuth()
  const searchParams = useSearchParams()

  useEffect(() => {
    const trackId = searchParams.get('track')
    if (trackId) {
      setTrackingOrder(trackId)
    }
  }, [searchParams])

  useEffect(() => {
    if (!user) return

    const unsubscribe = orderService.onOrderUpdates(user.uid, (fetchedOrders) => {
      setOrders(fetchedOrders)
      setLoading(false)
    })

    return () => unsubscribe()
  }, [user])

  const getStatusIcon = (status: Order['status']) => {
    switch (status) {
      case 'confirmed': return <Clock className="w-5 h-5 text-gold" />
      case 'preparing': return <Package className="w-5 h-5 text-blue-500" />
      case 'ready': return <CheckCircle className="w-5 h-5 text-kente" />
      case 'out_for_delivery': return <Truck className="w-5 h-5 text-purple-500" />
      case 'delivered': case 'completed': return <CheckCircle className="w-5 h-5 text-kente" />
    }
  }

  const getStatusText = (status: Order['status']) => {
    switch (status) {
      case 'confirmed': return 'Order Confirmed'
      case 'preparing': return 'Preparing Your Order'
      case 'ready': return 'Ready for Pickup'
      case 'out_for_delivery': return 'Out for Delivery'
      case 'delivered': return 'Delivered'
      case 'completed': return 'Completed'
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold"></div>
      </div>
    )
  }

  // If tracking a specific order, show tracking view
  if (trackingOrder) {
    const order = orders.find(o => o.id === trackingOrder)
    if (!order) {
      return (
        <div className="min-h-screen bg-sand-100 flex items-center justify-center">
          <div className="text-center">
            <h1 className="font-display text-2xl text-ink mb-4">Order Not Found</h1>
            <Link href="/orders" className="text-gold-600 hover:text-gold-600">Back to Orders</Link>
          </div>
        </div>
      )
    }

    const steps = [
      { status: 'confirmed', icon: CheckCircle, title: 'Order Confirmed', desc: 'We received your order' },
      { status: 'preparing', icon: ChefHat, title: 'Preparing', desc: 'Our chefs are cooking your meal' },
      { status: 'ready', icon: Package, title: order.orderType === 'delivery' ? 'Ready for Delivery' : 'Ready for Pickup', desc: order.orderType === 'delivery' ? 'Order is ready to be delivered' : 'Your order is ready for pickup' },
      ...(order.orderType === 'delivery' ? [
        { status: 'out_for_delivery', icon: Truck, title: 'Out for Delivery', desc: 'Your order is on the way' },
        { status: 'delivered', icon: CheckCircle, title: 'Delivered', desc: 'Order has been delivered' }
      ] : [
        { status: 'completed', icon: CheckCircle, title: 'Completed', desc: 'Order has been picked up' }
      ])
    ]

    const currentStepIndex = steps.findIndex(step => step.status === order.status)

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
        
        <div className="relative z-10 page-shell px-4 py-8">
          <div className="mb-6">
            <button 
              onClick={() => {
                window.location.href = '/orders'
              }}
              className="inline-flex items-center gap-2 text-gold-600 hover:text-gold-600 mb-4 bg-white/80 backdrop-blur-sm px-4 py-2 rounded-full shadow-card hover:shadow-card transition-all"
            >
              <ArrowLeft className="w-4 h-4" /> Back to Orders
            </button>
          </div>
          
          <div className="bg-white/80 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 mb-6">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-16 h-16 bg-sand-200 rounded-full flex items-center justify-center">
                <img src="/assets/images/logo.png" alt="Logo" className="w-10 h-10 object-contain" />
              </div>
              <div>
                <h1 className="font-display text-3xl text-ink mb-1">Order #{order.orderNumber}</h1>
                <p className="text-gold-600 font-semibold">Live Order Tracking</p>
              </div>
            </div>
            <div className="flex justify-between items-center bg-sand-100 rounded-card p-4">
              <div>
                <p className="text-ink font-bold text-lg">{order.customerInfo.name}</p>
                <p className="text-sand-700 font-semibold flex items-center gap-2">
                  {order.orderType === 'delivery' ? (
                    <><Truck className="w-4 h-4" /> Delivery Order</>
                  ) : (
                    <><MapPin className="w-4 h-4" /> Pickup Order</>
                  )}
                </p>
              </div>
              <div className="text-right">
                <div className="font-display text-2xl text-gold-600">${order.total.toFixed(2)}</div>
                <div className="text-sm text-sand-500">Total Amount</div>
              </div>
            </div>
          </div>

          <div className="bg-white/80 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8 mb-6">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-sand-200 rounded-full flex items-center justify-center">
                <Clock className="w-6 h-6 text-gold-600" />
              </div>
              <h2 className="font-display text-2xl text-ink">Order Progress</h2>
            </div>
            
            <div className="space-y-4">
              {steps.map((step, index) => {
                const isCompleted = index <= currentStepIndex
                const isCurrent = index === currentStepIndex
                const Icon = step.icon

                return (
                  <div key={step.status} className="flex items-center relative">
                    <div className={`w-12 h-12 rounded-full flex items-center justify-center border-3 shadow-card transition-all duration-500 ${
                      isCompleted 
                        ? 'bg-gold border-gold text-white transform scale-110' 
                        : 'bg-white border-sand-200 text-sand-500'
                    }`}>
                      <Icon className="w-6 h-6" />
                    </div>
                    {index < steps.length - 1 && (
                      <div className={`absolute left-6 top-12 w-0.5 h-8 transition-all duration-500 ${
                        index < currentStepIndex ? 'bg-gold' : 'bg-sand-200'
                      }`} />
                    )}
                    <div className="ml-6 flex-1">
                      <div className={`font-bold text-lg transition-all duration-300 ${
                        isCompleted ? 'text-ink' : 'text-sand-500'
                      }`}>
                        {step.title}
                      </div>
                      <div className={`text-sm font-medium transition-all duration-300 ${
                        isCompleted ? 'text-sand-700' : 'text-sand-500'
                      }`}>
                        {step.desc}
                      </div>
                      {isCurrent && (
                        <div className="flex items-center gap-2 text-sm font-bold text-gold-600 mt-2 animate-pulse">
                          <div className="w-2 h-2 bg-gold rounded-full animate-ping"></div>
                          Current Status
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          <div className="bg-white/80 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-sand-100 rounded-full flex items-center justify-center">
                <Phone className="w-6 h-6 text-blue-600" />
              </div>
              <h3 className="text-xl font-bold text-ink">Need Help?</h3>
            </div>
            <div className="space-y-4">
              <div className="flex items-center gap-4 p-4 bg-sand-100 rounded-card border border-blue-200">
                <Phone className="w-6 h-6 text-blue-500" />
                <div>
                  <div className="font-bold text-ink">Call Us Directly</div>
                  <a href="tel:+18608055121" className="text-blue-600 font-bold hover:text-blue-700 text-lg">
                    (860) 805-5121
                  </a>
                </div>
              </div>
              {order.orderType === 'delivery' && order.uberTrackingUrl && (
                <a
                  href={order.uberTrackingUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="flex items-center gap-4 p-4 bg-sand-100 rounded-card border border-purple-200 hover:border-purple-400 transition-colors"
                >
                  <Truck className="w-6 h-6 text-purple-500" />
                  <div>
                    <div className="font-bold text-ink">Live Courier Tracking</div>
                    <span className="text-purple-600 font-bold">Follow your delivery on Uber →</span>
                  </div>
                </a>
              )}
              {order.orderType === 'delivery' && order.deliveryAddress && (
                <div className="flex items-start gap-4 p-4 bg-sand-100 rounded-card border border-kente-50">
                  <MapPin className="w-6 h-6 text-kente mt-1" />
                  <div>
                    <div className="font-bold text-ink mb-1">Delivery Address</div>
                    <div className="text-sand-700 font-medium">{order.deliveryAddress}</div>
                  </div>
                </div>
              )}
            </div>
          </div>
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
      
      <div className="relative z-10 page-shell px-4 py-8">
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-4">
            <Link href="/" className="p-3 hover:bg-gold-50 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-gold-600" />
            </Link>
            <div>
              <h1 className="font-display text-3xl text-ink mb-2">Your Orders</h1>
              <p className="text-sand-700 font-bold">Track your order status in real-time</p>
            </div>
          </div>
        </div>

        {orders.length === 0 ? (
          <div className="bg-white/80 backdrop-blur-sm rounded-card shadow-2xl border border-gold-300 p-12 text-center">
            <div className="w-24 h-24 bg-sand-200 rounded-full flex items-center justify-center mx-auto mb-6">
              <Package className="w-12 h-12 text-gold" />
            </div>
            <h2 className="font-display text-2xl text-ink mb-3">No orders yet</h2>
            <p className="text-sand-700 mb-8 text-lg">Start your culinary journey with authentic Ghanaian flavors!</p>
            <Link
              href="/"
              className="inline-flex items-center gap-2 bg-gold text-white px-8 py-4 rounded-card font-bold hover:bg-gold-600 transition-all shadow-card"
            >
              <span>🍽️</span> Browse Menu
            </Link>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Stats Overview */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
              <div className="bg-white/80 backdrop-blur-sm rounded-card p-6 border border-gold-300 shadow-card">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-gold-50 rounded-full flex items-center justify-center">
                    <Package className="w-6 h-6 text-gold-600" />
                  </div>
                  <div>
                    <div className="font-display text-2xl text-ink">{orders.length}</div>
                    <div className="text-sm text-sand-700">Total Orders</div>
                  </div>
                </div>
              </div>
              <div className="bg-white/80 backdrop-blur-sm rounded-card p-6 border border-kente-50 shadow-card">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-kente-50 rounded-full flex items-center justify-center">
                    <CheckCircle className="w-6 h-6 text-kente" />
                  </div>
                  <div>
                    <div className="font-display text-2xl text-ink">
                      {orders.filter(o => ['delivered', 'completed'].includes(o.status)).length}
                    </div>
                    <div className="text-sm text-sand-700">Completed</div>
                  </div>
                </div>
              </div>
              <div className="bg-white/80 backdrop-blur-sm rounded-card p-6 border border-blue-200 shadow-card">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                    <span className="text-xl">💰</span>
                  </div>
                  <div>
                    <div className="font-display text-2xl text-ink">
                      ${orders.reduce((sum, order) => sum + order.total, 0).toFixed(0)}
                    </div>
                    <div className="text-sm text-sand-700">Total Spent</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Orders List */}
            {orders.map((order) => {
              const isCompleted = ['delivered', 'completed'].includes(order.status)
              const isActive = !isCompleted
              
              return (
                <div key={order.id} className={`bg-white/80 backdrop-blur-sm rounded-card shadow-card border p-6 transition-all  ${
                  isActive ? 'border-gold bg-gold-50' : 'border-sand-200'
                }`}>
                  {/* Header */}
                  <div className="flex flex-col md:flex-row md:justify-between md:items-start gap-4 mb-6">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-xl font-bold text-ink">Order #{order.orderNumber}</h3>
                        {isActive && (
                          <span className="px-3 py-1 bg-gold text-white text-xs font-bold rounded-full animate-pulse">
                            ACTIVE
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-4 text-sm text-sand-700">
                        <span className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {new Date(order.createdAt).toLocaleDateString('en-US', {
                            weekday: 'short',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </span>
                        <span className="flex items-center gap-1">
                          {order.orderType === 'delivery' ? (
                            <><Truck className="w-4 h-4" /> Delivery</>
                          ) : (
                            <><MapPin className="w-4 h-4" /> Pickup</>
                          )}
                        </span>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className="flex items-center gap-2 mb-2">
                        {getStatusIcon(order.status)}
                        <span className="font-bold text-ink">{getStatusText(order.status)}</span>
                      </div>
                      <div className="font-display text-2xl text-gold-600 mb-3">${order.total.toFixed(2)}</div>
                      
                      <div className="flex flex-col gap-2">
                        {isActive && (
                          <Link
                            href={`/orders?track=${order.id}`}
                            className="px-4 py-2 bg-gold text-white rounded-xl text-sm font-bold hover:bg-gold-600 transition-all shadow-card"
                          >
                            🔍 Track Order
                          </Link>
                        )}
                        
                        {isCompleted && (
                          <button
                            onClick={() => setExpandedOrder(expandedOrder === order.id ? null : order.id!)}
                            className="px-4 py-2 bg-sand-100 text-white rounded-xl text-sm font-bold transition-all  shadow-card"
                          >
                            {expandedOrder === order.id ? '⭐ Hide Reviews' : '⭐ Write Reviews'}
                          </button>
                        )}
                        
                        <button
                          onClick={() => {
                            // Reorder functionality
                            const cartItems = order.items.map(item => ({ ...item, quantity: item.quantity }))
                            localStorage.setItem('cart', JSON.stringify(cartItems))
                            window.location.href = '/cart'
                          }}
                          className="px-4 py-2 bg-kente text-white rounded-xl text-sm font-bold transition-all  shadow-card"
                        >
                          🔄 Reorder
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Progress Bar for Active Orders */}
                  {isActive && (
                    <div className="mb-6">
                      <div className="flex justify-between text-xs text-sand-700 mb-2">
                        <span>Confirmed</span>
                        <span>Preparing</span>
                        <span>Ready</span>
                        {order.orderType === 'delivery' && <span>Delivering</span>}
                        <span>Complete</span>
                      </div>
                      <div className="w-full bg-sand-200 rounded-full h-3 shadow-inner">
                        <div 
                          className="bg-gold h-3 rounded-full transition-all duration-1000 shadow-card"
                          style={{ 
                            width: `${(
                              order.status === 'confirmed' ? 20 :
                              order.status === 'preparing' ? 40 :
                              order.status === 'ready' ? 60 :
                              order.status === 'out_for_delivery' ? 80 :
                              100
                            )}%` 
                          }}
                        ></div>
                      </div>
                    </div>
                  )}

                  {/* Order Details */}
                  <div className="grid md:grid-cols-2 gap-6">
                    <div className="bg-white/60 rounded-card p-4 border border-sand-200">
                      <h4 className="font-bold text-ink mb-3 flex items-center gap-2">
                        <span>🍽️</span> Order Items ({order.items.length})
                      </h4>
                      <div className="space-y-2 max-h-32 overflow-y-auto">
                        {order.items.map((item, index) => (
                          <div key={index} className="flex justify-between items-center py-1 border-b border-sand-200 last:border-0">
                            <span className="text-ink-soft font-medium">{item.quantity}x {item.name}</span>
                            <span className="font-bold text-ink">${(item.price * item.quantity).toFixed(2)}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="bg-white/60 rounded-card p-4 border border-sand-200">
                      <h4 className="font-bold text-ink mb-3 flex items-center gap-2">
                        {order.orderType === 'delivery' ? (
                          <><span>🚚</span> Delivery Info</>
                        ) : (
                          <><span>🏪</span> Pickup Info</>
                        )}
                      </h4>
                      {order.orderType === 'delivery' ? (
                        <div className="space-y-2">
                          <div className="flex items-start gap-2">
                            <MapPin className="w-4 h-4 text-gold mt-1" />
                            <span className="text-ink-soft text-sm">{order.deliveryAddress}</span>
                          </div>
                          <div className="text-xs text-sand-500">Delivery Fee: ${order.deliveryFee.toFixed(2)}</div>
                        </div>
                      ) : (
                        <div className="space-y-2">
                          <div className="flex items-start gap-2">
                            <MapPin className="w-4 h-4 text-gold mt-1" />
                            <div className="text-sm">
                              <div className="font-medium text-ink-soft">Taste of African Cuisine</div>
                              <div className="text-sand-700">200 Hartford Turnpike, Vernon, CT</div>
                            </div>
                          </div>
                          <div className="text-xs text-sand-500">Ready for pickup when notified</div>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  {/* Reviews Section — one review per order, shared with the
                      mobile app and admin panel via Supabase order_reviews */}
                  {expandedOrder === order.id && isCompleted && order.id && (
                    <div className="mt-6 pt-6 border-t border-sand-200">
                      <h4 className="font-bold text-ink mb-4 flex items-center gap-2">
                        <span>⭐</span> Rate Your Experience
                      </h4>
                      <Reviews
                        orderId={order.id}
                        orderLabel={`Order #${order.orderNumber}`}
                        userCanReview={true}
                      />
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}

export default function OrdersPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-sand-50 flex items-center justify-center">
          <div className="w-8 h-8 border-2 border-sand-300 border-t-gold rounded-full animate-spin" />
        </div>
      }
    >
      <OrdersContent />
    </Suspense>
  )
}
