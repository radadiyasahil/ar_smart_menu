import type { Product } from '@/types/product'

interface ProductInfoOverlayProps {
  product: Product
}

export function ProductInfoOverlay({ product }: ProductInfoOverlayProps) {
  return (
    <div className="dish-info-card">
      <div className="dish-info-left">
        {product.thumbnail ? (
          <img
            src={product.thumbnail}
            alt={product.name}
            className="dish-thumb-main"
            loading="eager"
          />
        ) : (
          <div
            className={`veg-badge ${product.isVeg ? 'veg' : 'non-veg'}`}
            aria-label={product.isVeg ? 'Vegetarian' : 'Non-vegetarian'}
          />
        )}
        <div className="dish-info-text">
          <h1 className="dish-name">{product.name}</h1>
          <p className="dish-meta">{product.calories}</p>
          {product.description && (
            <p className="dish-description">{product.description}</p>
          )}
        </div>
      </div>
      <div className="dish-price">{product.price}</div>
    </div>
  )
}
