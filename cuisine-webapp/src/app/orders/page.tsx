'use client'

import { useState, useEffect } from 'react'
import { useAuth } from '@/lib/AuthContext'
import { orderService, type Order } from '@/lib/orderService'
import { Clock, CheckCircle, Truck, Package, MapPin, Star, ArrowLeft, ChefHat, Phone } from 'lucide-react'
import Link from 'next/link'
import Reviews from '@/components/Reviews'
import { useSearchParams } from 'next/navigation'

export default function OrdersPage() {
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
      case 'confirmed': return <Clock className="w-5 h-5 text-orange-500" />
      case 'preparing': return <Package className="w-5 h-5 text-blue-500" />
      case 'ready': return <CheckCircle className="w-5 h-5 text-green-500" />
      case 'out_for_delivery': return <Truck className="w-5 h-5 text-purple-500" />
      case 'delivered': case 'completed': return <CheckCircle className="w-5 h-5 text-green-600" />
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
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500"></div>
      </div>
    )
  }

  // If tracking a specific order, show tracking view
  if (trackingOrder) {
    const order = orders.find(o => o.id === trackingOrder)
    if (!order) {
      return (
        <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
          <div className="text-center">
            <h1 className="text-2xl font-bold text-gray-900 mb-4">Order Not Found</h1>
            <Link href="/orders" className="text-orange-600 hover:text-orange-700">Back to Orders</Link>
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
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 relative overflow-hidden">
        {/* Background Logo */}
        <div className="fixed inset-0 flex items-center justify-center opacity-5 pointer-events-none z-0">
          <img 
            src="/assets/images/logo.png" 
            alt="Background Logo" 
            className="w-96 h-96 object-contain"
          />
        </div>
        
        <div className="relative z-10 max-w-2xl mx-auto px-4 py-8">
          <div className="mb-6">
            <button 
              onClick={() => {
                window.location.href = '/orders'
              }}
              className="inline-flex items-center gap-2 text-orange-600 hover:text-orange-700 mb-4 bg-white/80 backdrop-blur-sm px-4 py-2 rounded-full shadow-lg hover:shadow-xl transition-all"
            >
              <ArrowLeft className="w-4 h-4" /> Back to Orders
            </button>
          </div>
          
          <div className="bg-white/80 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 mb-6">
            <div className="flex items-center gap-4 mb-4">
              <div className="w-16 h-16 bg-gradient-to-br from-orange-100 to-red-100 rounded-full flex items-center justify-center">
                <img src="/assets/images/logo.png" alt="Logo" className="w-10 h-10 object-contain" />
              </div>
              <div>
                <h1 className="text-3xl font-bold text-gray-900 mb-1">Order #{order.orderNumber}</h1>
                <p className="text-orange-600 font-semibold">Live Order Tracking</p>
              </div>
            </div>
            <div className="flex justify-between items-center bg-gradient-to-r from-orange-50 to-red-50 rounded-2xl p-4">
              <div>
                <p className="text-gray-900 font-bold text-lg">{order.customerInfo.name}</p>
                <p className="text-gray-600 font-semibold flex items-center gap-2">
                  {order.orderType === 'delivery' ? (
                    <><Truck className="w-4 h-4" /> Delivery Order</>
                  ) : (
                    <><MapPin className="w-4 h-4" /> Pickup Order</>
                  )}
                </p>
              </div>
              <div className="text-right">
                <div className="text-2xl font-bold text-orange-600">${order.total.toFixed(2)}</div>
                <div className="text-sm text-gray-500">Total Amount</div>
              </div>
            </div>
          </div>

          <div className="bg-white/80 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8 mb-6">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-orange-100 to-red-100 rounded-full flex items-center justify-center">
                <Clock className="w-6 h-6 text-orange-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Order Progress</h2>
            </div>
            
            <div className="space-y-4">
              {steps.map((step, index) => {
                const isCompleted = index <= currentStepIndex
                const isCurrent = index === currentStepIndex
                const Icon = step.icon

                return (
                  <div key={step.status} className="flex items-center relative">
                    <div className={`w-12 h-12 rounded-full flex items-center justify-center border-3 shadow-lg transition-all duration-500 ${
                      isCompleted 
                        ? 'bg-gradient-to-br from-orange-500 to-red-500 border-orange-500 text-white transform scale-110' 
                        : 'bg-white border-gray-300 text-gray-400'
                    }`}>
                      <Icon className="w-6 h-6" />
                    </div>
                    {index < steps.length - 1 && (
                      <div className={`absolute left-6 top-12 w-0.5 h-8 transition-all duration-500 ${
                        index < currentStepIndex ? 'bg-gradient-to-b from-orange-500 to-red-500' : 'bg-gray-200'
                      }`} />
                    )}
                    <div className="ml-6 flex-1">
                      <div className={`font-bold text-lg transition-all duration-300 ${
                        isCompleted ? 'text-gray-900' : 'text-gray-500'
                      }`}>
                        {step.title}
                      </div>
                      <div className={`text-sm font-medium transition-all duration-300 ${
                        isCompleted ? 'text-gray-600' : 'text-gray-400'
                      }`}>
                        {step.desc}
                      </div>
                      {isCurrent && (
                        <div className="flex items-center gap-2 text-sm font-bold text-orange-600 mt-2 animate-pulse">
                          <div className="w-2 h-2 bg-orange-500 rounded-full animate-ping"></div>
                          Current Status
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>

          <div className="bg-white/80 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-12 h-12 bg-gradient-to-br from-blue-100 to-purple-100 rounded-full flex items-center justify-center">
                <Phone className="w-6 h-6 text-blue-600" />
              </div>
              <h3 className="text-xl font-bold text-gray-900">Need Help?</h3>
            </div>
            <div className="space-y-4">
              <div className="flex items-center gap-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-2xl border border-blue-200">
                <Phone className="w-6 h-6 text-blue-500" />
                <div>
                  <div className="font-bold text-gray-900">Call Us Directly</div>
                  <a href="tel:(929) 456-3215" className="text-blue-600 font-bold hover:text-blue-700 text-lg">
                    (929) 456-3215
                  </a>
                </div>
              </div>
              {order.orderType === 'delivery' && order.deliveryAddress && (
                <div className="flex items-start gap-4 p-4 bg-gradient-to-r from-green-50 to-teal-50 rounded-2xl border border-green-200">
                  <MapPin className="w-6 h-6 text-green-500 mt-1" />
                  <div>
                    <div className="font-bold text-gray-900 mb-1">Delivery Address</div>
                    <div className="text-gray-700 font-medium">{order.deliveryAddress}</div>
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
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 relative overflow-hidden">
      {/* Background Logo */}
      <div className="fixed inset-0 flex items-center justify-center opacity-5 pointer-events-none z-0">
        <img 
          src="/assets/images/logo.png" 
          alt="Background Logo" 
          className="w-96 h-96 object-contain"
        />
      </div>
      
      <div className="relative z-10 max-w-4xl mx-auto px-4 py-8">
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-4">
            <Link href="/" className="p-3 hover:bg-orange-100 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-orange-600" />
            </Link>
            <div>
              <h1 className="text-3xl font-bold text-gray-900 mb-2">Your Orders</h1>
              <p className="text-gray-700 font-bold">Track your order status in real-time</p>
            </div>
          </div>
        </div>

        {orders.length === 0 ? (
          <div className="bg-white/80 backdrop-blur-sm rounded-3xl shadow-2xl border border-orange-200 p-12 text-center">
            <div className="w-24 h-24 bg-gradient-to-br from-orange-100 to-red-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <Package className="w-12 h-12 text-orange-500" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900 mb-3">No orders yet</h2>
            <p className="text-gray-600 mb-8 text-lg">Start your culinary journey with authentic Ghanaian flavors!</p>
            <Link
              href="/"
              className="inline-flex items-center gap-2 bg-gradient-to-r from-orange-500 to-red-500 text-white px-8 py-4 rounded-2xl font-bold hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
            >
              <span>🍽️</span> Browse Menu
            </Link>
          </div>
        ) : (
          <div className="space-y-6">
            {/* Stats Overview */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
              <div className="bg-white/80 backdrop-blur-sm rounded-2xl p-6 border border-orange-200 shadow-lg">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-orange-100 rounded-full flex items-center justify-center">
                    <Package className="w-6 h-6 text-orange-600" />
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-gray-900">{orders.length}</div>
                    <div className="text-sm text-gray-600">Total Orders</div>
                  </div>
                </div>
              </div>
              <div className="bg-white/80 backdrop-blur-sm rounded-2xl p-6 border border-green-200 shadow-lg">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                    <CheckCircle className="w-6 h-6 text-green-600" />
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-gray-900">
                      {orders.filter(o => ['delivered', 'completed'].includes(o.status)).length}
                    </div>
                    <div className="text-sm text-gray-600">Completed</div>
                  </div>
                </div>
              </div>
              <div className="bg-white/80 backdrop-blur-sm rounded-2xl p-6 border border-blue-200 shadow-lg">
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                    <span className="text-xl">💰</span>
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-gray-900">
                      ${orders.reduce((sum, order) => sum + order.total, 0).toFixed(0)}
                    </div>
                    <div className="text-sm text-gray-600">Total Spent</div>
                  </div>
                </div>
              </div>
            </div>

            {/* Orders List */}
            {orders.map((order) => {
              const isCompleted = ['delivered', 'completed'].includes(order.status)
              const isActive = !isCompleted
              
              return (
                <div key={order.id} className={`bg-white/80 backdrop-blur-sm rounded-3xl shadow-xl border p-6 transition-all hover:shadow-2xl ${
                  isActive ? 'border-orange-300 bg-gradient-to-r from-orange-50/50 to-red-50/50' : 'border-gray-200'
                }`}>
                  {/* Header */}
                  <div className="flex flex-col md:flex-row md:justify-between md:items-start gap-4 mb-6">
                    <div className="flex-1">
                      <div className="flex items-center gap-3 mb-2">
                        <h3 className="text-xl font-bold text-gray-900">Order #{order.orderNumber}</h3>
                        {isActive && (
                          <span className="px-3 py-1 bg-orange-500 text-white text-xs font-bold rounded-full animate-pulse">
                            ACTIVE
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-4 text-sm text-gray-600">
                        <span className="flex items-center gap-1">
                          <Clock className="w-4 h-4" />
                          {order.createdAt && typeof order.createdAt === 'object' && 'toDate' in order.createdAt 
                            ? order.createdAt.toDate().toLocaleDateString('en-US', { 
                                weekday: 'short', 
                                month: 'short', 
                                day: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit'
                              })
                            : new Date(order.createdAt).toLocaleDateString('en-US', {
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
                        <span className="font-bold text-gray-900">{getStatusText(order.status)}</span>
                      </div>
                      <div className="text-2xl font-bold text-orange-600 mb-3">${order.total.toFixed(2)}</div>
                      
                      <div className="flex flex-col gap-2">
                        {isActive && (
                          <Link
                            href={`/orders?track=${order.id}`}
                            className="px-4 py-2 bg-gradient-to-r from-orange-500 to-red-500 text-white rounded-xl text-sm font-bold hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg"
                          >
                            🔍 Track Order
                          </Link>
                        )}
                        
                        {isCompleted && (
                          <button
                            onClick={() => setExpandedOrder(expandedOrder === order.id ? null : order.id!)}
                            className="px-4 py-2 bg-gradient-to-r from-blue-500 to-purple-500 text-white rounded-xl text-sm font-bold hover:from-blue-600 hover:to-purple-600 transition-all transform hover:scale-105 shadow-lg"
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
                          className="px-4 py-2 bg-gradient-to-r from-green-500 to-teal-500 text-white rounded-xl text-sm font-bold hover:from-green-600 hover:to-teal-600 transition-all transform hover:scale-105 shadow-lg"
                        >
                          🔄 Reorder
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Progress Bar for Active Orders */}
                  {isActive && (
                    <div className="mb-6">
                      <div className="flex justify-between text-xs text-gray-600 mb-2">
                        <span>Confirmed</span>
                        <span>Preparing</span>
                        <span>Ready</span>
                        {order.orderType === 'delivery' && <span>Delivering</span>}
                        <span>Complete</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-3 shadow-inner">
                        <div 
                          className="bg-gradient-to-r from-orange-500 to-red-500 h-3 rounded-full transition-all duration-1000 shadow-lg"
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
                    <div className="bg-white/60 rounded-2xl p-4 border border-gray-100">
                      <h4 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
                        <span>🍽️</span> Order Items ({order.items.length})
                      </h4>
                      <div className="space-y-2 max-h-32 overflow-y-auto">
                        {order.items.map((item, index) => (
                          <div key={index} className="flex justify-between items-center py-1 border-b border-gray-100 last:border-0">
                            <span className="text-gray-800 font-medium">{item.quantity}x {item.name}</span>
                            <span className="font-bold text-gray-900">${(item.price * item.quantity).toFixed(2)}</span>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="bg-white/60 rounded-2xl p-4 border border-gray-100">
                      <h4 className="font-bold text-gray-900 mb-3 flex items-center gap-2">
                        {order.orderType === 'delivery' ? (
                          <><span>🚚</span> Delivery Info</>
                        ) : (
                          <><span>🏪</span> Pickup Info</>
                        )}
                      </h4>
                      {order.orderType === 'delivery' ? (
                        <div className="space-y-2">
                          <div className="flex items-start gap-2">
                            <MapPin className="w-4 h-4 text-orange-500 mt-1" />
                            <span className="text-gray-800 text-sm">{order.deliveryAddress}</span>
                          </div>
                          <div className="text-xs text-gray-500">Delivery Fee: ${order.deliveryFee.toFixed(2)}</div>
                        </div>
                      ) : (
                        <div className="space-y-2">
                          <div className="flex items-start gap-2">
                            <MapPin className="w-4 h-4 text-orange-500 mt-1" />
                            <div className="text-sm">
                              <div className="font-medium text-gray-800">Taste of African Cuisine</div>
                              <div className="text-gray-600">200 Hartford Turnpike, Vernon, CT</div>
                            </div>
                          </div>
                          <div className="text-xs text-gray-500">Ready for pickup when notified</div>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  {/* Reviews Section */}
                  {expandedOrder === order.id && isCompleted && (
                    <div className="mt-6 pt-6 border-t border-gray-200">
                      <h4 className="font-bold text-gray-900 mb-4 flex items-center gap-2">
                        <span>⭐</span> Rate Your Experience
                      </h4>
                      <div className="space-y-4">
                        {order.items.map((item) => (
                          <div key={item.id} className="bg-white/60 rounded-xl p-4 border border-gray-100">
                            <Reviews
                              mealId={item.id}
                              mealName={item.name}
                              userCanReview={true}
                            />
                          </div>
                        ))}
                      </div>
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