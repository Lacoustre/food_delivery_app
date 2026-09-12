import { supabase } from './supabase'
import { getAuthHeaders } from './authHeaders'

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
  /** Money already sent back. Absent on an order being created — nothing has
   *  been refunded yet — and a customer must never be shown a figure their
   *  bank statement contradicts. */
  refundAmount?: number
  paymentMethod: 'card' | 'cash'
  status: 'confirmed' | 'preparing' | 'ready' | 'out_for_delivery' | 'delivered' | 'completed' | 'cancelled'
  uberTrackingUrl?: string | null
  createdAt: Date
  updatedAt: Date
}

// The orders table uses the admin panel's richer status vocabulary; map it
// onto the set this app's UI was built around.
const STATUS_FROM_DB: Record<string, Order['status']> = {
  'pending': 'confirmed', // scheduled orders awaiting their slot
  'confirmed': 'confirmed',
  'preparing': 'preparing',
  'ready for pickup': 'ready',
  'on the way': 'out_for_delivery',
  'delivered': 'delivered',
  'picked up': 'completed',
  'completed': 'completed',
  'cancelled': 'cancelled',
}

type ProfileInfo = { name: string | null; email: string | null; phone: string | null }

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function rowToOrder(row: any, profile: ProfileInfo | null): Order {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const items = ((row.order_items as any[]) ?? []).map((i) => ({
    id: i.meal_id as string,
    name: (i.name as string) ?? 'Item',
    price: Number(i.unit_price ?? 0),
    quantity: (i.quantity as number) ?? 1,
  }))
  return {
    id: row.id,
    orderNumber: row.order_number ?? String(row.id).slice(0, 8).toUpperCase(),
    userId: row.user_id,
    customerInfo: {
      name: profile?.name ?? '',
      email: profile?.email ?? '',
      phone: profile?.phone ?? '',
    },
    items,
    orderType: (row.order_type as Order['orderType']) ?? 'delivery',
    deliveryAddress: row.delivery_address ?? undefined,
    subtotal: Number(row.subtotal ?? 0),
    deliveryFee: Number(row.delivery_fee ?? 0),
    tax: Number(row.tax ?? 0),
    total: Number(row.total ?? 0),
    refundAmount: Number(row.refund_amount ?? 0),
    paymentMethod: (row.payment_method as Order['paymentMethod']) ?? 'card',
    status: STATUS_FROM_DB[row.status as string] ?? 'confirmed',
    uberTrackingUrl: row.uber_tracking_url ?? null,
    createdAt: row.created_at ? new Date(row.created_at) : new Date(),
    updatedAt: row.updated_at ? new Date(row.updated_at) : new Date(),
  }
}

export const orderService = {
  // Orders are created server-side by /api/create-order (which validates
  // pricing and dispatches Uber Direct); this only sends the confirmation
  // notifications. The old Firestore copy is gone — Supabase is the sole
  // source of truth, so status updates and Uber tracking actually reach
  // the customer.
  async createOrder(orderData: Omit<Order, 'id' | 'createdAt' | 'updatedAt'>): Promise<void> {
    await this.sendOrderConfirmation(orderData)
  },

  // Live view of the signed-in user's orders. The userId argument is the
  // legacy Firebase uid — ignored; the Supabase session (mirrored at login)
  // identifies the user, and RLS scopes the query server-side.
  onOrderUpdates(_userId: string, callback: (orders: Order[]) => void) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let channel: any = null
    let stopped = false

    const start = async () => {
      const { data: userData } = await supabase.auth.getUser()
      const user = userData?.user
      if (!user || stopped) {
        callback([])
        return
      }

      const fetchAll = async () => {
        const [{ data: rows }, { data: profile }] = await Promise.all([
          supabase
            .from('orders')
            .select('*, order_items(*)')
            .eq('user_id', user.id)
            .order('created_at', { ascending: false }),
          supabase.from('profiles').select('name, email, phone').eq('id', user.id).single(),
        ])
        if (!stopped) callback((rows ?? []).map((r) => rowToOrder(r, profile ?? null)))
      }

      await fetchAll()
      channel = supabase
        .channel(`orders-${user.id}`)
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'orders', filter: `user_id=eq.${user.id}` },
          fetchAll,
        )
        .subscribe()
    }

    start()
    return () => {
      stopped = true
      if (channel) supabase.removeChannel(channel)
    }
  },

  // Push + email on status changes of the user's orders.
  listenForStatusUpdates(_userId: string) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let channel: any = null
    let stopped = false

    const start = async () => {
      const { data: userData } = await supabase.auth.getUser()
      const user = userData?.user
      if (!user || stopped) return

      channel = supabase
        .channel(`order-status-${user.id}`)
        .on(
          'postgres_changes',
          { event: 'UPDATE', schema: 'public', table: 'orders', filter: `user_id=eq.${user.id}` },
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          async (payload: any) => {
            if (payload.new?.status === payload.old?.status) return
            // realtime payloads don't include joined items — refetch the row
            const [{ data: row }, { data: profile }] = await Promise.all([
              supabase.from('orders').select('*, order_items(*)').eq('id', payload.new.id).single(),
              supabase.from('profiles').select('name, email, phone').eq('id', user.id).single(),
            ])
            if (row) await this.handleStatusUpdate(rowToOrder(row, profile ?? null))
          },
        )
        .subscribe()
    }

    start()
    return () => {
      stopped = true
      if (channel) supabase.removeChannel(channel)
    }
  },

  async handleStatusUpdate(order: Order) {
    // Send push notification
    await fetch('/api/notifications/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
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
        completed: { message: 'Order Completed', estimatedTime: 'Thank you!' },
        cancelled: { message: 'Order Cancelled', estimatedTime: '' }
      }

      const statusInfo = statusMessages[order.status] || { message: order.status, estimatedTime: '' }

      await fetch('/api/send-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
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
        headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
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
        headers: { 'Content-Type': 'application/json', ...(await getAuthHeaders()) },
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
