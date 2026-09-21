import { Check, Package, Play, RefreshCw, Upload, X } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { RejectProductDialog } from '@/components/products/RejectProductDialog'
import { StatusBadge } from '@/components/tables/DataTable'
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
  PRODUCT_STATUS_LABELS,
  type AdminProductReviewItem,
} from '@/types/admin'

type ReviewFilter = 'pending' | 'approved' | 'all'

const FILTER_TABS: { label: string; value: ReviewFilter }[] = [
  { label: 'Pending review', value: 'pending' },
  { label: 'Ready to publish', value: 'approved' },
  { label: 'All owner products', value: 'all' },
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
    return 'Awaiting pipeline'
  }
  return '—'
}

function isStuckInPipeline(jobStatus?: number | null): boolean {
  return jobStatus === 1 || jobStatus === 2
}

function canApproveOrReject(item: AdminProductReviewItem): boolean {
  if (!item.processingJobId || item.productStatus === 4) return false
  // Only before admin approval — not when job is already Approved (4) or Rejected (5)
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

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setItems(await adminService.getProductReviewQueue(jobStatusForFilter(filter)))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load products')
    } finally {
      setLoading(false)
    }
  }, [filter])

  useEffect(() => {
    void load()
  }, [load])

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

  const handleApprove = (jobId: string) =>
    void runAction(jobId, () => adminService.submitQualityReview(jobId, 1))

  const handleRejectConfirm = (reason: string, improvementNotes: string) => {
    const target = rejectTarget
    if (!target?.processingJobId) return
    const jobId = target.processingJobId
    void runAction(jobId, async () => {
      await adminService.submitQualityReview(jobId, 2, reason, improvementNotes)
      setRejectTarget(null)
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
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-semibold">
            <Package className="h-5 w-5 text-primary" />
            Product review
          </h2>
          <p className="text-sm text-muted-foreground">
            Approve or reject owner products, then publish live with QR.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

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

      <Card>
        <CardHeader>
          <CardTitle className="text-base">{items.length} products</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <div className="space-y-2 p-4">
              <Skeleton className="h-12 w-full" />
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Product</TableHead>
                  <TableHead>Business</TableHead>
                  <TableHead>Photos</TableHead>
                  <TableHead>Product status</TableHead>
                  <TableHead>Pipeline</TableHead>
                  <TableHead>Updated</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="h-32 text-center">
                      <p className="text-muted-foreground">No owner products found for this filter.</p>
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
                    return (
                      <TableRow key={item.productId}>
                        <TableCell className="font-medium">{item.productName}</TableCell>
                        <TableCell>{item.businessName}</TableCell>
                        <TableCell>{item.photoCount}/4</TableCell>
                        <TableCell>
                          {PRODUCT_STATUS_LABELS[item.productStatus] ?? item.productStatus}
                        </TableCell>
                        <TableCell>
                          <StatusBadge status={statusBadgeKey(item.jobStatus)} />
                          <span className="ml-2 text-xs">{jobStatusLabel(item)}</span>
                        </TableCell>
                        <TableCell>{item.updatedAt.slice(0, 16).replace('T', ' ')}</TableCell>
                        <TableCell className="text-right">
                          <div className="flex flex-wrap justify-end gap-2">
                            {canEnqueue && (
                              <Button
                                size="sm"
                                variant="outline"
                                disabled={actionId === item.productId}
                                onClick={() => handleEnqueue(item.productId)}
                              >
                                <Play className="mr-1 h-3 w-3" />
                                Run processing
                              </Button>
                            )}
                            {canAdvanceToReview(item) && jobId && (
                              <Button
                                size="sm"
                                variant="outline"
                                disabled={actionId === jobId}
                                onClick={() => handleAdvanceToReview(jobId)}
                              >
                                <RefreshCw className="mr-1 h-3 w-3" />
                                Mark for review
                              </Button>
                            )}
                            {canApproveOrReject(item) && jobId && (
                              <>
                                <Button
                                  size="sm"
                                  disabled={actionId === jobId}
                                  onClick={() => handleApprove(jobId)}
                                >
                                  <Check className="mr-1 h-3 w-3" />
                                  Approve
                                </Button>
                                <Button
                                  size="sm"
                                  variant="destructive"
                                  disabled={actionId === jobId}
                                  onClick={() => setRejectTarget(item)}
                                >
                                  <X className="mr-1 h-3 w-3" />
                                  Reject
                                </Button>
                              </>
                            )}
                            {canPublishLive(item) && jobId && (
                              <Button
                                size="sm"
                                disabled={actionId === jobId}
                                onClick={() => handlePublish(jobId)}
                              >
                                <Upload className="mr-1 h-3 w-3" />
                                Publish live
                              </Button>
                            )}
                            {item.productStatus === 4 && (
                              <span className="text-xs text-success">Live</span>
                            )}
                            {item.productStatus === 6 && (
                              <span className="text-xs text-danger">Rejected</span>
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
