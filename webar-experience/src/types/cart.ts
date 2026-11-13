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
  addedBy?: string
  clientId?: string
}

export interface SharedCartItem {
  id: string
  dishId: string
  name: string
  unitPrice: number
  quantity: number
  imageUrl?: string
  modifiers?: string[]
  notes?: string
  clientId?: string
  addedBy?: string
  updatedAt?: string
}

export interface SharedCartResponse {
  tableNumber: string
  items: SharedCartItem[]
  totalItems: number
  totalAmount: number
  lastUpdatedBy?: string
  lastClientId?: string
  updatedAt?: string
}

export interface CartOrder {
  items: CartItem[]
  tableNumber: string
  specialInstructions: string
  subtotalPaise: number
  totalPaise: number
}
