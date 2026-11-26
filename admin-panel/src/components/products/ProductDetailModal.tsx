import {
  AlertCircle,
  Box,
  Check,
  Download,
  Flame,
  Layers,
  PauseCircle,
  Play,
  RotateCw,
  Sparkles,
  Upload,
  Trash2,
  X,
  ZoomIn,
} from 'lucide-react'
import { useRef, useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { adminService } from '@/services/adminService'
import {
  PHOTO_ANGLE_LABELS,
  PRODUCT_CATEGORY_LABELS,
  PRODUCT_STATUS_LABELS,
  PROCESSING_STATUS_LABELS,
  VEG_STATUS_LABELS,
  type AdminProductReviewItem,
  formatPaise,
} from '@/types/admin'

interface ProductDetailModalProps {
  item: AdminProductReviewItem
  actionId: string | null
  onClose: () => void
  onApprove: (jobId: string, productId?: string) => void
  onReject: (item: AdminProductReviewItem) => void
  onPublish: (jobId: string, productId?: string) => void
  onEnqueue: (productId: string) => void
  onAdvanceToReview: (jobId: string) => void
  onSetStatus?: (productId: string, status: number) => void
  onRefresh?: () => void
}

export function ProductDetailModal({
  item,
  actionId,
  onClose,
  onApprove,
  onReject,
  onPublish,
  onEnqueue,
  onAdvanceToReview,
  onSetStatus,
  onRefresh,
}: ProductDetailModalProps) {
  const [selectedPhoto, setSelectedPhoto] = useState<string | null>(null)
  const [show3DViewer, setShow3DViewer] = useState(false)
  const [autoRotate3D, setAutoRotate3D] = useState(true)
  const [is3DLoading, setIs3DLoading] = useState(true)
  const [isDownloading, setIsDownloading] = useState(false)
  const [isUploadingGlb, setIsUploadingGlb] = useState(false)
  const [isDeletingGlb, setIsDeletingGlb] = useState(false)
  const [deletingPhotoId, setDeletingPhotoId] = useState<string | null>(null)
  const [statusNotice, setStatusNotice] = useState<string | null>(null)
  const glbInputRef = useRef<HTMLInputElement>(null)

  const handleUploadGlb = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    setIsUploadingGlb(true)
    setStatusNotice(null)
    try {
      await adminService.uploadProductModel(item.productId, file)
      setStatusNotice('3D Model (.glb) uploaded successfully! Dish is now Live.')
      if (onRefresh) onRefresh()
    } catch (err: unknown) {
      alert((err as { message?: string })?.message || 'Failed to upload 3D model')
    } finally {
      setIsUploadingGlb(false)
      if (glbInputRef.current) glbInputRef.current.value = ''
    }
  }

  const handleDeleteGlb = async () => {
    if (!window.confirm('Are you sure you want to delete this 3D model (.glb)? This will remove it from diner AR view.')) return
    setIsDeletingGlb(true)
    setStatusNotice(null)
    try {
      await adminService.deleteProductModel(item.productId)
      setStatusNotice('3D model deleted successfully.')
      if (onRefresh) onRefresh()
    } catch (err: unknown) {
      alert((err as { message?: string })?.message || 'Failed to delete 3D model')
    } finally {
      setIsDeletingGlb(false)
    }
  }

  const handleDeletePhoto = async (photoId: string) => {
    if (!window.confirm('Are you sure you want to delete this photo?')) return
    setDeletingPhotoId(photoId)
    setStatusNotice(null)
    try {
      await adminService.deleteProductPhoto(item.productId, photoId)
      setStatusNotice('Photo deleted successfully.')
      if (onRefresh) onRefresh()
    } catch (err: unknown) {
      alert((err as { message?: string })?.message || 'Failed to delete photo')
    } finally {
      setDeletingPhotoId(null)
    }
  }

  const handleDownloadGlb = async (e?: React.MouseEvent) => {
    if (e) e.preventDefault()
    if (!item.glbUrl) return
    setIsDownloading(true)
    try {
      const response = await fetch(item.glbUrl)
      if (!response.ok) throw new Error('Download request failed')
      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `${item.productName.replace(/[^\w\s-]/g, '').trim() || 'dish-3d-model'}.glb`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
    } catch {
      // Fallback direct link download
      const a = document.createElement('a')
      a.href = item.glbUrl
      a.target = '_blank'
      a.rel = 'noreferrer'
      a.download = `${item.productName.replace(/[^\w\s-]/g, '').trim() || 'dish-3d-model'}.glb`
      document.body.appendChild(a)
      a.click()
      document.body.removeChild(a)
    } finally {
      setIsDownloading(false)
    }
  }

  const vegInfo = VEG_STATUS_LABELS[item.vegStatus ?? 0] ?? VEG_STATUS_LABELS[0]
  const categoryLabel =
    item.category != null ? PRODUCT_CATEGORY_LABELS[item.category] ?? 'General' : 'General'

  const jobId = item.processingJobId
  const canEnqueue =
    item.photoCount >= 4 &&
    !jobId &&
    item.productStatus !== 4 &&
    item.productStatus !== 6
  const canAdvance =
    Boolean(jobId) &&
    item.productStatus !== 4 &&
    (item.jobStatus === 1 || item.jobStatus === 2)
  const canApproveOrReject =
    Boolean(jobId) &&
    item.productStatus !== 4 &&
    item.jobStatus !== 4 &&
    item.jobStatus !== 5 &&
    (item.jobStatus === 3 || item.jobStatus === 2)
  const canPublish = Boolean(jobId) && item.productStatus !== 4 && item.jobStatus === 4

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs">
      <Card className="flex max-h-[92vh] w-full max-w-3xl flex-col overflow-hidden shadow-2xl">
        {/* Modal Header */}
        <CardHeader className="flex flex-row items-center justify-between border-b border-border bg-muted/30 pb-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <CardTitle className="text-xl font-bold">{item.productName}</CardTitle>
              <span className="inline-flex items-center gap-1 rounded-full bg-primary/10 px-2.5 py-0.5 text-xs font-semibold text-primary">
                <Sparkles className="h-3 w-3" />
                Hero 3D Dish
              </span>
            </div>
            <p className="text-xs text-muted-foreground">
              Offered by <span className="font-medium text-foreground">{item.businessName}</span>
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose} className="h-8 w-8 p-0">
            <X className="h-5 w-5" />
          </Button>
        </CardHeader>

        {/* Modal Body */}
        <CardContent className="flex-1 space-y-6 overflow-y-auto p-6">
          {/* Quick Metrics Bar */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-lg border border-border bg-card p-3">
              <span className="text-xs text-muted-foreground">Price</span>
              <p className="text-lg font-bold text-foreground">
                {formatPaise(item.pricePaise)}
              </p>
            </div>
            <div className="rounded-lg border border-border bg-card p-3">
              <span className="text-xs text-muted-foreground">Food Type</span>
              <p className="flex items-center gap-1.5 text-sm font-semibold" style={{ color: vegInfo.color }}>
                <span className="inline-block h-2 w-2 rounded-full" style={{ backgroundColor: vegInfo.color }} />
                {vegInfo.label}
              </p>
            </div>
            <div className="rounded-lg border border-border bg-card p-3">
              <span className="text-xs text-muted-foreground">Category</span>
              <p className="text-sm font-semibold text-foreground">{categoryLabel}</p>
            </div>
            <div className="rounded-lg border border-border bg-card p-3">
              <span className="text-xs text-muted-foreground">Product Status</span>
              <p className="text-sm font-semibold text-foreground">
                {PRODUCT_STATUS_LABELS[item.productStatus] ?? item.productStatus}
              </p>
            </div>
          </div>

          {/* Tags */}
          <div className="flex flex-wrap items-center gap-2">
            {item.isBestseller && (
              <Badge variant="warning" className="gap-1">
                <Sparkles className="h-3 w-3" /> Bestseller
              </Badge>
            )}
            {item.isSpicy && (
              <Badge variant="danger" className="gap-1">
                <Flame className="h-3 w-3" /> Spicy
              </Badge>
            )}
            {item.isNew && (
              <Badge variant="info" className="gap-1">
                New Dish
              </Badge>
            )}
            <Badge variant="muted" className="gap-1 text-xs">
              <Layers className="h-3 w-3" />
              {item.photoCount}/4 Photogrammetry Angles
            </Badge>
          </div>

          {/* Description */}
          {item.description && (
            <div className="space-y-1 rounded-lg border border-border bg-muted/20 p-3">
              <span className="text-xs font-semibold text-muted-foreground">Description</span>
              <p className="text-sm text-foreground">{item.description}</p>
            </div>
          )}

          {/* 4-Angle Photos Gallery */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <h4 className="text-sm font-semibold text-foreground">
                {item.isHero === false
                  ? `Standard (2D) Display Photo (${((item.photos?.length ?? item.photoCount) || 1)} Photo)`
                  : `Photogrammetry Source Photos (${item.photos?.length ?? item.photoCount}/4)`}
              </h4>
              <span className="text-xs text-muted-foreground">
                Click any photo to enlarge
              </span>
            </div>

            {statusNotice && (
              <div className="rounded-md bg-primary/10 p-2.5 text-xs text-primary border border-primary/20 flex items-center justify-between">
                <span>{statusNotice}</span>
                <button type="button" onClick={() => setStatusNotice(null)} className="text-primary hover:opacity-70">
                  <X className="h-3.5 w-3.5" />
                </button>
              </div>
            )}

            {item.photos && item.photos.length > 0 ? (
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
                {item.photos.map((ph) => {
                  const angleName =
                    PHOTO_ANGLE_LABELS[ph.angleType] ?? `Angle ${ph.angleType}`
                  return (
                    <div
                      key={ph.id}
                      className="group relative cursor-pointer overflow-hidden rounded-lg border border-border bg-muted/30 transition hover:border-primary"
                      onClick={() => setSelectedPhoto(ph.photoUrl)}
                    >
                      <div className="aspect-square w-full overflow-hidden bg-black/5">
                        <img
                          src={ph.photoUrl}
                          alt={angleName}
                          className="h-full w-full object-cover transition group-hover:scale-105"
                          loading="lazy"
                        />
                      </div>
                      <div className="absolute inset-0 flex items-center justify-center bg-black/40 opacity-0 transition group-hover:opacity-100">
                        <ZoomIn className="h-6 w-6 text-white" />
                      </div>
                      <button
                        type="button"
                        disabled={deletingPhotoId === ph.id}
                        className="absolute top-1.5 right-1.5 z-10 rounded-full bg-red-600/90 p-1 text-white opacity-80 hover:opacity-100 shadow-sm transition hover:scale-110"
                        title="Delete photo"
                        onClick={(e) => {
                          e.stopPropagation()
                          handleDeletePhoto(ph.id)
                        }}
                      >
                        <Trash2 className="h-3 w-3" />
                      </button>
                      <div className="p-2 text-center">
                        <span className="text-xs font-semibold text-foreground">
                          {angleName}
                        </span>
                      </div>
                    </div>
                  )
                })}
              </div>
            ) : (
              <div className="rounded-lg border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
                No direct photo preview URLs available ({item.photoCount} photos uploaded by owner).
              </div>
            )}
          </div>

          {/* 3D Model & AR Pipeline Status */}
          <div className="rounded-lg border border-border bg-card p-4 space-y-3">
            <input
              ref={glbInputRef}
              type="file"
              accept=".glb"
              className="hidden"
              onChange={handleUploadGlb}
            />
            <div className="flex items-center justify-between">
              <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
                <Layers className="h-4 w-4 text-primary" />
                3D AR Pipeline & Reconstruction
              </h4>
              <span className="text-xs text-muted-foreground">
                {item.jobStatus != null
                  ? `Pipeline: ${PROCESSING_STATUS_LABELS[item.jobStatus] ?? item.jobStatus}`
                  : 'Pipeline: Not started'}
              </span>
            </div>

            {item.glbUrl ? (
              <div className="rounded-md bg-success/10 p-3 text-sm text-success border border-success/30 space-y-2.5 sm:space-y-0 sm:flex sm:items-center sm:justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Check className="h-4 w-4 shrink-0" />
                  <span className="font-semibold">3D GLB Model generated and ready!</span>
                </div>
                <div className="flex items-center gap-2 shrink-0 flex-wrap">
                  {/* Option 1: Interactive 3D View */}
                  <Button
                    type="button"
                    size="sm"
                    className="h-8 gap-1.5 bg-primary text-white hover:bg-primary/90 text-xs font-semibold shadow-xs"
                    onClick={() => {
                      setIs3DLoading(true)
                      setShow3DViewer(true)
                    }}
                  >
                    <Box className="h-3.5 w-3.5" />
                    <span>See 3D View</span>
                  </Button>

                  {/* Option 2: Download .GLB File */}
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-8 gap-1.5 border-border bg-card text-foreground hover:bg-muted text-xs font-semibold shadow-xs"
                    onClick={handleDownloadGlb}
                    disabled={isDownloading}
                    title="Download .glb 3D model file directly"
                  >
                    <Download className={`h-3.5 w-3.5 ${isDownloading ? 'animate-bounce' : 'text-muted-foreground'}`} />
                    <span>{isDownloading ? 'Downloading...' : 'Download GLB'}</span>
                  </Button>

                  {/* Option 3: Replace .GLB */}
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-8 gap-1.5 border-primary/50 text-primary hover:bg-primary/10 text-xs font-semibold shadow-xs"
                    onClick={() => glbInputRef.current?.click()}
                    disabled={isUploadingGlb}
                    title="Replace the .glb 3D model file"
                  >
                    <Upload className={`h-3.5 w-3.5 ${isUploadingGlb ? 'animate-spin' : ''}`} />
                    <span>{isUploadingGlb ? 'Uploading...' : 'Replace GLB'}</span>
                  </Button>

                  {/* Option 4: Delete 3D Model */}
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-8 gap-1.5 border-danger/50 text-danger hover:bg-danger/10 text-xs font-semibold shadow-xs"
                    onClick={handleDeleteGlb}
                    disabled={isDeletingGlb}
                    title="Delete 3D model from product"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    <span>{isDeletingGlb ? 'Deleting...' : 'Delete 3D'}</span>
                  </Button>
                </div>
              </div>
            ) : (
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-3 rounded-md bg-muted/40 border border-border">
                <p className="text-xs text-muted-foreground">
                  3D photogrammetry model has not been published yet. Upload a ready .glb model to activate interactive 3D AR immediately.
                </p>
                <Button
                  type="button"
                  size="sm"
                  className="h-8 gap-1.5 bg-primary text-white hover:bg-primary/90 text-xs font-semibold shrink-0"
                  onClick={() => glbInputRef.current?.click()}
                  disabled={isUploadingGlb}
                >
                  <Upload className={`h-3.5 w-3.5 ${isUploadingGlb ? 'animate-spin' : ''}`} />
                  <span>{isUploadingGlb ? 'Uploading...' : 'Upload .GLB'}</span>
                </Button>
              </div>
            )}

            {item.rejectionReason && (
              <div className="rounded-md bg-danger/10 p-3 text-xs text-danger border border-danger/30 flex items-start gap-2">
                <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
                <div>
                  <span className="font-semibold">Rejection Feedback: </span>
                  {item.rejectionReason}
                </div>
              </div>
            )}

            {item.productStatus === 5 && (
              <div className="rounded-md bg-amber-500/10 p-3 text-xs text-amber-700 dark:text-amber-400 border border-amber-500/30 flex items-start gap-2">
                <PauseCircle className="h-4 w-4 shrink-0 mt-0.5" />
                <div>
                  <span className="font-semibold">Dish Currently Paused: </span>
                  This dish is temporarily removed from diner AR menus. All 3D assets, photos, and configurations remain 100% saved. Click "Publish back to Live" below to restore it instantly.
                </div>
              </div>
            )}
          </div>
        </CardContent>

        {/* Modal Action Footer */}
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border bg-muted/20 px-6 py-4">
          <Button variant="outline" size="sm" onClick={onClose}>
            Close
          </Button>

          <div className="flex flex-wrap items-center gap-2">
            {/* If product is Live (status 4): Option to Remove from Live (Pause) */}
            {item.productStatus === 4 && onSetStatus && (
              <Button
                size="sm"
                variant="outline"
                className="text-warning border-warning/30 hover:bg-warning/10"
                disabled={actionId === item.productId}
                onClick={() => onSetStatus(item.productId, 5)}
                title="Remove dish from diner AR menu (preserves 3D assets & details, 100% reversible)"
              >
                <PauseCircle className="mr-1.5 h-4 w-4" />
                Remove from Live (Pause)
              </Button>
            )}

            {/* If product is Paused (status 5): Reverse strategy to Publish back to Live */}
            {item.productStatus === 5 && onSetStatus && (
              <Button
                size="sm"
                className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                disabled={actionId === item.productId}
                onClick={() => onSetStatus(item.productId, 4)}
                title="Reverse strategy: Publish dish back to diner live AR menu immediately"
              >
                <Play className="mr-1.5 h-4 w-4 fill-current" />
                Publish back to Live
              </Button>
            )}

            {canEnqueue && (
              <Button
                size="sm"
                variant="outline"
                disabled={actionId === item.productId}
                onClick={() => onEnqueue(item.productId)}
              >
                Run 3D Processing
              </Button>
            )}

            {canAdvance && jobId && (
              <Button
                size="sm"
                variant="outline"
                disabled={actionId === jobId}
                onClick={() => onAdvanceToReview(jobId)}
              >
                Mark for Review
              </Button>
            )}

            {canApproveOrReject && jobId && (
              <>
                <Button
                  size="sm"
                  className="bg-emerald-600 hover:bg-emerald-700 text-white"
                  disabled={actionId === jobId}
                  onClick={() => onApprove(jobId, item.productId)}
                >
                  <Check className="mr-1.5 h-4 w-4" />
                  Approve 3D Model
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  disabled={actionId === jobId}
                  onClick={() => onReject(item)}
                >
                  <X className="mr-1.5 h-4 w-4" />
                  Reject Dish
                </Button>
              </>
            )}

            {canPublish && jobId && (
              <Button
                size="sm"
                className="bg-primary hover:bg-primary/90 text-white"
                disabled={actionId === jobId}
                onClick={() => onPublish(jobId, item.productId)}
              >
                <Upload className="mr-1.5 h-4 w-4" />
                Publish Live in AR
              </Button>
            )}
          </div>
        </div>
      </Card>

      {/* Lightbox / Zoom view */}
      {selectedPhoto && (
        <div
          className="fixed inset-0 z-60 flex items-center justify-center bg-black/90 p-4"
          onClick={() => setSelectedPhoto(null)}
        >
          <div className="relative max-h-[90vh] max-w-3xl overflow-hidden rounded-lg">
            <img
              src={selectedPhoto}
              alt="Enlarged angle"
              className="max-h-[85vh] w-auto rounded-lg object-contain"
            />
            <Button
              variant="outline"
              size="sm"
              className="absolute top-2 right-2 bg-black/60 text-white hover:bg-black/90"
              onClick={() => setSelectedPhoto(null)}
            >
              <X className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}

      {/* Interactive 3D Model Viewer Modal */}
      {show3DViewer && item.glbUrl && (
        <div
          className="fixed inset-0 z-60 flex items-center justify-center bg-black/85 backdrop-blur-sm p-3 sm:p-5 animate-in fade-in-0"
          onClick={() => setShow3DViewer(false)}
        >
          <div
            className="relative flex flex-col w-full max-w-2xl max-h-[92vh] overflow-hidden rounded-2xl border border-border bg-card shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between border-b border-border bg-muted/40 px-5 py-3.5">
              <div className="flex items-center gap-2.5 min-w-0">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-primary/10 text-primary">
                  <Box className="h-5 w-5" />
                </div>
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <h3 className="text-base font-bold text-foreground truncate">
                      {item.productName}
                    </h3>
                    <span className="shrink-0 rounded-full bg-success/15 px-2 py-0.5 text-[10px] font-bold text-success border border-success/30">
                      3D Model
                    </span>
                  </div>
                  <p className="text-xs text-muted-foreground truncate">
                    Offered by <span className="font-medium text-foreground">{item.businessName}</span>
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                {/* Download button in modal header */}
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  className="h-8 gap-1.5 border-border bg-card text-foreground hover:bg-muted text-xs font-semibold"
                  onClick={handleDownloadGlb}
                  disabled={isDownloading}
                  title="Download .glb 3D asset file"
                >
                  <Download className={`h-3.5 w-3.5 ${isDownloading ? 'animate-bounce' : 'text-muted-foreground'}`} />
                  <span className="hidden sm:inline">{isDownloading ? 'Downloading...' : 'Download GLB'}</span>
                </Button>

                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 text-muted-foreground hover:text-foreground hover:bg-muted"
                  onClick={() => setShow3DViewer(false)}
                  aria-label="Close 3D viewer"
                >
                  <X className="h-5 w-5" />
                </Button>
              </div>
            </div>

            {/* 3D Model Viewer Canvas */}
            <div className="relative h-[380px] sm:h-[460px] w-full bg-gradient-to-b from-[#141d2e] via-[#0b0f19] to-[#06080e] flex items-center justify-center overflow-hidden">
              {is3DLoading && (
                <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2.5 bg-card/75 backdrop-blur-xs">
                  <div className="h-9 w-9 animate-spin rounded-full border-3 border-primary/20 border-t-primary" />
                  <span className="text-xs font-semibold text-foreground">Rendering 3D Model...</span>
                  <span className="text-[11px] text-muted-foreground">Interactive 360° GLB viewport</span>
                </div>
              )}

              <model-viewer
                src={item.glbUrl}
                alt={item.productName}
                camera-controls
                auto-rotate={autoRotate3D}
                rotation-per-second="25deg"
                touch-action="pan-y"
                shadow-intensity="1.2"
                shadow-softness="0.7"
                exposure="1.2"
                environment-image="neutral"
                loading="eager"
                interaction-prompt="none"
                style={{ width: '100%', height: '100%', outline: 'none' }}
                ref={(el) => {
                  if (el) {
                    el.addEventListener('load', () => setIs3DLoading(false), { once: true })
                    el.addEventListener('error', () => setIs3DLoading(false), { once: true })
                  }
                }}
              />

              {/* Interactive Toolbar Overlay */}
              <div className="absolute bottom-3 inset-x-3 sm:inset-x-auto sm:left-4 flex items-center justify-between sm:justify-start gap-2 rounded-xl border border-border/80 bg-card/90 px-3 py-1.5 shadow-xl backdrop-blur-md">
                <button
                  type="button"
                  className={`flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
                    autoRotate3D
                      ? 'bg-primary text-white shadow-xs'
                      : 'text-muted-foreground hover:text-foreground hover:bg-muted'
                  }`}
                  onClick={() => setAutoRotate3D((v) => !v)}
                  title="Toggle 360° automatic rotation"
                >
                  <RotateCw className={`h-3.5 w-3.5 ${autoRotate3D ? 'animate-spin' : ''}`} />
                  <span>{autoRotate3D ? 'Auto-Rotating' : 'Auto-Rotate'}</span>
                </button>
                <div className="h-4 w-px bg-border shrink-0" />
                <span className="text-[11px] text-muted-foreground select-none">
                  🖱️ Drag to orbit • Scroll to zoom
                </span>
              </div>
            </div>

            {/* Footer with format and close actions */}
            <div className="flex items-center justify-between border-t border-border bg-muted/20 px-5 py-3 text-xs">
              <div className="flex items-center gap-2 text-muted-foreground">
                <Sparkles className="h-3.5 w-3.5 text-primary" />
                <span>Format: <strong className="text-foreground">GLB (Binary glTF 2.0)</strong></span>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs font-semibold"
                  onClick={() => setShow3DViewer(false)}
                >
                  Close Preview
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
