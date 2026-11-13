import type { PublicMenuDish } from '@/services/productService'

export interface DishAddon {
  id: string
  name: string
  price: number
}

export interface DishCustomization {
  spiceLevel?: 'Mild' | 'Medium' | 'Spicy'
  dietary?: 'Regular' | 'Jain' | 'Vegan'
  selectedAddons?: DishAddon[]
  notes?: string
}

export interface CartItem {
  id?: string
  dish: PublicMenuDish
  quantity: number
  customization?: DishCustomization
  unitPrice?: number
}

export interface CartOrder {
  items: CartItem[]
  tableNumber: string
  specialInstructions: string
  subtotalPaise: number
  totalPaise: number
}
