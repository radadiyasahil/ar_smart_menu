export interface PublicMenuDishAddon {
  id: string
  name: string
  price: number
}

export interface PublicMenuDishCustomization {
  isCustomizable?: boolean
  allowSpiceLevel?: boolean
  allowDietary?: boolean
  addons?: PublicMenuDishAddon[]
}

export interface PublicMenuDish {
  id: string
  name: string
  description?: string
  pricePaise?: number
  vegStatus: number
  isSpicy: boolean
  isBestseller: boolean
  isNew: boolean
  soldOutToday: boolean
  thumbnailUrl?: string
  photoUrls: string[]
  glbUrl?: string
  usdzUrl?: string
  has3dModel: boolean
  dishSlug: string
  customizationJson?: string
  customization?: PublicMenuDishCustomization
  categoryName?: string
}

const SWEET_OR_BEVERAGE_REGEX = /ice\s*cream|shake|beverage|drink|dessert|juice|soda|coke|pepsi|coffee|tea|water|smoothie|pastry|cake|mithai|halwa|gulab\s*jamun|rasgulla|kulfi|falooda/i
const NON_CUSTOM_REGEX = /water\s*bottle|mineral\s*water|soda\s*can|soft\s*drink|canned|packaged/i

export function isSweetOrBeverageDish(dish: PublicMenuDish): boolean {
  return SWEET_OR_BEVERAGE_REGEX.test(dish.name) || (Boolean(dish.categoryName) && SWEET_OR_BEVERAGE_REGEX.test(dish.categoryName!))
}

export function isNonCustomizableDish(dish: PublicMenuDish): boolean {
  // 1. Explicitly disabled by restaurant owner
  if (dish.customization?.isCustomizable === false) return true

  // 2. Water / soda / packaged goods regex
  if (NON_CUSTOM_REGEX.test(dish.name)) return true

  // 3. Customization config exists, but neither spice, dietary, nor add-ons are enabled
  if (
    dish.customization &&
    !dish.customization.allowSpiceLevel &&
    !dish.customization.allowDietary &&
    (!dish.customization.addons || dish.customization.addons.length === 0)
  ) {
    return true
  }

  // 4. Sweet / dessert / beverage / ice cream without custom add-ons or spice level
  if (
    isSweetOrBeverageDish(dish) &&
    (!dish.customization?.addons || dish.customization.addons.length === 0) &&
    dish.customization?.allowSpiceLevel !== true
  ) {
    return true
  }

  return false
}

export interface PublicMenuCategory {
  categoryName: string
  categoryId: number
  dishes: PublicMenuDish[]
}

export interface PublicMenuResponse {
  slug: string
  businessName: string
  logoUrl?: string
  city: string
  address?: string
  whatsAppNumber?: string
  orderingUrl?: string
  categories: PublicMenuCategory[]
  isBusinessActive?: boolean
  inactiveMessage?: string
  availableTables?: string[]
  wifiName?: string
  wifiPassword?: string
  upiId?: string
  requireGeofence?: boolean
  geofenceRadiusMeters?: number
  latitude?: number
  longitude?: number
}

import { apiClient, type ApiEnvelope } from './apiClient'
import type { ArExperience, Product } from '@/types/product'

const FALLBACK_GLB =
  'https://modelviewer.dev/shared-assets/models/Hamburger.glb'
const FALLBACK_USDZ =
  'https://modelviewer.dev/shared-assets/models/Hamburger.usdz'

interface PublicArModelDto {
  glbUrl?: string
  usdzUrl?: string
}

interface PublicArProductDto {
  id: string
  name: string
  description?: string
  priceInPaise?: number
  vegStatus: number
  isSpicy: boolean
  isBestseller: boolean
  soldOutToday: boolean
  calories?: number
  photoUrls: string[]
}

interface PublicArBusinessDto {
  businessName: string
  city: string
  orderingUrl?: string
  logoUrl?: string
}

interface PublicArOtherProductDto {
  id: string
  name: string
  priceInPaise?: number
  slug: string
  model: PublicArModelDto
}

export interface PublicArResponse {
  slug: string
  product: PublicArProductDto
  business: PublicArBusinessDto
  model: PublicArModelDto
  otherProducts: PublicArOtherProductDto[]
}

function formatPrice(paise?: number): string {
  if (paise == null) return '—'
  return `₹${Math.round(paise / 100).toLocaleString('en-IN')}`
}

