import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { analyticsService } from '@/services/analyticsService'
import { productService } from '@/services/productService'
import type { ArBusiness, ArExperience, ArStatus, Product, ScalePreset } from '@/types/product'

interface UseArViewerOptions {
  slug?: string
}

export function useArViewer({ slug }: UseArViewerOptions = {}) {
  const navigate = useNavigate()
  const modelViewerRef = useRef<HTMLElement | null>(null)

  const [experience, setExperience] = useState<ArExperience | null>(null)
  const [otherProducts, setOtherProducts] = useState<Product[]>([])
  const [business, setBusiness] = useState<ArBusiness | null>(null)
  const [activeProduct, setActiveProduct] = useState<Product | null>(null)
  const [isLoadingProducts, setIsLoadingProducts] = useState(true)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [isModelLoading, setIsModelLoading] = useState(true)
  const [modelProgress, setModelProgress] = useState(0)
  const [modelError, setModelError] = useState<string | null>(null)
  const [arUnavailable, setArUnavailable] = useState(false)
  const [showScanOverlay, setShowScanOverlay] = useState(true)
  const [rotationY, setRotationY] = useState(0)
  const [scale, setScale] = useState<ScalePreset>(1)

  useEffect(() => {
    async function load() {
      setIsLoadingProducts(true)
      setLoadError(null)
      setIsModelLoading(true)
      setModelProgress(0)
      setModelError(null)
      setRotationY(0)
      setScale(1)

      try {
        if (!slug) {
          setLoadError('Missing dish slug in URL.')
          setExperience(null)
          setActiveProduct(null)
          return
        }

        analyticsService.setSlug(slug)
        const data = await productService.getExperienceBySlug(slug)
        setExperience(data)
        setBusiness(data.business)
        setOtherProducts(data.otherProducts)
        setActiveProduct(data.product)
        document.title = `${data.product.name} — AR Smart Menu`

        await analyticsService.logScan(slug)
        analyticsService.track('ar_open', data.product.id)
      } catch (e) {
        if (slug) {
          // Fallback: If this slug is not a dish, check if it's actually a restaurant menu or table QR!
          try {
            const tableMatch = slug.match(/^(.*)-t(\d+)$/)
            const menuSlug = tableMatch ? tableMatch[1] : slug
            const tableParam = tableMatch
              ? `?table=${tableMatch[2]}`
              : (window.location.search || '')

            const menuData = await productService.fetchMenuBySlug(menuSlug)
            if (menuData && (menuData.slug || menuData.businessName)) {
              // It is a restaurant menu! Seamlessly redirect to the full menu page
              navigate(`/menu/${menuSlug}${tableParam}`, { replace: true })
              return
            }
          } catch {
            // Not a menu either, proceed to normal error display
          }
        }

        let message = 'Could not load this dish. Please try again.'
        if (e instanceof Error) {
          if (e.message.includes('404') || e.message === 'NOT_FOUND') {
            message = 'This dish is not available yet.'
          } else if (e.message.startsWith('NETWORK:')) {
            message = e.message.replace('NETWORK: ', '')
          }
        }
        setLoadError(message)
        setExperience(null)
        setActiveProduct(null)
      } finally {
        setIsLoadingProducts(false)
      }
    }

    void load()
  }, [slug])

  const switchProduct = useCallback(
    (product: Product) => {
      if (product.slug === slug) return
      navigate(`/dish/${product.slug}`)
    },
    [navigate, slug],
  )

  const rotateModel = useCallback(() => {
    setRotationY((prev) => {
      const next = (prev + 45) % 360
      analyticsService.track('rotation', activeProduct?.id, { degrees: next })
      return next
    })
  }, [activeProduct?.id])

  const cycleScale = useCallback(() => {
    setScale((prev) => {
      const order: ScalePreset[] = [1, 0.5, 1.25]
      const next = order[(order.indexOf(prev) + 1) % order.length]
      analyticsService.track('scale_change', activeProduct?.id, { scale: next })
      return next
    })
  }, [activeProduct?.id])

  const handleModelLoad = useCallback(() => {
    setIsModelLoading(false)
    setModelProgress(100)
    setModelError(null)
    analyticsService.track('model_load', activeProduct?.id, { success: true })
  }, [activeProduct?.id])

  const handleModelProgress = useCallback((progress: number) => {
    setModelProgress(progress)
    setIsModelLoading(progress < 1)
  }, [])

  const handleModelError = useCallback(() => {
    setIsModelLoading(false)
    setModelError('Failed to load 3D model. Check your connection and try again.')
    analyticsService.track('model_load', activeProduct?.id, { success: false })
  }, [activeProduct?.id])

  const handleArStatus = useCallback((status: ArStatus) => {
    if (status === 'object-placed' || status === 'session-started') {
      setShowScanOverlay(false)
    }
    if (status === 'failed') {
      setArUnavailable(true)
      analyticsService.track('ar_failed', undefined, { status })
    }
  }, [])

  const retryModel = useCallback(() => {
    setModelError(null)
    setIsModelLoading(true)
    setModelProgress(0)
    const el = modelViewerRef.current as HTMLModelViewerElement | null
    if (el && activeProduct) {
      el.src = activeProduct.glbUrl
    }
  }, [activeProduct])

  const scaleString = `${scale} ${scale} ${scale}`
  const orientationString = `0deg ${rotationY}deg 0deg`

  return {
    modelViewerRef,
    experience,
    business,
    otherProducts,
    activeProduct,
    isLoadingProducts,
    loadError,
    isModelLoading,
    modelProgress,
    modelError,
    arUnavailable,
    showScanOverlay,
    setShowScanOverlay,
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
  }
}

interface HTMLModelViewerElement extends HTMLElement {
  src: string
  activateAR: () => Promise<void>
}
