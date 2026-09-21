import { useState } from 'react'

import { analyticsService } from '@/services/analyticsService'
import type { Product } from '@/types/product'

interface BottomControlBarProps {
  product: Product
  onRotate: () => void
  onShare: () => Promise<{ message: string }>
}

export function BottomControlBar({
  product,
  onRotate,
  onShare,
}: BottomControlBarProps) {
  const [shareMessage, setShareMessage] = useState<string | null>(null)

  const handleShare = async () => {
    const result = await onShare()
    setShareMessage(result.message)
    setTimeout(() => setShareMessage(null), 2500)
  }

  const handleOrder = () => {
    analyticsService.track('add_to_order', product.id)
    analyticsService.flush()

    const url = product.orderDeepLink
    if (url && url !== '#order') {
      window.location.href = url
      return
    }

    const wa = `https://wa.me/?text=${encodeURIComponent(`I want to order ${product.name}`)}`
    window.open(wa, '_blank', 'noopener,noreferrer')
  }

  return (
    <div className="bottom-controls-wrap">
      {shareMessage && <div className="share-toast">{shareMessage}</div>}
      <div className="bottom-controls">
        <button type="button" className="ctrl-btn" onClick={onRotate} aria-label="Rotate model">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <path d="M21.5 2v6h-6M2.5 22v-6h6M2 11.5a10 10 0 0 1 18.8-4.3M22 12.5a10 10 0 0 1-18.8 4.2" />
          </svg>
          <span>Rotate</span>
        </button>

        <button type="button" className="ctrl-btn ctrl-btn-primary" onClick={handleOrder} aria-label="Add to order">
          <span>Add to order</span>
        </button>

        <button type="button" className="ctrl-btn" onClick={() => void handleShare()} aria-label="Share this dish">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <circle cx="18" cy="5" r="3" /><circle cx="6" cy="12" r="3" /><circle cx="18" cy="19" r="3" />
            <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" /><line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
          </svg>
          <span>Share</span>
        </button>
      </div>
    </div>
  )
}
