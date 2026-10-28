import {
  AlertCircle,
  Check,
  ExternalLink,
  Flame,
  Layers,
  PauseCircle,
  Play,
  Sparkles,
  Upload,
  X,
  ZoomIn,
} from 'lucide-react'
import { useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
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
  onApprove: (jobId: string) => void
  onReject: (item: AdminProductReviewItem) => void
  onPublish: (jobId: string) => void
  onEnqueue: (productId: string) => void
  onAdvanceToReview: (jobId: string) => void
  onSetStatus?: (productId: string, status: number) => void
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
}: ProductDetailModalProps) {
  const [selectedPhoto, setSelectedPhoto] = useState<string | null>(null)

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
                Photogrammetry Source Photos ({item.photos?.length ?? item.photoCount}/4)
              </h4>
              <span className="text-xs text-muted-foreground">
                Click any photo to enlarge
              </span>
            </div>

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
              <div className="flex items-center justify-between rounded-md bg-success/10 p-3 text-sm text-success border border-success/30">
                <div className="flex items-center gap-2">
                  <Check className="h-4 w-4" />
                  <span>3D GLB Model generated and ready!</span>
                </div>
                <a
                  href={item.glbUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="flex items-center gap-1 font-semibold underline text-xs"
                >
                  View 3D Asset <ExternalLink className="h-3 w-3" />
                </a>
              </div>
            ) : (
              <p className="text-xs text-muted-foreground">
                3D photogrammetry model has not been published yet. Once the pipeline completes,
                the admin approves the model and publishes it live to customer AR menus.
              </p>
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
                  onClick={() => onApprove(jobId)}
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
                onClick={() => onPublish(jobId)}
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
    </div>
  )
}
