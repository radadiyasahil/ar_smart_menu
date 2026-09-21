import { cn } from '@/utils/cn'
import type { Product } from '@/types/product'

interface ProductCarouselProps {
  businessName: string
  products: Product[]
  activeSlug: string
  onSelect: (product: Product) => void
}

export function ProductCarousel({
  businessName,
  products,
  activeSlug,
  onSelect,
}: ProductCarouselProps) {
  if (products.length === 0) return null

  return (
    <div className="other-dishes-section">
      <p className="other-dishes-label">{businessName}</p>
      <div className="other-dishes-strip">
        {products.map((product) => {
          const isActive = product.slug === activeSlug
          return (
            <button
              key={product.slug}
              type="button"
              className={cn('dish-thumb-card', isActive && 'active')}
              onClick={() => onSelect(product)}
              aria-label={`View ${product.name} in AR`}
              aria-current={isActive ? 'true' : undefined}
            >
              <div className="dish-thumb-name">{product.name}</div>
              <div className="dish-thumb-price">{product.price}</div>
            </button>
          )
        })}
      </div>
    </div>
  )
}
