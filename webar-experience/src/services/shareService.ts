import { analyticsService } from '@/services/analyticsService'
import { getShareUrl } from '@/services/productService'
import type { Product } from '@/types/product'

export interface ShareResult {
  success: boolean
  method: 'native' | 'clipboard' | 'failed'
  message: string
}

export async function shareProductExperience(
  product: Product,
): Promise<ShareResult> {
  const url = getShareUrl(product.slug)
  const title = product.name
  const text = `${product.name} dekho 3D mein! AR Smart Menu`

  analyticsService.track('share', product.id)

  if (navigator.share) {
    try {
      await navigator.share({ title, text, url })
      return { success: true, method: 'native', message: 'Shared!' }
    } catch (err) {
      if ((err as Error).name === 'AbortError') {
        return { success: false, method: 'native', message: 'Share cancelled' }
      }
    }
  }

  try {
    await navigator.clipboard.writeText(`${text}\n${url}`)
    return { success: true, method: 'clipboard', message: 'Link copied!' }
  } catch {
    return { success: false, method: 'failed', message: 'Link copy nahi ho saki' }
  }
}
