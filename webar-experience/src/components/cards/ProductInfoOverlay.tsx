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
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', flexWrap: 'wrap' }}>
            <h1
              className="dish-name"
              style={product.soldOutToday ? { textDecoration: 'line-through', opacity: 0.7 } : undefined}
            >
              {product.name}
            </h1>
            {product.soldOutToday && (
              <span
                style={{
                  fontSize: '10px',
                  fontWeight: 700,
                  padding: '2px 8px',
                  borderRadius: '12px',
                  background: 'rgba(239, 68, 68, 0.2)',
                  color: '#fca5a5',
                  border: '1px solid rgba(239, 68, 68, 0.4)',
                }}
              >
                Sold Out Today
              </span>
            )}
          </div>
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
