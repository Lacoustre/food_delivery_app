import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { CartItem, User, MenuItem } from './types'

interface AppStore {
  // Auth
  user: User | null
  setUser: (user: User | null) => void
  
  // Cart
  cart: CartItem[]
  addToCart: (item: MenuItem, quantity?: number) => void
  removeFromCart: (itemId: string) => void
  updateQuantity: (itemId: string, quantity: number) => void
  clearCart: () => void
  cartTotal: number
  
  // UI
  isCartOpen: boolean
  setCartOpen: (open: boolean) => void
  isMobileMenuOpen: boolean
  setMobileMenuOpen: (open: boolean) => void
}

export const useAppStore = create<AppStore>()(
  persist(
    (set, get) => ({
      // Auth
      user: null,
      setUser: (user) => set({ user }),
      
      // Cart
      cart: [],
      addToCart: (item, quantity = 1) => {
        const cart = get().cart
        const existingItem = cart.find(cartItem => cartItem.id === item.id)
        
        if (existingItem) {
          set({
            cart: cart.map(cartItem =>
              cartItem.id === item.id
                ? { ...cartItem, quantity: cartItem.quantity + quantity }
                : cartItem
            )
          })
        } else {
          set({
            cart: [...cart, { ...item, quantity }]
          })
        }
      },
      
      removeFromCart: (itemId) => {
        set({
          cart: get().cart.filter(item => item.id !== itemId)
        })
      },
      
      updateQuantity: (itemId, quantity) => {
        if (quantity <= 0) {
          get().removeFromCart(itemId)
          return
        }
        
        set({
          cart: get().cart.map(item =>
            item.id === itemId ? { ...item, quantity } : item
          )
        })
      },
      
      clearCart: () => set({ cart: [] }),
      
      get cartTotal() {
        return get().cart.reduce((total, item) => total + (item.price * item.quantity), 0)
      },
      
      // UI
      isCartOpen: false,
      setCartOpen: (open) => set({ isCartOpen: open }),
      isMobileMenuOpen: false,
      setMobileMenuOpen: (open) => set({ isMobileMenuOpen: open }),
    }),
    {
      name: 'cuisine-webapp-store',
      partialize: (state) => ({
        cart: state.cart,
        user: state.user,
      }),
    }
  )
)