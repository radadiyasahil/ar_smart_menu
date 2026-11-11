import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Check,
  Eye,
  Package,
  PauseCircle,
  Play,
  RefreshCw,
  Search,
  SlidersHorizontal,
  Sparkles,
  Upload,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { ProductDetailModal } from '@/components/products/ProductDetailModal'
import { RejectProductDialog } from '@/components/products/RejectProductDialog'
import { StatusBadge } from '@/components/tables/DataTable'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
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
import { cn } from '@/utils/cn'

type ReviewFilter = 'pending' | 'approved' | 'live' | 'paused' | 'all'
type ProductSortField = 'name' | 'business' | 'price' | 'category' | 'photos' | 'status' | 'date'
type SortOrder = 'asc' | 'desc'

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

  // Rich Filter & Sorting states
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [selectedVegStatus, setSelectedVegStatus] = useState<string>('all')
  const [selectedJobStatus, setSelectedJobStatus] = useState<string>('all')
  const [sortField, setSortField] = useState<ProductSortField>('date')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')

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

  // Auto-open product review modal if productId is specified in URL query (e.g. from notification click)
  useEffect(() => {
    const targetProductId = searchParams.get('productId')
    if (targetProductId && items.length > 0) {
      const match = items.find((p) => p.productId.toLowerCase() === targetProductId.toLowerCase())
      if (match) {
        setSelectedProduct(match)
      }
    }
  }, [items, searchParams])

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

  const handleApprove = (jobId: string, productId?: string) =>
    void runAction(jobId, () => adminService.submitQualityReview(jobId, 1, undefined, undefined, productId))

  const handleRejectConfirm = (reason: string, improvementNotes: string) => {
    const target = rejectTarget
    if (!target) return
    const id = target.processingJobId || target.productId
    void runAction(id, async () => {
      await adminService.submitQualityReview(id, 2, reason, improvementNotes, target.productId)
      setRejectTarget(null)
      if (selectedProduct?.productId === target.productId) {
        setSelectedProduct(null)
      }
    })
  }

  const handlePublish = (jobId: string, productId?: string) =>
    void runAction(jobId, () => adminService.publishProcessingJob(jobId, productId))

  const handleEnqueue = (productId: string) =>
    void runAction(productId, () => adminService.enqueueProductProcessing(productId))

  const handleAdvanceToReview = (jobId: string) =>
    void runAction(jobId, () => adminService.advanceJobToReview(jobId))

  // Filter & Sort calculation
  const filteredAndSortedItems = useMemo(() => {
    let result = [...items]

    // 1. Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim()
      result = result.filter((item) => {
        const matchName = item.productName?.toLowerCase().includes(q)
        const matchBusiness = item.businessName?.toLowerCase().includes(q)
        const matchDesc = item.description?.toLowerCase().includes(q)
        const priceStr = item.pricePaise ? (item.pricePaise / 100).toString() : ''
        const matchPrice = priceStr.includes(q)
        return Boolean(matchName || matchBusiness || matchDesc || matchPrice)
      })
    }

    // 2. Category Filter
    if (selectedCategory !== 'all') {
      const catNum = Number(selectedCategory)
      result = result.filter((item) => item.category === catNum)
    }

    // 3. Veg / Diet Filter
    if (selectedVegStatus !== 'all') {
      const vegNum = Number(selectedVegStatus)
      result = result.filter((item) => item.vegStatus === vegNum)
    }

    // 4. Job / Pipeline Status Filter
    if (selectedJobStatus !== 'all') {
      const statusNum = Number(selectedJobStatus)
      result = result.filter((item) => item.jobStatus === statusNum)
    }

    // 5. Sorting
    result.sort((a, b) => {
      let comparison = 0
      switch (sortField) {
        case 'name':
          comparison = (a.productName || '').localeCompare(b.productName || '', undefined, { sensitivity: 'base' })
          break
        case 'business':
          comparison = (a.businessName || '').localeCompare(b.businessName || '', undefined, { sensitivity: 'base' })
          break
        case 'price':
          comparison = (a.pricePaise ?? 0) - (b.pricePaise ?? 0)
          break
        case 'category':
          comparison = (a.category ?? 999) - (b.category ?? 999)
          break
        case 'photos':
          comparison = (a.photoCount ?? 0) - (b.photoCount ?? 0)
          break
        case 'status':
          const aStat = a.jobStatus ?? a.productStatus ?? 0
          const bStat = b.jobStatus ?? b.productStatus ?? 0
          comparison = aStat - bStat
          break
        case 'date':
        default:
          const aDate = new Date(a.updatedAt || a.createdAt || 0).getTime()
          const bDate = new Date(b.updatedAt || b.createdAt || 0).getTime()
          comparison = aDate - bDate
          break
      }
      return sortOrder === 'asc' ? comparison : -comparison
    })

    return result
  }, [items, searchQuery, selectedCategory, selectedVegStatus, selectedJobStatus, sortField, sortOrder])

  const hasActiveFilters = Boolean(
    searchQuery.trim() ||
      selectedCategory !== 'all' ||
      selectedVegStatus !== 'all' ||
      selectedJobStatus !== 'all',
  )

  const resetFilters = () => {
    setSearchQuery('')
    setSelectedCategory('all')
    setSelectedVegStatus('all')
    setSelectedJobStatus('all')
  }

  const handleHeaderClick = (field: ProductSortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortField(field)
      setSortOrder(field === 'price' || field === 'photos' || field === 'date' ? 'desc' : 'asc')
    }
  }

  const renderSortHeader = (label: string, field: ProductSortField, alignRight = false) => {
    const isActive = sortField === field
    return (
      <button
        type="button"
        onClick={() => handleHeaderClick(field)}
        className={cn(
          'inline-flex items-center gap-1.5 font-medium hover:text-foreground transition-colors cursor-pointer select-none group',
          isActive ? 'text-primary font-semibold' : 'text-muted-foreground',
          alignRight && 'justify-end w-full',
        )}
      >
        <span>{label}</span>
        {isActive ? (
          sortOrder === 'asc' ? (
            <ArrowUp className="h-3.5 w-3.5 text-primary" />
          ) : (
            <ArrowDown className="h-3.5 w-3.5 text-primary" />
          )
        ) : (
          <ArrowUpDown className="h-3.5 w-3.5 opacity-40 group-hover:opacity-100 transition-opacity" />
        )}
      </button>
    )
  }

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

      {/* Search & Filter Toolbar */}
      <div className="flex flex-col gap-3 rounded-xl border border-border bg-card/60 p-3.5 shadow-xs">
        <div className="flex flex-wrap items-center justify-between gap-3">
          {/* Search Input */}
          <div className="relative flex-1 min-w-[240px] max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search dish, business, or price..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-8 h-9 text-xs bg-background/80"
            />
            {searchQuery && (
              <button
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground cursor-pointer"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>

          {/* Filter Dropdowns */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Category Dropdown */}
            <select
              value={selectedCategory}
              onChange={(e) => setSelectedCategory(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Categories</option>
              {Object.entries(PRODUCT_CATEGORY_LABELS).map(([key, label]) => (
                <option key={key} value={key}>
                  {label}
                </option>
              ))}
            </select>

            {/* Veg / Diet Dropdown */}
            <select
              value={selectedVegStatus}
              onChange={(e) => setSelectedVegStatus(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Diets</option>
              <option value="1">🌱 Pure Veg</option>
              <option value="2">🍗 Non-Veg</option>
              <option value="3">🥚 Egg</option>
              <option value="4">🌿 Vegan</option>
            </select>

            {/* Pipeline Status Dropdown */}
            <select
              value={selectedJobStatus}
              onChange={(e) => setSelectedJobStatus(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Pipeline Statuses</option>
              <option value="0">Queued (0)</option>
              <option value="1">Processing (1)</option>
              <option value="2">Optimizing (2)</option>
              <option value="3">Review (3)</option>
              <option value="4">Approved (4)</option>
              <option value="5">Rejected (5)</option>
              <option value="6">Failed (6)</option>
            </select>

            {/* Sort Preset Dropdown */}
            <select
              value={`${sortField}-${sortOrder}`}
              onChange={(e) => {
                const [field, order] = e.target.value.split('-') as [ProductSortField, SortOrder]
                setSortField(field)
                setSortOrder(order)
              }}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer font-medium"
            >
              <option value="date-desc">Sort: Newest First</option>
              <option value="date-asc">Sort: Oldest First</option>
              <option value="name-asc">Sort: Dish (A to Z)</option>
              <option value="name-desc">Sort: Dish (Z to A)</option>
              <option value="business-asc">Sort: Business (A to Z)</option>
              <option value="business-desc">Sort: Business (Z to A)</option>
              <option value="price-asc">Sort: Price (Low to High)</option>
              <option value="price-desc">Sort: Price (High to Low)</option>
              <option value="photos-desc">Sort: Most Photos (4+)</option>
            </select>

            {/* Clear Filters Button */}
            {hasActiveFilters && (
              <Button
                variant="ghost"
                size="sm"
                onClick={resetFilters}
                className="h-9 text-xs text-muted-foreground hover:text-foreground gap-1 px-2.5 cursor-pointer"
              >
                <X className="h-3.5 w-3.5" />
                Reset
              </Button>
            )}
          </div>
        </div>

        {/* Active Filters Pill Bar (when filters applied) */}
        {hasActiveFilters && (
          <div className="flex flex-wrap items-center gap-1.5 pt-2 text-[11px] text-muted-foreground border-t border-border/40">
            <span className="font-semibold text-foreground/80 flex items-center gap-1">
              <SlidersHorizontal className="h-3 w-3 text-primary" /> Active Filters:
            </span>
            {searchQuery && (
              <span className="inline-flex items-center gap-1 bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 rounded-full font-medium">
                Search: "{searchQuery}"
                <button
                  onClick={() => setSearchQuery('')}
                  className="hover:text-primary/70 cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {selectedCategory !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Category: {PRODUCT_CATEGORY_LABELS[Number(selectedCategory)]}
                <button
                  onClick={() => setSelectedCategory('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {selectedVegStatus !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Diet: {VEG_STATUS_LABELS[Number(selectedVegStatus)]?.label}
                <button
                  onClick={() => setSelectedVegStatus('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {selectedJobStatus !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Status: {PROCESSING_STATUS_LABELS[Number(selectedJobStatus)]}
                <button
                  onClick={() => setSelectedJobStatus('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
          </div>
        )}
      </div>

      {/* Products Table Card */}
      <Card>
        <CardHeader className="py-4 flex flex-row items-center justify-between">
          <CardTitle className="text-base font-semibold">
            {filteredAndSortedItems.length} {filteredAndSortedItems.length === 1 ? 'Hero Dish' : 'Hero Dishes'}
            {hasActiveFilters && (
              <span className="ml-2 text-xs font-normal text-muted-foreground">
                (Filtered from {items.length} total)
              </span>
            )}
          </CardTitle>
          <span className="text-xs text-muted-foreground">
            Click table column headers to sort ↑↓
          </span>
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
                  <TableHead>{renderSortHeader('Dish & Details', 'name')}</TableHead>
                  <TableHead>{renderSortHeader('Business', 'business')}</TableHead>
                  <TableHead>{renderSortHeader('Price', 'price')}</TableHead>
                  <TableHead>{renderSortHeader('Category / Type', 'category')}</TableHead>
                  <TableHead>{renderSortHeader('3D Photos', 'photos')}</TableHead>
                  <TableHead>{renderSortHeader('Pipeline Status', 'status')}</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredAndSortedItems.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="h-32 text-center">
                      <div className="flex flex-col items-center justify-center gap-2 py-4">
                        <p className="text-muted-foreground">
                          {hasActiveFilters
                            ? 'No hero dishes match your filter criteria.'
                            : 'No hero dishes found for this tab.'}
                        </p>
                        {hasActiveFilters && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={resetFilters}
                            className="cursor-pointer text-xs"
                          >
                            Clear all filters
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredAndSortedItems.map((item) => {
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
                                  onClick={() => handleApprove(jobId, item.productId)}
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
                                onClick={() => handlePublish(jobId, item.productId)}
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
          isSubmitting={actionId === (rejectTarget.processingJobId || rejectTarget.productId)}
          onConfirm={handleRejectConfirm}
          onCancel={() => setRejectTarget(null)}
        />
      )}
    </div>
  )
}
