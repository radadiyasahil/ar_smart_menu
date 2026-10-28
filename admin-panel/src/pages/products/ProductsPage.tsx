import { Check, Eye, Package, PauseCircle, Play, RefreshCw, Sparkles, Upload, X } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { ProductDetailModal } from '@/components/products/ProductDetailModal'
import { RejectProductDialog } from '@/components/products/RejectProductDialog'
import { StatusBadge } from '@/components/tables/DataTable'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { adminService } from '@/services/adminService'
import {
  PROCESSING_STATUS_LABELS,
  PRODUCT_CATEGORY_LABELS,
  PRODUCT_STATUS_LABELS,
  VEG_STATUS_LABELS,
  type AdminProductReviewItem,
  formatPaise,
} from '@/types/admin'

type ReviewFilter = 'pending' | 'approved' | 'live' | 'paused' | 'all'

const FILTER_TABS: { label: string; value: ReviewFilter }[] = [
  { label: 'Pending Hero Review', value: 'pending' },
  { label: 'Ready to Publish Live', value: 'approved' },
  { label: 'Live in AR', value: 'live' },
  { label: 'Paused Dishes', value: 'paused' },
  { label: 'All Hero Products', value: 'all' },
]

function jobStatusForFilter(filter: ReviewFilter): number | undefined {
  if (filter === 'pending') return 3
  if (filter === 'approved') return 4
  return undefined
}

function statusBadgeKey(jobStatus?: number | null): string {
  switch (jobStatus) {
    case 3:
      return 'pending'
    case 4:
      return 'active'
    case 5:
    case 6:
      return 'rejected'
    case 1:
    case 2:
      return 'pending'
    default:
      return 'pending'
  }
}

function jobStatusLabel(item: AdminProductReviewItem): string {
  if (item.jobStatus != null) {
    return PROCESSING_STATUS_LABELS[item.jobStatus] ?? String(item.jobStatus)
  }
  if (item.photoCount >= 4 && item.productStatus <= 3) {
    return 'Awaiting Pipeline'
  }
  return '—'
}

function isStuckInPipeline(jobStatus?: number | null): boolean {
  return jobStatus === 1 || jobStatus === 2
}

function canApproveOrReject(item: AdminProductReviewItem): boolean {
  if (!item.processingJobId || item.productStatus === 4) return false
  if (item.jobStatus === 4 || item.jobStatus === 5) return false
  return item.jobStatus === 3 || item.jobStatus === 2
}

function canPublishLive(item: AdminProductReviewItem): boolean {
  if (!item.processingJobId || item.productStatus === 4) return false
  return item.jobStatus === 4
}

function canAdvanceToReview(item: AdminProductReviewItem): boolean {
  if (!item.processingJobId || item.productStatus === 4) return false
  return isStuckInPipeline(item.jobStatus)
}

