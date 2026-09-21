import type { Product } from '@/types/product'

/**
 * Mock product catalog — replace with API call to ASP.NET Core later.
 * GLB/USDZ URLs use Google model-viewer shared assets for demo.
 */
const mockProducts: Product[] = [
  {
    id: 'p1',
    slug: 'margherita-pizza-demo',
    name: 'Margherita Pizza',
    price: '₹299',
    serves: '2 people',
    calories: '680 kcal',
    rating: 4.6,
    isVeg: true,
    isSpicy: false,
    isBestseller: true,
    soldOutToday: false,
    thumbnail:
      'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=200&h=200&fit=crop',
    photoUrls: [],
    glbUrl: 'https://modelviewer.dev/shared-assets/models/Hamburger.glb',
    usdzUrl: 'https://modelviewer.dev/shared-assets/models/Hamburger.usdz',
    orderDeepLink: 'https://example.com/order/p1',
  },
  {
    id: 'p2',
    slug: 'shish-kebab-demo',
    name: 'Grilled Shish Kebab',
    price: '₹349',
    serves: '1 person',
    calories: '420 kcal',
    rating: 4.4,
    isVeg: false,
    isSpicy: true,
    isBestseller: false,
    soldOutToday: false,
    thumbnail:
      'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=200&h=200&fit=crop',
    photoUrls: [],
    glbUrl: 'https://modelviewer.dev/shared-assets/models/shishkebab.glb',
    usdzUrl: 'https://modelviewer.dev/shared-assets/models/shishkebab.usdz',
    orderDeepLink: 'https://example.com/order/p2',
  },
  {
    id: 'p3',
    slug: 'chocolate-cake-demo',
    name: 'Chocolate Cake Slice',
    price: '₹199',
    serves: '1 person',
    calories: '350 kcal',
    rating: 4.8,
    isVeg: true,
    isSpicy: false,
    isBestseller: true,
    soldOutToday: false,
    thumbnail:
      'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=200&h=200&fit=crop',
    photoUrls: [],
    glbUrl: 'https://modelviewer.dev/shared-assets/models/MaterialsVariantsExamples.glb',
    orderDeepLink: 'https://example.com/order/p3',
  },
  {
    id: 'p4',
    slug: 'wooden-chair-demo',
    name: 'Wooden Dining Chair',
    price: '₹4,999',
    serves: '1 piece',
    calories: '—',
    rating: 4.3,
    isVeg: true,
    isSpicy: false,
    isBestseller: false,
    soldOutToday: false,
    thumbnail:
      'https://images.unsplash.com/photo-1506439773649-6e0eb8cfb237?w=200&h=200&fit=crop',
    photoUrls: [],
    glbUrl: 'https://modelviewer.dev/shared-assets/models/Chair.glb',
    orderDeepLink: 'https://example.com/order/p4',
  },
]

const delay = (ms = 400) => new Promise((r) => setTimeout(r, ms))

export const productService = {
  async getProducts(businessId?: string): Promise<Product[]> {
    await delay()
    void businessId
    return mockProducts
  },

  async getProduct(id: string): Promise<Product | undefined> {
    await delay(200)
    return mockProducts.find((p) => p.id === id)
  },
}

export function getShareUrl(productId: string, businessId = 'demo'): string {
  const base = window.location.origin + window.location.pathname
  return `${base}?business=${businessId}&product=${productId}`
}
