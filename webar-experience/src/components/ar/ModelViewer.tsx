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
  const arModes = 'webxr scene-viewer quick-look'

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
      ios-src={usdzUrl}
      poster={posterUrl}
      alt={alt}
      ar
      ar-modes={arModes}
      ar-placement="floor"
      ar-scale="fixed"
      camera-controls
      auto-rotate
      auto-rotate-delay="0"
      rotation-per-second="30deg"
      touch-action="pan-y"
      shadow-intensity="1"
      shadow-softness="0.8"
      exposure="1.2"
      environment-image="neutral"
      loading="eager"
      reveal="auto"
      interaction-prompt="none"
      scale={scale}
      orientation={orientation}
      style={{ width: '100%', height: '100%', background: '#1a1a1a' }}
    >
      <button
        slot="ar-button"
        className="ar-launch-btn"
        aria-label="View on your table in AR"
      >
        <span>View in AR</span>
      </button>
      <div slot="ar-prompt" className="ar-prompt">
        <p>Move your phone over the table</p>
      </div>
    </model-viewer>
  )
}