function isVeg(vegStatus: number): boolean {
  return vegStatus === 0 || vegStatus === 2
}

function mapProduct(
  slug: string,
  data: PublicArProductDto,
  model: PublicArModelDto,
  orderingUrl?: string,
): Product {
  const meta: string[] = []
  if (data.calories) meta.push(`${data.calories} cal`)
  if (data.isSpicy) meta.push('Spicy')
  if (data.isBestseller) meta.push('Bestseller')

  return {
    id: data.id,
    slug,
    name: data.name,
    description: data.description,
    price: formatPrice(data.priceInPaise),
    pricePaise: data.priceInPaise,
    serves: data.soldOutToday ? 'Sold out today' : '1 serving',
    calories: meta.join(' · ') || '—',
    rating: data.isBestseller ? 4.8 : 4.5,
    isVeg: isVeg(data.vegStatus),
    isSpicy: data.isSpicy,
    isBestseller: data.isBestseller,
    soldOutToday: data.soldOutToday,
    thumbnail: data.photoUrls[0] ?? '',
    photoUrls: data.photoUrls.filter(Boolean),
    glbUrl: model.glbUrl ?? FALLBACK_GLB,
    usdzUrl: model.usdzUrl ?? FALLBACK_USDZ,
    orderDeepLink: orderingUrl ?? '#order',
  }
}

function mapOtherProduct(
  item: PublicArOtherProductDto,
  orderingUrl?: string,
): Product {
  return mapProduct(
    item.slug,
    {
      id: item.id,
      name: item.name,
      priceInPaise: item.priceInPaise,
      vegStatus: 3,
      isSpicy: false,
      isBestseller: false,
      soldOutToday: false,
      photoUrls: [],
    },
    item.model,
    orderingUrl,
  )
}

function mapExperience(data: PublicArResponse): ArExperience {
  const orderingUrl = data.business.orderingUrl
  const product = mapProduct(data.slug, data.product, data.model, orderingUrl)

  return {
    slug: data.slug,
    product,
    business: {
      name: data.business.businessName,
      city: data.business.city,
      orderingUrl,
      logoUrl: data.business.logoUrl,
    },
    otherProducts: data.otherProducts.map((item) =>
      mapOtherProduct(item, orderingUrl),
    ),
  }
}

export const productService = {
  /** Fetch the entire restaurant menu dynamically from the backend */
  async fetchMenuBySlug(slug: string): Promise<PublicMenuResponse> {
    const res = await apiClient.get<ApiEnvelope<PublicMenuResponse>>(
      `/public/ar/menu/${slug}`,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error || 'Menu not found')
    }
    const menu = res.data.data
    if (menu?.categories) {
      for (const cat of menu.categories) {
        for (const dish of cat.dishes) {
          dish.categoryName = cat.categoryName
          if (dish.customizationJson) {
            try {
              dish.customization = JSON.parse(dish.customizationJson)
            } catch {
              // Ignore parse error
            }
          }
        }
      }
    }
    return menu
  },

  /** Fetch a specific dish AR experience dynamically from the backend */
  async getExperienceBySlug(slug: string): Promise<ArExperience> {
    const res = await apiClient.get<ApiEnvelope<PublicArResponse>>(
      `/public/ar/${slug}`,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Product not found')
    }
    return mapExperience(res.data.data)
  },

  async logScan(
    slug: string,
    payload: {
      sessionId: string
      visitorFingerprint?: string
      deviceType?: string
      platform?: string
    },
  ): Promise<string | null> {
    try {
      const res = await apiClient.post<ApiEnvelope<{ eventId: string }>>(
        `/public/ar/${slug}/scan`,
        payload,
      )
      const id = res.data.data?.eventId
      return id ? String(id) : null
    } catch {
      return null
    }
  },

  async logView(
    slug: string,
    payload: {
      sessionId: string
      viewDurationSeconds: number
      arLaunched: boolean
      visitorFingerprint?: string
      deviceType?: string
      platform?: string
      scanEventId?: string | null
      rotated?: boolean
      resized?: boolean
      shared?: boolean
      clickedOrder?: boolean
    },
  ): Promise<void> {
    try {
      await apiClient.post(`/public/ar/${slug}/view`, payload)
    } catch {
      // Non-critical
    }
  },
}

export function getShareUrl(slug: string): string {
  return `${window.location.origin}/dish/${slug}`
}
