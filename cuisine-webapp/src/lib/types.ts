export interface User {
  uid: string
  email: string
  name: string
  phone: string
  role: 'customer' | 'admin'
  createdAt: any
  updatedAt: any
  fcmToken?: string
}

export interface MenuItem {
  id: string
  name: string
  price: number
  image: string
  category: 'Main Dishes' | 'Side Dishes' | 'Pastries' | 'Drinks'
  available: boolean
  active: boolean
}

export interface CartItem extends MenuItem {
  quantity: number
}

export interface Order {
  id: string
  userId: string
  items: Array<{
    name: string
    price: number
    quantity: number
    image?: string
  }>
  total: number
  status: 'pending' | 'confirmed' | 'preparing' | 'ready' | 'delivered' | 'cancelled'
  deliveryAddress: string
  customerName: string
  customerPhone: string
  customerEmail: string
  createdAt: any
  updatedAt: any
  estimatedDeliveryTime?: any
}