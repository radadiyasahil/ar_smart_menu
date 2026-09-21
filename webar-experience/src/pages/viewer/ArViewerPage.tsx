import { useCallback } from 'react'
import { Link, useParams, useSearchParams } from 'react-router-dom'

import { ModelViewer } from '@/components/ar/ModelViewer'
import { ProductInfoOverlay } from '@/components/cards/ProductInfoOverlay'
import { ProductPhotoStrip } from '@/components/cards/ProductPhotoStrip'
import { BottomControlBar } from '@/components/controls/BottomControlBar'
import { ProductCarousel } from '@/components/controls/ProductCarousel'
import { ScaleControl } from '@/components/controls/ScaleControl'
import { useArViewer } from '@/hooks/useArViewer'
import { shareProductExperience } from '@/services/shareService'

export function ArViewerPage() {
  const { slug: routeSlug } = useParams()
  const [searchParams] = useSearchParams()
  const slug = routeSlug ?? searchParams.get('slug') ?? undefined

  const {
    modelViewerRef,
    business,
    otherProducts,
    activeProduct,
    isLoadingProducts,
    loadError,
    isModelLoading,
    modelProgress,
    modelError,
    arUnavailable,
    scale,
    scaleString,
    orientationString,
    switchProduct,
    rotateModel,
    cycleScale,
    handleModelLoad,
    handleModelProgress,
    handleModelError,
    handleArStatus,
    retryModel,
  } = useArViewer({ slug })

  const handleShare = useCallback(async () => {
    if (!activeProduct) return { message: 'No product selected' }
    const result = await shareProductExperience(activeProduct)
    return { message: result.message }
  }, [activeProduct])

  if (!slug) {
    return (
      <div id="error-screen">
        <div className="error-icon">ℹ️</div>
        <h2 className="error-title">Invalid link</h2>
        <p className="error-sub">
          Open a dish URL like <code>/dish/pizza-0znr</code> or scan the restaurant QR code.
        </p>
        <Link to="/" className="btn-retry home-link-btn">
          Back to home
        </Link>
      </div>
    )
  }

  if (isLoadingProducts) {
    return (
      <div id="loading-screen">
        <div className="loading-spinner" />
        <p className="loading-text">Loading dish...</p>
      </div>
    )
  }

  if (loadError || !activeProduct) {
    return (
      <div id="error-screen">
        <div className="error-icon">⚠️</div>
        <h2 className="error-title">Could not load dish</h2>
        <p className="error-sub">{loadError ?? 'Please try again.'}</p>
        <button type="button" className="btn-retry" onClick={() => window.location.reload()}>
          Try again
        </button>
        <Link to="/" className="home-back-link">
          Back to home
        </Link>
      </div>
    )
  }

  return (
    <div id="ar-container">
      <ModelViewer
        viewerRef={modelViewerRef}
        glbUrl={activeProduct.glbUrl}
        usdzUrl={activeProduct.usdzUrl}
        posterUrl={activeProduct.thumbnail || undefined}
        alt={activeProduct.name}
        scale={scaleString}
        orientation={orientationString}
        onLoad={handleModelLoad}
        onProgress={handleModelProgress}
        onError={handleModelError}
        onArStatus={handleArStatus}
      />

      {arUnavailable && (
        <div className="no-ar-banner visible">
          AR is not available on this device — you can still view the 3D model
        </div>
      )}

      {isModelLoading && (
        <div className="model-loading">
          <div className="model-loading-bar">
            <div
              className="model-loading-fill"
              style={{ width: `${Math.round(modelProgress * 100)}%` }}
            />
          </div>
          <p className="model-loading-text">
            Loading 3D model... {Math.round(modelProgress * 100)}%
          </p>
        </div>
      )}

      {modelError && (
        <div className="model-error-overlay">
          <p>{modelError}</p>
          <button type="button" className="btn-retry" onClick={retryModel}>
            Try again
          </button>
        </div>
      )}

      <div className="dish-info-wrap">
        <ProductInfoOverlay product={activeProduct} />
        <ProductPhotoStrip product={activeProduct} />
      </div>

      <ScaleControl activeScale={scale} onCycle={cycleScale} />

      <BottomControlBar
        product={activeProduct}
        onRotate={rotateModel}
        onShare={handleShare}
      />

      {business && (
        <ProductCarousel
          businessName={business.name}
          products={otherProducts}
          activeSlug={activeProduct.slug}
          onSelect={switchProduct}
        />
      )}
    </div>
  )
}
