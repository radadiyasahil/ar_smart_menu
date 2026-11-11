export interface Product {
  id: string
  slug: string
  name: string
  price: string
  pricePaise?: number
  description?: string
  serves: string
  calories: string
  rating: number
  isVeg: boolean
  isSpicy: boolean
  isBestseller: boolean
  soldOutToday: boolean
  thumbnail: string
  photoUrls: string[]
  glbUrl: string
  usdzUrl?: string
  orderDeepLink: string
}

export interface ArBusiness {
  name: string
  city: string
  orderingUrl?: string
  logoUrl?: string
}

export interface ArExperience {
  slug: string
  product: Product
  business: ArBusiness
  otherProducts: Product[]
}

export type ScalePreset = 0.5 | 1 | 1.25

export const SCALE_PRESETS: { label: string; value: ScalePreset }[] = [
  { label: 'Actual size', value: 1 },
  { label: '50% smaller', value: 0.5 },
  { label: '25% larger', value: 1.25 },
]

export type ArStatus =
  | 'not-presenting'
  | 'session-started'
  | 'object-placed'
  | 'failed'

export type CameraPermissionState = 'prompt' | 'granted' | 'denied' | 'unsupported'
