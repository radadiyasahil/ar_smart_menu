import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  Eye,
  RefreshCw,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useMemo, useState } from 'react'

import { BusinessDetailModal } from '@/components/businesses/BusinessDetailModal'
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
import {
  BUSINESS_TYPE_LABELS,
  KYC_STATUS_LABELS,
  type AdminBusiness,
  businessStatusKey,
} from '@/types/admin'
import { cn } from '@/utils/cn'

type KycSortField = 'business' | 'owner' | 'mobile' | 'kycStatus' | 'businessStatus' | 'date'
type SortOrder = 'asc' | 'desc'

/** KYC review — businesses whose owners submitted KYC (status ≥ submitted). */
export function KycReviewPage() {
  const [rows, setRows] = useState<AdminBusiness[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedBusiness, setSelectedBusiness] = useState<AdminBusiness | null>(null)

  // Filters & Sorting state
  const [searchQuery, setSearchQuery] = useState('')
  const [kycStatusFilter, setKycStatusFilter] = useState<string>('all')
  const [sortField, setSortField] = useState<KycSortField>('date')
  const [sortOrder, setSortOrder] = useState<SortOrder>('desc')

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await adminService.listBusinesses({ status: 'all', limit: 100 })
      const kycRows = result.items.filter((b) => b.ownerKycStatus >= 1)
      setRows(kycRows)
      if (selectedBusiness) {
        const refreshed = kycRows.find((b) => b.id === selectedBusiness.id)
        if (refreshed) setSelectedBusiness(refreshed)
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load')
    } finally {
      setLoading(false)
    }
  }, [selectedBusiness])

  useEffect(() => {
    void load()
  }, [])

  // Filter & Sort calculation
  const filteredAndSortedRows = useMemo(() => {
    let result = [...rows]

    // 1. Text search
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim()
      result = result.filter((b) => {
        const matchBusiness = b.businessName?.toLowerCase().includes(q)
        const matchOwner = b.ownerName?.toLowerCase().includes(q)
        const matchMobile = b.ownerMobile?.toLowerCase().includes(q)
        const matchCity = b.city?.toLowerCase().includes(q)
        const matchPan = b.ownerPanNumber?.toLowerCase().includes(q)
        return Boolean(matchBusiness || matchOwner || matchMobile || matchCity || matchPan)
      })
    }

    // 2. KYC Status filter
    if (kycStatusFilter !== 'all') {
      const statNum = Number(kycStatusFilter)
      result = result.filter((b) => b.ownerKycStatus === statNum)
    }

    // 3. Sorting
    result.sort((a, b) => {
      let cmp = 0
      switch (sortField) {
        case 'business':
          cmp = (a.businessName || '').localeCompare(b.businessName || '', undefined, { sensitivity: 'base' })
          break
        case 'owner':
          cmp = (a.ownerName || '').localeCompare(b.ownerName || '', undefined, { sensitivity: 'base' })
          break
        case 'mobile':
          cmp = (a.ownerMobile || '').localeCompare(b.ownerMobile || '')
          break
        case 'kycStatus':
          cmp = a.ownerKycStatus - b.ownerKycStatus
          break
        case 'businessStatus':
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
  }, [rows, searchQuery, kycStatusFilter, sortField, sortOrder])

  const hasActiveFilters = Boolean(searchQuery.trim() || kycStatusFilter !== 'all')

  const resetFilters = () => {
    setSearchQuery('')
    setKycStatusFilter('all')
  }

  const handleHeaderClick = (field: KycSortField) => {
    if (sortField === field) {
      setSortOrder((prev) => (prev === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortField(field)
      setSortOrder(field === 'date' || field === 'kycStatus' ? 'desc' : 'asc')
    }
  }

  const renderSortHeader = (label: string, field: KycSortField, alignRight = false) => {
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
            <ShieldCheck className="h-6 w-6 text-primary" />
            KYC & Bank Verification Review
          </h2>
          <p className="text-sm text-muted-foreground">
            Inspect Aadhaar last-4, PAN numbers, and penny-drop bank verification for onboarding owners.
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">
          {error}
        </div>
      )}

      {/* Search & Filter Toolbar */}
      <div className="flex flex-col gap-3 rounded-xl border border-border bg-card/60 p-3.5 shadow-xs">
        <div className="flex flex-wrap items-center justify-between gap-3">
          {/* Search Input */}
          <div className="relative flex-1 min-w-[240px] max-w-md">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              type="text"
              placeholder="Search owner, business, mobile, PAN..."
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

          {/* Filter & Sort Dropdowns */}
          <div className="flex flex-wrap items-center gap-2">
            {/* KYC Status Dropdown */}
            <select
              value={kycStatusFilter}
              onChange={(e) => setKycStatusFilter(e.target.value)}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer"
            >
              <option value="all">All KYC Statuses</option>
              <option value="1">Submitted (Pending Review)</option>
              <option value="2">Verified</option>
              <option value="3">Rejected</option>
            </select>

            {/* Sort Dropdown */}
            <select
              value={`${sortField}-${sortOrder}`}
              onChange={(e) => {
                const [f, o] = e.target.value.split('-') as [KycSortField, SortOrder]
                setSortField(f)
                setSortOrder(o)
              }}
              className="h-9 rounded-lg border border-border bg-background px-2.5 text-xs text-foreground focus:outline-none focus:ring-1 focus:ring-primary cursor-pointer font-medium"
            >
              <option value="date-desc">Sort: Newest First</option>
              <option value="date-asc">Sort: Oldest First</option>
              <option value="business-asc">Sort: Business (A to Z)</option>
              <option value="owner-asc">Sort: Owner (A to Z)</option>
              <option value="kycStatus-asc">Sort: KYC Status</option>
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
            {kycStatusFilter !== 'all' && (
              <span className="inline-flex items-center gap-1 bg-muted px-2 py-0.5 rounded-full border border-border">
                Status: {KYC_STATUS_LABELS[Number(kycStatusFilter)]}
                <button
                  onClick={() => setKycStatusFilter('all')}
                  className="hover:text-foreground cursor-pointer"
                >
                  <X className="h-3 w-3" />
                </button>
              </span>
            )}
          </div>
        )}
      </div>

      {/* KYC Table */}
      <Card>
        <CardHeader className="py-4 flex flex-row items-center justify-between">
          <CardTitle className="text-base font-semibold">
            {filteredAndSortedRows.length}{' '}
            {filteredAndSortedRows.length === 1 ? 'KYC Submission' : 'KYC Submissions'}
            {hasActiveFilters && (
              <span className="ml-2 text-xs font-normal text-muted-foreground">
                (Filtered from {rows.length} total)
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
                  <TableHead>{renderSortHeader('Owner', 'owner')}</TableHead>
                  <TableHead>{renderSortHeader('Mobile', 'mobile')}</TableHead>
                  <TableHead>{renderSortHeader('KYC Status', 'kycStatus')}</TableHead>
                  <TableHead>{renderSortHeader('Business Status', 'businessStatus')}</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredAndSortedRows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-32 text-center text-muted-foreground">
                      <div className="flex flex-col items-center justify-center gap-2 py-4">
                        <p>
                          {hasActiveFilters
                            ? 'No KYC submissions match your filter criteria.'
                            : 'No KYC submissions yet. Owners submit KYC from the mobile app Account tab.'}
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
                  filteredAndSortedRows.map((b) => (
                    <TableRow key={b.id} className="hover:bg-muted/30">
                      <TableCell>
                        <div className="font-semibold text-foreground">{b.businessName}</div>
                        <div className="text-xs text-muted-foreground">
                          {BUSINESS_TYPE_LABELS[b.businessType]} · {b.city}
                        </div>
                      </TableCell>
                      <TableCell className="font-medium">{b.ownerName ?? '—'}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">{b.ownerMobile}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <StatusBadge
                            status={
                              b.ownerKycStatus === 2
                                ? 'active'
                                : b.ownerKycStatus === 3
                                  ? 'rejected'
                                  : 'pending'
                            }
                          />
                          <span className="text-xs font-medium">
                            {KYC_STATUS_LABELS[b.ownerKycStatus]}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={businessStatusKey(b.status)} />
                      </TableCell>
                      <TableCell className="text-right">
                        <Button
                          size="sm"
                          variant="ghost"
                          className="h-8 px-2 text-xs cursor-pointer"
                          onClick={() => setSelectedBusiness(b)}
                          title="Inspect KYC details, Aadhaar, PAN and Bank"
                        >
                          <Eye className="mr-1 h-3.5 w-3.5" />
                          Inspect KYC
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Detail Modal */}
      {selectedBusiness && (
        <BusinessDetailModal
          business={selectedBusiness}
          onClose={() => setSelectedBusiness(null)}
          onApprove={async (id, notes) => {
            await adminService.approveBusiness(id, notes)
            await load()
            setSelectedBusiness(null)
          }}
          onReject={async (id, reason, notes) => {
            await adminService.rejectBusiness(id, reason, notes)
            await load()
            setSelectedBusiness(null)
          }}
        />
      )}
    </div>
  )
}
