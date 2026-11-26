import { useEffect, type RefObject } from 'react'

import type { ArStatus } from '@/types/product'

interface ModelViewerProps {
  viewerRef: RefObject<HTMLElement | null>
  glbUrl: string
  usdzUrl?: string
  posterUrl?: string
  alt: string
  scale: string
  orientation: string
  onLoad: () => void
  onProgress: (progress: number) => void
  onError: () => void
  onArStatus: (status: ArStatus) => void
}

export function ModelViewer({
  viewerRef,
  glbUrl,
  usdzUrl,
  posterUrl,
  alt,
  scale,
  orientation,
  onLoad,
  onProgress,
  onError,
  onArStatus,
}: ModelViewerProps) {
  // Prefer in-browser WebXR hit-test (table surface), then Android Scene Viewer, then iOS Quick Look
  const arModes = 'webxr scene-viewer quick-look'
  const safeUsdz =
    usdzUrl && !usdzUrl.includes('Hamburger.usdz') ? usdzUrl : undefined

  useEffect(() => {
    const el = viewerRef.current
    if (!el) return

    const handleLoad = () => onLoad()
    const handleError = () => onError()
    const handleProgress = (e: Event) => {
      const detail = (e as CustomEvent).detail
      if (detail?.totalProgress != null) {
        onProgress(detail.totalProgress)
      }
    }
    const handleArStatus = (e: Event) => {
      const detail = (e as CustomEvent).detail
      const status = detail?.status as ArStatus
      if (status) onArStatus(status)
    }

    el.addEventListener('load', handleLoad)
    el.addEventListener('error', handleError)
    el.addEventListener('progress', handleProgress)
    el.addEventListener('ar-status', handleArStatus)

    return () => {
      el.removeEventListener('load', handleLoad)
      el.removeEventListener('error', handleError)
      el.removeEventListener('progress', handleProgress)
      el.removeEventListener('ar-status', handleArStatus)
    }
  }, [viewerRef, onLoad, onError, onProgress, onArStatus, glbUrl])

  const setRef = (el: HTMLElement | null) => {
    viewerRef.current = el
  }

  return (
    <model-viewer
      ref={setRef}
      src={glbUrl}
      ios-src={safeUsdz}
      poster={posterUrl}
      alt={alt}
      ar
      ar-modes={arModes}
      ar-placement="floor"
      ar-scale="fixed"
      camera-controls
      touch-action="pan-y"
      shadow-intensity="1.2"
      shadow-softness="0.9"
      exposure="1.15"
      environment-image="neutral"
      loading="eager"
      reveal="auto"
      interaction-prompt="none"
      camera-orbit="0deg 65deg 105%"
      field-of-view="28deg"
      scale={scale}
      orientation={orientation}
      style={{ width: '100%', height: '100%', background: '#111' }}
    >
      <button
        slot="ar-button"
        className="ar-launch-btn"
        aria-label="Place dish on your table in AR"
      >
        <span>📷 Place on Table</span>
      </button>
      <div slot="ar-prompt" className="ar-prompt">
        <p>Point at a flat table, then tap to place the dish</p>
      </div>
    </model-viewer>
  )
}
