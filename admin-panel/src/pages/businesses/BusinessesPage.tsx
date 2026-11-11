import {
  AlertCircle,
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Check,
  Eye,
  RefreshCw,
  Search,
  ShieldAlert,
  SlidersHorizontal,
  Store,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { BusinessDetailModal } from '@/components/businesses/BusinessDetailModal'
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
  BUSINESS_TYPE_LABELS,
  KYC_STATUS_LABELS,
  type AdminBusiness,
  type BusinessStatusFilter,
  businessStatusKey,
} from '@/types/admin'
import { cn } from '@/utils/cn'

type BusinessSortField = 'name' | 'owner' | 'city' | 'status' | 'products' | 'date'
type SortOrder = 'asc' | 'desc'

const STATUS_TABS: { label: string; value: BusinessStatusFilter }[] = [
  { label: 'Pending Approvals', value: 'pending' },
  { label: 'Active', value: 'active' },
  { label: 'Deactivated', value: 'deactivated' },
  { label: 'Suspended', value: 'suspended' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'All Businesses', value: 'all' },
]

export function BusinessesPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const initialStatus = (searchParams.get('status') as BusinessStatusFilter) ?? 'pending'

  const [businesses, setBusinesses] = useState<AdminBusiness[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [statusFilter, setStatusFilter] = useState<BusinessStatusFilter>(initialStatus)
  const [search, setSearch] = useState('')
  const [actionId, setActionId] = useState<string | null>(null)
  const [rejectId, setRejectId] = useState<string | null>(null)
  const [rejectReason, setRejectReason] = useState('')
  const [selectedBusiness, setSelectedBusiness] = useState<AdminBusiness | null>(null)

  // Rich Filter & Sorting state
  const [businessTypeFilter, setBusinessTypeFilter] = useState<string>('all')
  const [kycFilter, setKycFilter] = useState<string>('all')
  const [sortField, setSortField] = useState<BusinessSortField>('date')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await adminService.listBusinesses({
        status: statusFilter,
        search: search || undefined,
        page: 1,
        limit: 100,
      })
      setBusinesses(result.items)
      setTotal(result.total)

      // Refresh selectedBusiness if open
      if (selectedBusiness) {
        const refreshed = result.items.find((b) => b.id === selectedBusiness.id)
        if (refreshed) setSelectedBusiness(refreshed)
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load businesses')
    } finally {
      setLoading(false)
    }
  }, [statusFilter, search, selectedBusiness])

  useEffect(() => {
    void load()
  }, [statusFilter])

  // Auto-open business review modal if businessId is specified in URL query (e.g. from notification click)
  useEffect(() => {
    const targetBusinessId = searchParams.get('businessId')
    if (targetBusinessId && businesses.length > 0) {
      const match = businesses.find((b) => b.id.toLowerCase() === targetBusinessId.toLowerCase())
      if (match) {
        setSelectedBusiness(match)
      }
    }
  }, [businesses, searchParams])

  const handleApprove = async (id: string, notes?: string) => {
    setActionId(id)
    try {
      await adminService.approveBusiness(id, notes)
      await load()
      setSelectedBusiness(null)
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Approve failed')
    } finally {
      setActionId(null)
    }
  }

  const handleReject = async (id: string, reason: string, notes?: string) => {
    setActionId(id)
    try {
      await adminService.rejectBusiness(id, reason, notes)
      setRejectId(null)
      setRejectReason('')
      setSelectedBusiness(null)
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Reject failed')
    } finally {
      setActionId(null)
    }
  }

  const handleSetStatus = async (
    id: string,
    status: number,
    reason?: string,
    notes?: string,
  ) => {
    setActionId(id)
    try {
      await adminService.setBusinessStatus(id, status, reason, notes)
      await load()
      if (selectedBusiness?.id === id) {
        setSelectedBusiness((prev) => (prev ? { ...prev, status } : null))
      }
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Status update failed')
    } finally {
      setActionId(null)
    }
  }

  const handleGrantSubscription = async (
    id: string,
    payload: { planSlug: string; customDays?: number; notes?: string },
  ) => {
    setActionId(id)
    try {
      await adminService.grantSubscription(id, payload)
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to grant subscription')
    } finally {
      setActionId(null)
    }
  }

  const handleCancelSubscription = async (id: string) => {
    setActionId(id)
    try {
      await adminService.cancelSubscription(id)
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to cancel subscription')
    } finally {
      setActionId(null)
    }
  }

  const setTab = (value: BusinessStatusFilter) => {
    setStatusFilter(value)
    setSearchParams(value === 'all' ? {} : { status: value })
  }

  const pendingCount = businesses.filter((b) => b.status === 0).length

  // Filter & Sort computation
  const filteredAndSortedBusinesses = useMemo(() => {
    let result = [...businesses]

    // 1. Business type filter
    if (businessTypeFilter !== 'all') {
      const typeNum = Number(businessTypeFilter)
      result = result.filter((b) => b.businessType === typeNum)
    }

    // 2. KYC Status filter
    if (kycFilter !== 'all') {
      const kycNum = Number(kycFilter)
      result = result.filter((b) => b.ownerKycStatus === kycNum)
    }

    // 3. Sorting
    result.sort((a, b) => {
      let cmp = 0
      switch (sortField) {
        case 'name':
          cmp = (a.businessName || '').localeCompare(b.businessName || '', undefined, { sensitivity: 'base' })
          break
        case 'owner':
          cmp = (a.ownerName || '').localeCompare(b.ownerName || '', undefined, { sensitivity: 'base' })
          break
        case 'city':
          cmp = (a.city || '').localeCompare(b.city || '', undefined, { sensitivity: 'base' })
          break
        case 'products':
          cmp = a.productCount - b.productCount
          break
        case 'status':
          cmp = a.status - b.status
          break
        case 'date':
        default:
          cmp = new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
          break
      }
      return sortOrder === 'asc' ? cmp : -cmp
    })

    return result
  }, [businesses, businessTypeFilter, kycFilter, sortField, sortOrder])

  const hasActiveFilters = Boolean(
    search.trim() || businessTypeFilter !== 'all' || kycFilter !== 'all',
  )

  const resetFilters = () => {
    setSearch('')
    setBusinessTypeFilter('all')
    setKycFilter('all')
    void load()
  }

  const handleHeaderClick = (field: BusinessSortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortField(field)
      setSortOrder(field === 'date' || field === 'products' ? 'desc' : 'asc')
    }
  }

  const renderSortHeader = (label: string, field: BusinessSortField, alignRight = false) => {
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
      {/* Top Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-xl font-bold tracking-tight text-foreground flex items-center gap-2">
            <Store className="h-6 w-6 text-primary" />
            Restaurant & Business Approvals
          </h2>
          <p className="text-sm text-muted-foreground">
            Review onboarding submissions, verify FSSAI/GSTIN compliance, and approve owner registrations.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Pending Banner if pending registrations exist */}
      {statusFilter === 'pending' && pendingCount > 0 && (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 p-4 text-xs text-foreground flex items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <ShieldAlert className="h-5 w-5 text-amber-600 shrink-0" />
            <span>
              <strong>Action Required:</strong> {pendingCount} new business registration(s) awaiting review.
              Approving a business unlocks their product management and AR table menus.
            </span>
          </div>
          <Badge className="bg-amber-600 text-white shrink-0">
            {pendingCount} Pending
          </Badge>
        </div>
      )}

      {/* Filter Tabs */}
      <div className="flex flex-wrap gap-2">
        {STATUS_TABS.map((tab) => (
          <Button
            key={tab.value}
            variant={statusFilter === tab.value ? 'default' : 'outline'}
            size="sm"
            onClick={() => setTab(tab.value)}
          >
            {tab.label}
          </Button>
        ))}
      </div>

      {/* Search & Filter Toolbar */}
      <div className="flex flex-col gap-3 rounded-xl border border-border bg-card/60 p-3.5 shadow-xs">
        <div className="flex flex-wrap items-center justify-between gap-3">
          {/* Search Input */}
          <div className="relative flex-1 min-w-[240px] max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search restaurant, owner, city, or mobile..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && void load()}
              className="pl-9 pr-8 h-9 text-xs bg-background/80"
            />
            {search && (
              <button
                type="button"
                onClick={() => {
                  setSearch('')
                  void load()
                }}
                className="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground cursor-pointer"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>

          {/* Filter Dropdowns */}
          <div className="flex flex-wrap items-center gap-2">
            {/* Category / Type Dropdown */}
            <select
              value={businessTypeFilter}
              onChange={(e) => setBusinessTypeFilter(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All Business Types</option>
              {BUSINESS_TYPE_LABELS.map((label, idx) => (
                <option key={idx} value={String(idx)}>
                  {label}
                </option>
              ))}
            </select>

            {/* KYC Status Dropdown */}
            <select
              value={kycFilter}
              onChange={(e) => setKycFilter(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All KYC Statuses</option>
              {Object.entries(KYC_STATUS_LABELS).map(([k, label]) => (
                <option key={k} value={k}>
                  KYC: {label}
                </option>
              ))}
            </select>

            {/* Sort Dropdown */}
            <select
              value={`${sortField}-${sortOrder}`}
              onChange={(e) => {
                const [f, o] = e.target.value.split('-') as [BusinessSortField, SortOrder]
                setSortField(f)
                setSortOrder(o)
              }}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer font-medium"
            >
              <option value="date-desc">Sort: Newest First</option>
              <option value="date-asc">Sort: Oldest First</option>
              <option value="name-asc">Sort: Business (A to Z)</option>
              <option value="name-desc">Sort: Business (Z to A)</option>
              <option value="city-asc">Sort: City (A to Z)</option>
              <option value="products-desc">Sort: Most Dishes</option>
              <option value="status-asc">Sort: Status</option>
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
            {search && (
              <span className="inline-flex items-center gap-1 bg-primary/10 text-primary border border-primary/20 px-2 py-0.5 rounded-full font-medium">
                Search: "{search}"
                <button
                  onClick={() => {
                    setSearch('')
                    void load()
                  }}
                  className="hover:text-primary/70 cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {businessTypeFilter !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Type: {BUSINESS_TYPE_LABELS[Number(businessTypeFilter)]}
                <button
                  onClick={() => setBusinessTypeFilter('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
            {kycFilter !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                KYC: {KYC_STATUS_LABELS[Number(kycFilter)]}
                <button
                  onClick={() => setKycFilter('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
          </div>
        )}
      </div>

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger text-sm">
          {error}
        </div>
      )}

      {/* Businesses Table */}
      <Card>
        <CardHeader className="py-4 flex flex-row items-center justify-between">
          <CardTitle className="text-base font-semibold">
            {filteredAndSortedBusinesses.length}{' '}
            {filteredAndSortedBusinesses.length === 1 ? 'Business' : 'Businesses'} Registered
            {hasActiveFilters && (
              <span className="ml-2 text-xs font-normal text-muted-foreground">
                (Filtered from {total} total)
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
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{renderSortHeader('Restaurant Name', 'name')}</TableHead>
                  <TableHead>{renderSortHeader('Owner & Contact', 'owner')}</TableHead>
                  <TableHead>{renderSortHeader('City & Address', 'city')}</TableHead>
                  <TableHead>Category</TableHead>
                  <TableHead>Compliance</TableHead>
                  <TableHead>{renderSortHeader('Status', 'status')}</TableHead>
                  <TableHead>Subscription</TableHead>
                  <TableHead>{renderSortHeader('Dishes', 'products')}</TableHead>
                  <TableHead>{renderSortHeader('Registered', 'date')}</TableHead>
                  <TableHead className="text-right">Review / Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredAndSortedBusinesses.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={10} className="h-32 text-center">
                      <div className="flex flex-col items-center justify-center gap-2 py-4">
                        <p className="text-muted-foreground text-sm">
                          {hasActiveFilters
                            ? 'No businesses match your filter criteria.'
                            : 'No businesses found for this tab.'}
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
                  filteredAndSortedBusinesses.map((b) => {
                    const isPending = b.status === 0
                    return (
                      <TableRow key={b.id} className="hover:bg-muted/30">
                        {/* Restaurant Name */}
                        <TableCell>
                          <div className="space-y-0.5">
                            <span className="font-semibold text-foreground block">
                              {b.businessName}
                            </span>
                            <span className="text-[11px] text-muted-foreground">
                              ID: {b.id.slice(0, 8)}
                            </span>
                          </div>
                        </TableCell>

                        {/* Owner & Contact */}
                        <TableCell>
                          <div className="text-sm font-medium">{b.ownerName ?? 'Owner'}</div>
                          <div className="text-xs text-muted-foreground">{b.ownerMobile}</div>
                        </TableCell>

                        {/* City & Address */}
                        <TableCell>
                          <div className="text-sm font-medium">{b.city}</div>
                          {b.fullAddress && (
                            <div className="text-xs text-muted-foreground line-clamp-1 max-w-[180px]">
                              {b.fullAddress}
                            </div>
                          )}
                        </TableCell>

                        {/* Type */}
                        <TableCell>
                          <span className="text-xs font-medium">
                            {BUSINESS_TYPE_LABELS[b.businessType] ?? 'Restaurant'}
                          </span>
                        </TableCell>

                        {/* Compliance (FSSAI / GSTIN / UPI) */}
                        <TableCell>
                          <div className="flex flex-col gap-0.5">
                            {b.fssaiNumber ? (
                              <span className="text-[10px] text-emerald-600 font-medium">
                                FSSAI: {b.fssaiNumber.slice(0, 7)}...
                              </span>
                            ) : (
                              <span className="text-[10px] text-muted-foreground">No FSSAI</span>
                            )}
                            {b.upiId ? (
                              <span className="text-[10px] text-primary font-medium">
                                UPI: {b.upiId}
                              </span>
                            ) : null}
                          </div>
                        </TableCell>

                        {/* Status */}
                        <TableCell>
                          <StatusBadge status={businessStatusKey(b.status)} />
                        </TableCell>

                        {/* Subscription */}
                        <TableCell>
                          {b.subscriptionStatus === 'Active' || b.subscriptionStatus === 'Trial' ? (
                            <div className="space-y-0.5">
                              <Badge
                                variant={b.subscriptionStatus === 'Trial' ? 'warning' : 'success'}
                                className="text-[11px] font-medium"
                              >
                                {b.subscriptionPlanName ||
                                  (b.subscriptionStatus === 'Trial' ? '7D Trial' : 'Active')}
                              </Badge>
                              <div className="text-[10px] text-muted-foreground">
                                {b.subscriptionDaysRemaining != null &&
                                  `${b.subscriptionDaysRemaining}d left`}
                              </div>
                            </div>
                          ) : (
                            <Badge variant="muted" className="text-[10px]">
                              No Plan
                            </Badge>
                          )}
                        </TableCell>

                        {/* Dishes Count */}
                        <TableCell>
                          <span className="font-semibold text-xs">{b.productCount}</span>
                        </TableCell>

                        {/* Registered Date */}
                        <TableCell className="text-xs text-muted-foreground">
                          {b.createdAt.slice(0, 10)}
                        </TableCell>

                        {/* Actions */}
                        <TableCell className="text-right">
                          <div className="flex flex-wrap justify-end items-center gap-1.5">
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-8 px-2 text-xs"
                              onClick={() => setSelectedBusiness(b)}
                              title="Inspect full details, KYC & Settings"
                            >
                              <Eye className="mr-1 h-3.5 w-3.5" />
                              Review
                            </Button>

                            {isPending && (
                              <>
                                <Button
                                  size="sm"
                                  className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2.5"
                                  disabled={actionId === b.id}
                                  onClick={() => handleApprove(b.id)}
                                >
                                  <Check className="mr-1 h-3.5 w-3.5" />
                                  Approve
                                </Button>
                                <Button
                                  size="sm"
                                  variant="destructive"
                                  className="h-8 text-xs px-2.5"
                                  disabled={actionId === b.id}
                                  onClick={() => {
                                    setRejectId(b.id)
                                    setRejectReason('')
                                  }}
                                >
                                  <X className="mr-1 h-3.5 w-3.5" />
                                  Reject
                                </Button>
                              </>
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

      {/* Reject Modal */}
      {rejectId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <Card className="w-full max-w-md shadow-xl border-border">
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-rose-500">
                <AlertCircle className="h-5 w-5" />
                Reject Business Registration
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-xs text-muted-foreground">
                Provide an explicit reason for rejecting this restaurant. The owner will see this in their app.
              </p>
              <Input
                placeholder="Reason (e.g. Invalid FSSAI certificate, unverified address)..."
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                className="text-xs"
              />
              <div className="flex justify-end gap-2 pt-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    setRejectId(null)
                    setRejectReason('')
                  }}
                  disabled={actionId === rejectId}
                >
                  Cancel
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  disabled={actionId === rejectId || !rejectReason.trim()}
                  onClick={() => handleReject(rejectId, rejectReason)}
                >
                  Confirm Rejection
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Detailed Business Modal */}
      {selectedBusiness && (
        <BusinessDetailModal
          business={selectedBusiness}
          isSubmitting={Boolean(actionId)}
          onClose={() => setSelectedBusiness(null)}
          onApprove={handleApprove}
          onReject={handleReject}
          onSetStatus={handleSetStatus}
          onGrantSubscription={handleGrantSubscription}
          onCancelSubscription={handleCancelSubscription}
        />
      )}
    </div>
  )
}
