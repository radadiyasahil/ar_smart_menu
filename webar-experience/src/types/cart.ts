import type { PublicMenuDish } from '@/services/productService'

export interface CartItem {
  dish: PublicMenuDish
  quantity: number
}

export interface CartOrder {
  items: CartItem[]
  tableNumber: string
  specialInstructions: string
  subtotalPaise: number
  totalPaise: number
}
