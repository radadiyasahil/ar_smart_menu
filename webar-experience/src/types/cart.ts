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

export function getCustomizationKey(customization?: DishCustomization): string {
  if (!customization) return 'standard'
  const spice = customization.spiceLevel || 'none'
  const dietary = customization.dietary || 'Regular'
  const addons = (customization.selectedAddons || [])
    .map((a) => a.id || a.name)
    .sort()
    .join(',')
  const notes = (customization.notes || '').trim().toLowerCase()
  if (spice === 'none' && dietary === 'Regular' && !addons && !notes) {
    return 'standard'
  }
  return `s:${spice}__d:${dietary}__a:${addons}__n:${notes}`
}

export function getCartItemKey(dishId: string, customization?: DishCustomization): string {
  const customKey = getCustomizationKey(customization)
  if (customKey === 'standard') return dishId
  return `${dishId}__${customKey}`
}

export function parseCustomizationFromModifiers(
  modifiers?: string[],
  notes?: string,
): DishCustomization | undefined {
  if ((!modifiers || modifiers.length === 0) && !notes) return undefined
  const custom: DishCustomization = { notes: notes || '' }
  if (modifiers && modifiers.length > 0) {
    const addons: DishAddon[] = []
    for (const mod of modifiers) {
      if (mod.endsWith(' Spicy')) {
        const sp = mod.replace(' Spicy', '').trim()
        if (sp === 'Mild' || sp === 'Medium' || sp === 'Spicy') {
          custom.spiceLevel = sp
        }
      } else if (mod === 'Jain' || mod === 'Vegan' || mod === 'Regular') {
        custom.dietary = mod
      } else {
        // e.g. "Extra Cheese (+₹40)" or "Extra Butter"
        const match = mod.match(/^(.*?)(?:\s*\(\+₹(\d+)\))?$/)
        if (match) {
          const name = match[1].trim()
          const price = match[2] ? parseInt(match[2], 10) : 0
          addons.push({
            id: name.toLowerCase().replace(/[^a-z0-9]+/g, '_'),
            name,
            price,
          })
        }
      }
    }
    if (addons.length > 0) {
      custom.selectedAddons = addons
    }
  }
  return custom
}
