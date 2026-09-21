import axios from 'axios'

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
  async getExperienceBySlug(slug: string): Promise<ArExperience> {
    try {
      const res = await apiClient.get<ApiEnvelope<PublicArResponse>>(
        `/public/ar/${slug}`,
      )
      if (!res.data.success || !res.data.data) {
        throw new Error(res.data.error ?? 'Product not found')
      }
      return mapExperience(res.data.data)
    } catch (e) {
      if (axios.isAxiosError(e)) {
        if (e.response?.status === 404) {
          throw new Error('NOT_FOUND')
        }
        if (!e.response) {
          throw new Error(
            'NETWORK: Cannot reach the API. Start the backend: scripts\\dev-backend.ps1 (port 5232)',
          )
        }
      }
      throw e
    }
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