export function ProductsPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const initialFilter = (searchParams.get('filter') as ReviewFilter) ?? 'all'

  const [items, setItems] = useState<AdminProductReviewItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [filter, setFilter] = useState<ReviewFilter>(initialFilter)
  const [actionId, setActionId] = useState<string | null>(null)
  const [rejectTarget, setRejectTarget] = useState<AdminProductReviewItem | null>(null)
  const [selectedProduct, setSelectedProduct] = useState<AdminProductReviewItem | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await adminService.getProductReviewQueue(jobStatusForFilter(filter))
      let filtered = data
      if (filter === 'live') {
        filtered = data.filter((p) => p.productStatus === 4)
      } else if (filter === 'paused') {
        filtered = data.filter((p) => p.productStatus === 5)
      }
      setItems(filtered)
      // Keep selectedProduct in sync if open
      if (selectedProduct) {
        const refreshed = data.find((p) => p.productId === selectedProduct.productId)
        if (refreshed) setSelectedProduct(refreshed)
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load products')
    } finally {
      setLoading(false)
    }
  }, [filter, selectedProduct])

  useEffect(() => {
    void load()
  }, [filter])

  const setFilterAndUrl = (value: ReviewFilter) => {
    setFilter(value)
    setSearchParams(value === 'all' ? {} : { filter: value })
  }

  const runAction = async (id: string, action: () => Promise<void>) => {
    setActionId(id)
    try {
      await action()
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Action failed')
    } finally {
      setActionId(null)
    }
  }

  const handleSetProductStatus = (productId: string, status: number) =>
    void runAction(productId, async () => {
      await adminService.setProductStatus(productId, status)
      if (selectedProduct?.productId === productId) {
        setSelectedProduct((prev) => (prev ? { ...prev, productStatus: status } : null))
      }
    })

  const handleApprove = (jobId: string) =>
    void runAction(jobId, () => adminService.submitQualityReview(jobId, 1))

  const handleRejectConfirm = (reason: string, improvementNotes: string) => {
    const target = rejectTarget
    if (!target?.processingJobId) return
    const jobId = target.processingJobId
    void runAction(jobId, async () => {
      await adminService.submitQualityReview(jobId, 2, reason, improvementNotes)
      setRejectTarget(null)
      if (selectedProduct?.productId === target.productId) {
        setSelectedProduct(null)
      }
    })
  }

  const handlePublish = (jobId: string) =>
    void runAction(jobId, () => adminService.publishProcessingJob(jobId))

  const handleEnqueue = (productId: string) =>
    void runAction(productId, () => adminService.enqueueProductProcessing(productId))

  const handleAdvanceToReview = (jobId: string) =>
    void runAction(jobId, () => adminService.advanceJobToReview(jobId))

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-bold tracking-tight text-foreground">
            <Package className="h-6 w-6 text-primary" />
            Hero 3D Product Approvals
          </h2>
          <p className="text-sm text-muted-foreground">
            Review 4-angle photogrammetry photos, inspect dish details, approve 3D models & publish live.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Auto-Approval Information Banner */}
      <div className="rounded-lg border border-primary/20 bg-primary/5 p-4 text-xs text-foreground flex items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-primary shrink-0" />
          <span>
            <strong>Smart AR Policy:</strong> Standard dishes without 3D AR are <strong>auto-approved directly to Live</strong>.
            Only <strong>Hero 3D AR dishes</strong> requiring photogrammetry reconstruction are queued here for review.
          </span>
        </div>
        <Badge variant="muted" className="shrink-0 bg-background">
          Hero Pipeline Active
        </Badge>
      </div>

      {/* Filter Tabs */}
      <div className="flex flex-wrap gap-2">
        {FILTER_TABS.map((tab) => (
          <Button
            key={tab.value}
            size="sm"
            variant={filter === tab.value ? 'default' : 'outline'}
            onClick={() => setFilterAndUrl(tab.value)}
          >
            {tab.label}
          </Button>
        ))}
      </div>

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">{error}</div>
      )}

      {/* Products Table Card */}
      <Card>
        <CardHeader className="py-4">
          <CardTitle className="text-base font-semibold">{items.length} Hero Dishes</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <div className="space-y-2 p-4">
              <Skeleton className="h-12 w-full" />
              <Skeleton className="h-12 w-full" />
              <Skeleton className="h-12 w-full" />
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-14">Preview</TableHead>
                  <TableHead>Dish & Details</TableHead>
                  <TableHead>Business</TableHead>
                  <TableHead>Price</TableHead>
                  <TableHead>Category / Type</TableHead>
                  <TableHead>3D Photos</TableHead>
                  <TableHead>Pipeline Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="h-32 text-center">
                      <p className="text-muted-foreground">No hero dishes found for this filter.</p>
                    </TableCell>
                  </TableRow>
                ) : (
                  items.map((item) => {
                    const jobId = item.processingJobId
                    const canEnqueue =
                      item.photoCount >= 4 &&
                      !jobId &&
                      item.productStatus !== 4 &&
                      item.productStatus !== 6
                    const firstPhoto = item.photos?.[0]?.photoUrl

                    const veg = VEG_STATUS_LABELS[item.vegStatus ?? 0] ?? VEG_STATUS_LABELS[0]
                    const categoryName =
                      item.category != null
                        ? PRODUCT_CATEGORY_LABELS[item.category] ?? 'General'
                        : 'General'

                    return (
                      <TableRow key={item.productId} className="hover:bg-muted/30">
                        {/* Thumbnail */}
                        <TableCell>
                          <div
                            className="relative h-11 w-11 cursor-pointer overflow-hidden rounded-md border border-border bg-muted/40"
                            onClick={() => setSelectedProduct(item)}
                          >
                            {firstPhoto ? (
                              <img
                                src={firstPhoto}
                                alt={item.productName}
                                className="h-full w-full object-cover transition hover:scale-110"
                              />
                            ) : (
                              <div className="flex h-full w-full items-center justify-center text-muted-foreground">
                                <Package className="h-5 w-5" />
                              </div>
                            )}
                          </div>
                        </TableCell>

                        {/* Dish Name & Hero Badge */}
                        <TableCell>
                          <div className="space-y-1">
                            <div className="flex items-center gap-1.5 font-semibold text-foreground">
                              <span>{item.productName}</span>
                              <span className="inline-flex items-center gap-0.5 rounded bg-primary/10 px-1.5 py-0.2 text-[10px] font-bold text-primary">
                                <Sparkles className="h-2.5 w-2.5" /> 3D Hero
                              </span>
                            </div>
                            {item.description && (
                              <p className="line-clamp-1 text-xs text-muted-foreground">
                                {item.description}
                              </p>
                            )}
                          </div>
                        </TableCell>

                        {/* Business Name */}
                        <TableCell>
                          <span className="text-sm font-medium">{item.businessName}</span>
                        </TableCell>

                        {/* Price */}
                        <TableCell>
                          <span className="font-semibold text-foreground">
                            {formatPaise(item.pricePaise)}
                          </span>
                        </TableCell>

                        {/* Category & Veg Status */}
                        <TableCell>
                          <div className="flex flex-col gap-1">
                            <span className="text-xs text-foreground font-medium">
                              {categoryName}
                            </span>
                            <span
                              className="inline-flex items-center gap-1 text-[11px] font-semibold"
                              style={{ color: veg.color }}
                            >
                              <span
                                className="h-1.5 w-1.5 rounded-full"
                                style={{ backgroundColor: veg.color }}
                              />
                              {veg.label}
                            </span>
                          </div>
                        </TableCell>

                        {/* 4 Photos Progress */}
                        <TableCell>
                          <div className="space-y-1">
                            <span className="text-xs font-semibold">
                              {item.photoCount}/4 Angles
                            </span>
                            <div className="flex gap-1">
                              {[0, 1, 2, 3].map((idx) => (
                                <span
                                  key={idx}
                                  className={`h-1.5 w-3 rounded-full ${
                                    idx < item.photoCount ? 'bg-primary' : 'bg-muted'
                                  }`}
                                />
                              ))}
                            </div>
                          </div>
                        </TableCell>

                        {/* Pipeline Status */}
                        <TableCell>
                          <div className="flex items-center gap-1.5">
                            <StatusBadge status={statusBadgeKey(item.jobStatus)} />
                            <span className="text-xs text-muted-foreground">
                              {jobStatusLabel(item)}
                            </span>
                          </div>
                          <span className="text-[10px] text-muted-foreground">
                            Product: {PRODUCT_STATUS_LABELS[item.productStatus] ?? item.productStatus}
                          </span>
                        </TableCell>

                        {/* Actions */}
                        <TableCell className="text-right">
                          <div className="flex flex-wrap justify-end items-center gap-1.5">
                            {/* Inspect Dish Modal Trigger */}
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-8 px-2 text-xs"
                              title="View all details & photos"
                              onClick={() => setSelectedProduct(item)}
                            >
                              <Eye className="mr-1 h-3.5 w-3.5" />
                              Details
                            </Button>

                            {canEnqueue && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-8 text-xs"
                                disabled={actionId === item.productId}
                                onClick={() => handleEnqueue(item.productId)}
                              >
                                <Play className="mr-1 h-3 w-3" />
                                Run 3D
                              </Button>
                            )}

                            {canAdvanceToReview(item) && jobId && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-8 text-xs"
                                disabled={actionId === jobId}
                                onClick={() => handleAdvanceToReview(jobId)}
                              >
                                <RefreshCw className="mr-1 h-3 w-3" />
                                Review
                              </Button>
                            )}

                            {canApproveOrReject(item) && jobId && (
                              <>
                                <Button
                                  size="sm"
                                  className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2.5"
                                  disabled={actionId === jobId}
                                  onClick={() => handleApprove(jobId)}
                                >
                                  <Check className="mr-1 h-3.5 w-3.5" />
                                  Approve
                                </Button>
                                <Button
                                  size="sm"
                                  variant="destructive"
                                  className="h-8 text-xs px-2.5"
                                  disabled={actionId === jobId}
                                  onClick={() => setRejectTarget(item)}
                                >
                                  <X className="mr-1 h-3.5 w-3.5" />
                                  Reject
                                </Button>
                              </>
                            )}

                            {canPublishLive(item) && jobId && (
                              <Button
                                size="sm"
                                className="h-8 bg-primary hover:bg-primary/90 text-white text-xs px-2.5"
                                disabled={actionId === jobId}
                                onClick={() => handlePublish(jobId)}
                              >
                                <Upload className="mr-1 h-3.5 w-3.5" />
                                Publish Live
                              </Button>
                            )}

                            {item.productStatus === 4 && (
                              <>
                                <Badge variant="success" className="text-xs">
                                  Live in AR
                                </Badge>
                                <Button
                                  size="sm"
                                  variant="outline"
                                  className="h-8 text-xs text-warning border-warning/30 hover:bg-warning/10 px-2"
                                  disabled={actionId === item.productId}
                                  onClick={() => handleSetProductStatus(item.productId, 5)}
                                  title="Remove dish from diner AR menu (Pause dish)"
                                >
                                  <PauseCircle className="mr-1 h-3.5 w-3.5" />
                                  Pause
                                </Button>
                              </>
                            )}

                            {item.productStatus === 5 && (
                              <>
                                <Badge variant="warning" className="text-xs">
                                  Paused
                                </Badge>
                                <Button
                                  size="sm"
                                  className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2.5"
                                  disabled={actionId === item.productId}
                                  onClick={() => handleSetProductStatus(item.productId, 4)}
                                  title="Reverse strategy: Publish dish back to live diner menu"
                                >
                                  <Play className="mr-1 h-3.5 w-3.5 fill-current" />
                                  Publish Live
                                </Button>
                              </>
                            )}

                            {item.productStatus === 6 && (
                              <Badge variant="danger" className="text-xs">
                                Rejected
                              </Badge>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    )
                  })
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Product Detail Modal */}
      {selectedProduct && (
        <ProductDetailModal
          item={selectedProduct}
          actionId={actionId}
          onClose={() => setSelectedProduct(null)}
          onApprove={handleApprove}
          onReject={(item) => setRejectTarget(item)}
          onPublish={handlePublish}
          onEnqueue={handleEnqueue}
          onAdvanceToReview={handleAdvanceToReview}
          onSetStatus={handleSetProductStatus}
        />
      )}

      {/* Reject Product Modal */}
      {rejectTarget && (
        <RejectProductDialog
          productName={rejectTarget.productName}
          isSubmitting={actionId === rejectTarget.processingJobId}
          onConfirm={handleRejectConfirm}
          onCancel={() => setRejectTarget(null)}
        />
      )}
    </div>
  )
}
