import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Box,
  CheckCircle2,
  Clock,
  RefreshCw,
  Search,
  SlidersHorizontal,
  X,
  XCircle,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { RejectProductDialog } from '@/components/products/RejectProductDialog'
import { StatusBadge } from '@/components/tables/DataTable'
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
import { PROCESSING_STATUS_LABELS, type ProcessingJob } from '@/types/admin'
import { cn } from '@/utils/cn'

type JobSortField = 'business' | 'product' | 'status' | 'retries' | 'created'
type SortOrder = 'asc' | 'desc'

function statusBadgeKey(status: number): string {
  switch (status) {
    case 4:
      return 'active'
    case 5:
    case 6:
      return 'rejected'
    case 3:
      return 'pending'
    default:
      return 'pending'
  }
}

export function ProcessingPage() {
  const [jobs, setJobs] = useState<ProcessingJob[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionJobId, setActionJobId] = useState<string | null>(null)
  const [rejectJob, setRejectJob] = useState<ProcessingJob | null>(null)

  // Filters & Sorting state
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [retryFilter, setRetryFilter] = useState<string>('all')
  const [sortField, setSortField] = useState<JobSortField>('created')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      setJobs(await adminService.getProcessingQueue())
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load queue')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const runAction = async (jobId: string, action: () => Promise<void>) => {
    setActionJobId(jobId)
    try {
      await action()
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Action failed')
    } finally {
      setActionJobId(null)
    }
  }

  const handleApprove = (id: string) =>
    void runAction(id, () => adminService.submitQualityReview(id, 1))

  const handleRejectConfirm = (reason: string, improvementNotes: string) => {
    const job = rejectJob
    if (!job) return
    void runAction(job.id, async () => {
      await adminService.submitQualityReview(job.id, 2, reason, improvementNotes)
      setRejectJob(null)
    })
  }

  const handlePublish = (id: string) =>
    void runAction(id, () => adminService.publishProcessingJob(id))

  const handleRetry = (id: string) =>
    void runAction(id, () => adminService.retryProcessingJob(id))

  // Metrics summary
  const metrics = useMemo(() => {
    const total = jobs.length
    const inPipeline = jobs.filter((j) => j.status === 0 || j.status === 1 || j.status === 2).length
    const reviewReady = jobs.filter((j) => j.status === 3).length
    const approved = jobs.filter((j) => j.status === 4).length
    const failed = jobs.filter((j) => j.status === 6).length
    return { total, inPipeline, reviewReady, approved, failed }
  }, [jobs])

  // Filtering & Sorting
  const filteredAndSortedJobs = useMemo(() => {
    let result = [...jobs]

    // 1. Text search
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim()
      result = result.filter((j) => {
        const matchBusiness = j.businessName?.toLowerCase().includes(q)
        const matchProduct = j.productName?.toLowerCase().includes(q)
        const matchId = j.id.toLowerCase().includes(q)
        return Boolean(matchBusiness || matchProduct || matchId)
      })
    }

    // 2. Status filter
    if (statusFilter !== 'all') {
      const statNum = Number(statusFilter)
      result = result.filter((j) => j.status === statNum)
    }

    // 3. Retry filter
    if (retryFilter === 'retried') {
      result = result.filter((j) => j.retryCount > 0)
    } else if (retryFilter === 'no-retries') {
      result = result.filter((j) => j.retryCount === 0)
    }

    // 4. Sorting
    result.sort((a, b) => {
      let cmp = 0
      switch (sortField) {
        case 'business':
          cmp = (a.businessName || '').localeCompare(b.businessName || '', undefined, { sensitivity: 'base' })
          break
        case 'product':
          cmp = (a.productName || '').localeCompare(b.productName || '', undefined, { sensitivity: 'base' })
          break
        case 'status':
          cmp = a.status - b.status
          break
        case 'retries':
          cmp = a.retryCount - b.retryCount
          break
        case 'created':
        default:
          cmp = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
          break
      }
      return sortOrder === 'asc' ? cmp : -cmp
    })

    return result
  }, [jobs, searchQuery, statusFilter, retryFilter, sortField, sortOrder])

  const hasActiveFilters = Boolean(
    searchQuery.trim() || statusFilter !== 'all' || retryFilter !== 'all',
  )

  const resetFilters = () => {
    setSearchQuery('')
    setStatusFilter('all')
    setRetryFilter('all')
  }

  const handleHeaderClick = (field: JobSortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortField(field)
      setSortOrder(field === 'created' || field === 'retries' ? 'desc' : 'asc')
    }
  }

  const renderSortHeader = (label: string, field: JobSortField, alignRight = false) => {
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
            <Box className="h-6 w-6 text-primary" />
            3D Photogrammetry Processing Queue
          </h2>
          <p className="text-sm text-muted-foreground">
            Real-time pipeline queue: photogrammetry reconstruction, mesh optimization & approval.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh Queue
        </Button>
      </div>

      {/* Quick Metrics Badges */}
      <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
        <button
          type="button"
          onClick={() => {
            setStatusFilter('all')
            setRetryFilter('all')
          }}
          className={cn(
            'flex items-center justify-between p-3 rounded-xl border bg-card transition-colors text-left cursor-pointer',
            statusFilter === 'all' && retryFilter === 'all'
              ? 'border-primary shadow-xs ring-1 ring-primary/20'
              : 'border-border hover:border-primary/40',
          )}
        >
          <div>
            <p className="text-[11px] text-muted-foreground font-medium uppercase tracking-wide">Total Queue</p>
            <p className="text-xl font-bold text-foreground">{metrics.total}</p>
          </div>
          <Box className="h-5 w-5 text-muted-foreground opacity-60" />
        </button>

        <button
          type="button"
          onClick={() => {
            setStatusFilter('1')
            setRetryFilter('all')
          }}
          className={cn(
            'flex items-center justify-between p-3 rounded-xl border bg-card transition-colors text-left cursor-pointer',
            statusFilter === '1'
              ? 'border-primary shadow-xs ring-1 ring-primary/20'
              : 'border-border hover:border-primary/40',
          )}
        >
          <div>
            <p className="text-[11px] text-muted-foreground font-medium uppercase tracking-wide">In Processing</p>
            <p className="text-xl font-bold text-sky-500">{metrics.inPipeline}</p>
          </div>
          <Clock className="h-5 w-5 text-sky-500 opacity-70" />
        </button>

        <button
          type="button"
          onClick={() => {
            setStatusFilter('3')
            setRetryFilter('all')
          }}
          className={cn(
            'flex items-center justify-between p-3 rounded-xl border bg-card transition-colors text-left cursor-pointer',
            statusFilter === '3'
              ? 'border-primary shadow-xs ring-1 ring-primary/20'
              : 'border-border hover:border-primary/40',
          )}
        >
          <div>
            <p className="text-[11px] text-muted-foreground font-medium uppercase tracking-wide">Review Ready</p>
            <p className="text-xl font-bold text-amber-500">{metrics.reviewReady}</p>
          </div>
          <CheckCircle2 className="h-5 w-5 text-amber-500 opacity-70" />
        </button>

        <button
          type="button"
          onClick={() => {
            setStatusFilter('4')
            setRetryFilter('all')
          }}
          className={cn(
            'flex items-center justify-between p-3 rounded-xl border bg-card transition-colors text-left cursor-pointer',
            statusFilter === '4'
              ? 'border-primary shadow-xs ring-1 ring-primary/20'
              : 'border-border hover:border-primary/40',
          )}
        >
          <div>
            <p className="text-[11px] text-muted-foreground font-medium uppercase tracking-wide">Approved</p>
            <p className="text-xl font-bold text-emerald-500">{metrics.approved}</p>
          </div>
          <CheckCircle2 className="h-5 w-5 text-emerald-500 opacity-70" />
        </button>

        <button
          type="button"
          onClick={() => {
            setStatusFilter('6')
            setRetryFilter('all')
          }}
          className={cn(
            'flex items-center justify-between p-3 rounded-xl border bg-card transition-colors text-left cursor-pointer',
            statusFilter === '6'
              ? 'border-primary shadow-xs ring-1 ring-primary/20'
              : 'border-border hover:border-primary/40',
          )}
        >
          <div>
            <p className="text-[11px] text-muted-foreground font-medium uppercase tracking-wide">Failed / Retry</p>
            <p className="text-xl font-bold text-rose-500">{metrics.failed}</p>
          </div>
          <XCircle className="h-5 w-5 text-rose-500 opacity-70" />
        </button>
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
              placeholder="Search by business, product, or job ID..."
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
            {/* Status Dropdown */}
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Statuses</option>
              {Object.entries(PROCESSING_STATUS_LABELS).map(([k, label]) => (
                <option key={k} value={k}>
                  {label} ({k})
                </option>
              ))}
            </select>

            {/* Retries Dropdown */}
            <select
              value={retryFilter}
              onChange={(e) => setRetryFilter(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Retry Counts</option>
              <option value="no-retries">No Retries (0)</option>
              <option value="retried">Has Retries (&gt; 0)</option>
            </select>

            {/* Sort Dropdown */}
            <select
              value={`${sortField}-${sortOrder}`}
              onChange={(e) => {
                const [f, o] = e.target.value.split('-') as [JobSortField, SortOrder]
                setSortField(f)
                setSortOrder(o)
              }}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer font-medium"
            >
              <option value="created-desc">Sort: Newest First</option>
              <option value="created-asc">Sort: Oldest First</option>
              <option value="business-asc">Sort: Business (A to Z)</option>
              <option value="business-desc">Sort: Business (Z to A)</option>
              <option value="product-asc">Sort: Product (A to Z)</option>
              <option value="status-asc">Sort: Status (Pipeline)</option>
              <option value="retries-desc">Sort: Most Retries</option>
            </select>

            {/* Reset Filters */}
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

        {/* Active Filters Pill Bar */}
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
            {statusFilter !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Status: {PROCESSING_STATUS_LABELS[Number(statusFilter)]}
                <button
                  onClick={() => setStatusFilter('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {retryFilter !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Retries: {retryFilter === 'retried' ? 'Has Retries' : '0 Retries'}
                <button
                  onClick={() => setRetryFilter('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
          </div>
        )}
      </div>

      {/* Jobs Table */}
      <Card>
        <CardHeader className="py-4 flex flex-row items-center justify-between">
          <CardTitle className="text-base font-semibold">
            {filteredAndSortedJobs.length} {filteredAndSortedJobs.length === 1 ? 'Job' : 'Jobs'}
            {hasActiveFilters && (
              <span className="ml-2 text-xs font-normal text-muted-foreground">
                (Filtered from {jobs.length} total)
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
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{renderSortHeader('Business', 'business')}</TableHead>
                  <TableHead>{renderSortHeader('Product', 'product')}</TableHead>
                  <TableHead>{renderSortHeader('Status', 'status')}</TableHead>
                  <TableHead>{renderSortHeader('Retries', 'retries')}</TableHead>
                  <TableHead>{renderSortHeader('Created', 'created')}</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredAndSortedJobs.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-32 text-center">
                      <div className="flex flex-col items-center justify-center gap-2 py-4">
                        <p className="text-muted-foreground">
                          {hasActiveFilters
                            ? 'No processing jobs match your filter criteria.'
                            : 'Queue is empty. Jobs appear when owners upload 4 product photos.'}
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
                  filteredAndSortedJobs.map((job) => (
                    <TableRow key={job.id} className="hover:bg-muted/30">
                      <TableCell className="font-semibold text-foreground">
                        {job.businessName}
                      </TableCell>
                      <TableCell>
                        <span className="font-medium">{job.productName ?? '—'}</span>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <StatusBadge status={statusBadgeKey(job.status)} />
                          <span className="text-xs font-medium">
                            {PROCESSING_STATUS_LABELS[job.status] ?? job.status}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <span
                          className={cn(
                            'text-xs font-semibold px-2 py-0.5 rounded-full inline-block',
                            job.retryCount > 0
                              ? 'bg-rose-500/10 text-rose-500 border border-rose-500/20'
                              : 'text-muted-foreground',
                          )}
                        >
                          {job.retryCount}
                        </span>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {job.createdAt.slice(0, 16).replace('T', ' ')}
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          {job.status === 3 && (
                            <>
                              <Button
                                size="sm"
                                className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2.5 cursor-pointer"
                                disabled={actionJobId === job.id}
                                onClick={() => handleApprove(job.id)}
                              >
                                Approve
                              </Button>
                              <Button
                                size="sm"
                                variant="destructive"
                                className="h-8 text-xs px-2.5 cursor-pointer"
                                disabled={actionJobId === job.id}
                                onClick={() => setRejectJob(job)}
                              >
                                Reject
                              </Button>
                            </>
                          )}
                          {job.status === 4 && (
                            <Button
                              size="sm"
                              variant="default"
                              className="h-8 text-xs px-2.5 cursor-pointer"
                              disabled={actionJobId === job.id}
                              onClick={() => handlePublish(job.id)}
                            >
                              Publish live
                            </Button>
                          )}
                          {job.status === 6 && (
                            <Button
                              size="sm"
                              variant="outline"
                              className="h-8 text-xs px-2.5 cursor-pointer text-rose-500 border-rose-500/30 hover:bg-rose-500/10"
                              disabled={actionJobId === job.id}
                              onClick={() => handleRetry(job.id)}
                            >
                              Retry
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {rejectJob && (
        <RejectProductDialog
          productName={rejectJob.productName ?? rejectJob.businessName}
          isSubmitting={actionJobId === rejectJob.id}
          onConfirm={handleRejectConfirm}
          onCancel={() => setRejectJob(null)}
        />
      )}
    </div>
  )
}
