'use client'

import { useState, useEffect } from 'react'
import { useAuth } from '@/lib/AuthContext'
import { orderService, type Order } from '@/lib/orderService'
import { CheckCircle, Clock, Truck, Package, X } from 'lucide-react'

interface Notification {
  id: string
  orderId: string
  orderNumber: number
  status: Order['status']
  message: string
  timestamp: Date
  read: boolean
}

export default function OrderNotifications() {
  const [notifications, setNotifications] = useState<Notification[]>([])
  const [showNotifications, setShowNotifications] = useState(false)
  const { user } = useAuth()

  useEffect(() => {
    if (!user) return

    const unsubscribe = orderService.onOrderUpdates(user.uid, (orders) => {
      // Check for status changes and create notifications
      orders.forEach(order => {
        setNotifications(prev => {
          const existingNotification = prev.find(n => n.orderId === order.id && n.status === order.status)
          
          if (!existingNotification) {
            const notification: Notification = {
              id: `${order.id}-${order.status}-${Date.now()}`,
              orderId: order.id!,
              orderNumber: order.orderNumber,
              status: order.status,
              message: getStatusMessage(order.status, order.orderNumber),
              timestamp: new Date(),
              read: false
            }
            
            return [notification, ...prev.slice(0, 9)] // Keep last 10
          }
          return prev
        })
      })
    })

    return () => unsubscribe()
  }, [user, notifications.length])

  useEffect(() => {
    // Load notifications from localStorage
    const savedNotifications = localStorage.getItem('notifications')
    if (savedNotifications) {
      setNotifications(JSON.parse(savedNotifications).map((n: any) => ({
        ...n,
        timestamp: new Date(n.timestamp)
      })))
    }
  }, [])

  useEffect(() => {
    // Save notifications to localStorage whenever they change
    if (notifications.length > 0) {
      localStorage.setItem('notifications', JSON.stringify(notifications))
    }
  }, [notifications])

  // Request notification permission on mount
  useEffect(() => {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission()
    }
  }, [])

  const getStatusMessage = (status: Order['status'], orderNumber: number) => {
    switch (status) {
      case 'confirmed':
        return `Order #${orderNumber} has been confirmed! We're preparing your delicious meal.`
      case 'preparing':
        return `Order #${orderNumber} is being prepared by our chefs.`
      case 'ready':
        return `Order #${orderNumber} is ready for pickup!`
      case 'out_for_delivery':
        return `Order #${orderNumber} is out for delivery. It should arrive soon!`
      case 'delivered':
        return `Order #${orderNumber} has been delivered. Enjoy your meal!`
      case 'completed':
        return `Order #${orderNumber} is complete. Thank you for choosing us!`
      default:
        return `Order #${orderNumber} status updated.`
    }
  }

  const getStatusIcon = (status: Order['status']) => {
    switch (status) {
      case 'confirmed': return <Clock className="w-5 h-5 text-orange-500" />
      case 'preparing': return <Package className="w-5 h-5 text-blue-500" />
      case 'ready': return <CheckCircle className="w-5 h-5 text-green-500" />
      case 'out_for_delivery': return <Truck className="w-5 h-5 text-purple-500" />
      case 'delivered': case 'completed': return <CheckCircle className="w-5 h-5 text-green-600" />
    }
  }

  const markAsRead = (notificationId: string) => {
    setNotifications(prev => {
      const updated = prev.map(n => n.id === notificationId ? { ...n, read: true } : n)
      localStorage.setItem('notifications', JSON.stringify(updated))
      return updated
    })
  }

  const unreadCount = notifications.filter(n => !n.read).length

  if (!user) return null

  return (
    <div className="relative">
      {/* Notification Bell */}
      <button
        onClick={() => setShowNotifications(!showNotifications)}
        className="relative p-2 text-gray-600 hover:text-orange-600 transition-colors"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
        </svg>
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
            {unreadCount}
          </span>
        )}
      </button>

      {/* Notifications Dropdown */}
      {showNotifications && (
        <div className="absolute right-0 top-full mt-2 w-80 bg-white rounded-lg shadow-xl border border-gray-200 z-50 max-h-96 overflow-y-auto">
          <div className="p-4 border-b border-gray-200">
            <h3 className="font-bold text-gray-900">Order Updates</h3>
          </div>
          
          {notifications.length === 0 ? (
            <div className="p-4 text-center text-gray-500">
              No notifications yet
            </div>
          ) : (
            <div className="divide-y divide-gray-100">
              {notifications.map(notification => (
                <div
                  key={notification.id}
                  className={`p-4 hover:bg-gray-50 transition-colors cursor-pointer ${
                    !notification.read ? 'bg-orange-50' : ''
                  }`}
                  onClick={() => {
                    markAsRead(notification.id)
                    setShowNotifications(false)
                    window.location.href = '/orders'
                  }}
                >
                  <div className="flex items-start gap-3">
                    {getStatusIcon(notification.status)}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-gray-900 font-medium">
                        {notification.message}
                      </p>
                      <p className="text-xs text-gray-500 mt-1">
                        {notification.timestamp.toLocaleTimeString()}
                      </p>
                    </div>
                    {!notification.read && (
                      <div className="w-2 h-2 bg-orange-500 rounded-full"></div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}