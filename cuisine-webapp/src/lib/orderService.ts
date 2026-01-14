import { collection, addDoc, onSnapshot, query, where, orderBy, doc, onSnapshot as onDocSnapshot } from 'firebase/firestore'
import { db } from './firebase'
import { notificationService } from './notificationService'

export interface Order {
  id?: string
  orderNumber: string
  userId: string
  customerInfo: {
    name: string
    email: string
    phone: string
  }
  items: Array<{
    id: string
    name: string
    price: number
    quantity: number
  }>
  orderType: 'delivery' | 'pickup'
  deliveryAddress?: string
  subtotal: number
  deliveryFee: number
  tax: number
  total: number
  paymentMethod: 'card' | 'cash'
  status: 'confirmed' | 'preparing' | 'ready' | 'out_for_delivery' | 'delivered' | 'completed'
  createdAt: Date
  updatedAt: Date
}

export const orderService = {
  async createOrder(orderData: Omit<Order, 'id' | 'createdAt' | 'updatedAt'>): Promise<string> {
    const docRef = await addDoc(collection(db, 'orders'), {
      ...orderData,
      createdAt: new Date(),
      updatedAt: new Date()
    })
    
    await this.sendOrderConfirmation(orderData)
    return docRef.id
  },

  onOrderUpdates(userId: string, callback: (orders: Order[]) => void) {
    const q = query(
      collection(db, 'orders'),
      where('userId', '==', userId),
      orderBy('createdAt', 'desc')
    )
    
    return onSnapshot(q, (snapshot) => {
      const orders = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Order[]
      callback(orders)
    })
  },

  // Listen for status changes on user's orders for push notifications
  listenForStatusUpdates(userId: string) {
    const q = query(
      collection(db, 'orders'),
      where('userId', '==', userId)
    )
    
    return onSnapshot(q, (snapshot) => {
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'modified') {
          const order = { id: change.doc.id, ...change.doc.data() } as Order
          this.handleStatusUpdate(order)
        }
      })
    })
  },

  async handleStatusUpdate(order: Order) {
    // Send push notification
    await fetch('/api/notifications/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        type: 'status_update',
        orderId: order.id,
        orderNumber: order.orderNumber,
        status: order.status
      })
    })

    // Send email status update
    await this.sendStatusUpdateEmail(order)
  },

  async sendStatusUpdateEmail(order: Order) {
    try {
      const statusMessages = {
        confirmed: { message: 'Order Confirmed', estimatedTime: '30-45 minutes' },
        preparing: { message: 'Preparing Your Order', estimatedTime: '20-30 minutes' },
        ready: { message: 'Order Ready for Pickup', estimatedTime: 'Ready now' },
        out_for_delivery: { message: 'Out for Delivery', estimatedTime: '15-25 minutes' },
        delivered: { message: 'Order Delivered', estimatedTime: 'Completed' },
        completed: { message: 'Order Completed', estimatedTime: 'Thank you!' }
      }

      const statusInfo = statusMessages[order.status] || { message: order.status, estimatedTime: '' }

      await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'status_update',
          orderData: {
            customerEmail: order.customerInfo.email,
            customerName: order.customerInfo.name,
            orderNumber: order.orderNumber,
            orderType: order.orderType,
            items: order.items,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            tax: order.tax,
            total: order.total,
            deliveryAddress: order.deliveryAddress,
            status: statusInfo.message,
            estimatedTime: statusInfo.estimatedTime
          }
        })
      })

      console.log(`Status update email sent for order ${order.orderNumber}: ${order.status}`)
    } catch (error) {
      console.error('Failed to send status update email:', error)
    }
  },

  async sendOrderConfirmation(order: Omit<Order, 'id' | 'createdAt' | 'updatedAt'>) {
    try {
      // Send email confirmation
      await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'confirmation',
          orderData: {
            customerEmail: order.customerInfo.email,
            customerName: order.customerInfo.name,
            orderNumber: order.orderNumber,
            orderType: order.orderType,
            items: order.items,
            subtotal: order.subtotal,
            deliveryFee: order.deliveryFee,
            tax: order.tax,
            total: order.total,
            deliveryAddress: order.deliveryAddress,
            status: 'Order Confirmed',
            estimatedTime: '30-45 minutes'
          }
        })
      })
      
      // Also send push notification
      await fetch('/api/notifications/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          type: 'order_confirmation',
          email: order.customerInfo.email,
          phone: order.customerInfo.phone,
          orderNumber: order.orderNumber,
          customerName: order.customerInfo.name,
          total: order.total
        })
      })
      
      console.log(`Order confirmation email sent for order ${order.orderNumber}`)
    } catch (error) {
      console.error('Failed to send confirmation:', error)
    }
  }
}