import type { Product } from '@/types/product'

interface ProductPhotoStripProps {
  product: Product
}

export function ProductPhotoStrip({ product }: ProductPhotoStripProps) {
  if (product.photoUrls.length === 0) return null

  return (
    <div className="photo-strip-wrap">
      <p className="photo-strip-label">Owner photos</p>
      <div className="photo-strip">
        {product.photoUrls.map((url, index) => (
          <a
            key={`${url}-${index}`}
            href={url}
            target="_blank"
            rel="noreferrer"
            className="photo-thumb-link"
            aria-label={`View photo ${index + 1}`}
          >
            <img
              src={url}
              alt={`${product.name} photo ${index + 1}`}
              className="photo-thumb"
              loading={index === 0 ? 'eager' : 'lazy'}
              onError={(e) => {
                const img = e.currentTarget
                img.onerror = null
                img.src = ''
                img.classList.add('photo-thumb-broken')
                img.alt = 'Photo unavailable — re-upload in owner app'
              }}
            />
          </a>
        ))}
      </div>
    </div>
  )
}
