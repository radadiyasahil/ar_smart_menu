import { AlertCircle, Check, Eye, RefreshCw, ShieldAlert, Store, X } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
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
  type AdminBusiness,
  type BusinessStatusFilter,
  businessStatusKey,
} from '@/types/admin'

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

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await adminService.listBusinesses({
        status: statusFilter,
        search: search || undefined,
        page: 1,
        limit: 50,
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

      {/* Search Input */}
      <Input
        placeholder="Search by restaurant name, owner name, city or mobile..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && void load()}
        className="max-w-md text-xs"
      />

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger text-sm">
          {error}
        </div>
      )}

      {/* Businesses Table */}
      <Card>
        <CardHeader className="py-4">
          <CardTitle className="text-base font-semibold">
            {total} Businesses Registered
          </CardTitle>
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
                  <TableHead>Restaurant Name</TableHead>
                  <TableHead>Owner & Contact</TableHead>
                  <TableHead>City & Address</TableHead>
                  <TableHead>Category</TableHead>
                  <TableHead>Compliance</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Subscription</TableHead>
                  <TableHead>Dishes</TableHead>
                  <TableHead>Registered</TableHead>
                  <TableHead className="text-right">Review / Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {businesses.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={10} className="h-28 text-center text-muted-foreground text-sm">
                      No businesses found for this filter.
                    </TableCell>
                  </TableRow>
                ) : (
                  businesses.map((b) => {
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
                                b.subscriptionDaysRemaining > 0
                                  ? `${b.subscriptionDaysRemaining}d left`
                                  : 'Ends today'}
                              </div>
                            </div>
                          ) : b.subscriptionStatus === 'Expired' ? (
                            <Badge variant="danger" className="text-[11px]">
                              Expired
                            </Badge>
                          ) : (
                            <span className="text-xs text-muted-foreground">No Plan</span>
                          )}
                        </TableCell>

                        {/* Product Count */}
                        <TableCell>
                          <span className="text-xs font-semibold">{b.productCount}</span>
                        </TableCell>

                        {/* Registered Date */}
                        <TableCell>
                          <span className="text-xs text-muted-foreground">
                            {b.createdAt.slice(0, 10)}
                          </span>
                        </TableCell>

                        {/* Actions */}
                        <TableCell className="text-right">
                          <div className="flex justify-end items-center gap-1.5">
                            {/* Inspect Modal Trigger */}
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-8 px-2 text-xs"
                              title="Review full application & details"
                              onClick={() => setSelectedBusiness(b)}
                            >
                              <Eye className="mr-1 h-3.5 w-3.5" />
                              Review
                            </Button>

                            {/* Quick Action Buttons for Pending */}
                            {isPending && (
                              <>
                                <Button
                                  size="sm"
                                  className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2.5"
                                  disabled={actionId === b.id}
                                  onClick={() => void handleApprove(b.id)}
                                >
                                  <Check className="mr-1 h-3.5 w-3.5" />
                                  Approve
                                </Button>
                                <Button
                                  size="sm"
                                  variant="destructive"
                                  className="h-8 text-xs px-2.5"
                                  disabled={actionId === b.id}
                                  onClick={() => setRejectId(b.id)}
                                >
                                  <X className="mr-1 h-3.5 w-3.5" />
                                  Reject
                                </Button>
                              </>
                            )}

                            {/* Active: Quick Deactivate option */}
                            {b.status === 1 && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-8 text-xs text-warning border-warning/30 hover:bg-warning/10 px-2"
                                disabled={actionId === b.id}
                                onClick={() => void handleSetStatus(b.id, 4, 'Admin deactivated operations')}
                                title="Deactivate business operations (diner scans show temporarily closed; 100% reversible)"
                              >
                                Deactivate
                              </Button>
                            )}

                            {/* Deactivated or Suspended: Quick Reactivate option (Reverse Strategy) */}
                            {(b.status === 4 || b.status === 2) && (
                              <Button
                                size="sm"
                                className="h-8 bg-emerald-600 hover:bg-emerald-700 text-white text-xs px-2"
                                disabled={actionId === b.id}
                                onClick={() => void handleSetStatus(b.id, 1)}
                                title="Reverse strategy: Reactivate business and restore live diner menu instantly"
                              >
                                Reactivate
                              </Button>
                            )}

                            {b.status === 3 && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-8 text-xs px-2"
                                disabled={actionId === b.id}
                                onClick={() => void handleSetStatus(b.id, 1)}
                                title="Re-open and approve registration"
                              >
                                Re-Open
                              </Button>
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

      {/* Business Detail & Review Modal */}
      {selectedBusiness && (
        <BusinessDetailModal
          business={selectedBusiness}
          isSubmitting={actionId === selectedBusiness.id}
          onClose={() => setSelectedBusiness(null)}
          onApprove={handleApprove}
          onReject={handleReject}
          onSetStatus={handleSetStatus}
          onGrantSubscription={handleGrantSubscription}
          onCancelSubscription={handleCancelSubscription}
        />
      )}

      {/* Quick Reject Dialog from Table */}
      {rejectId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs">
          <Card className="w-full max-w-md shadow-2xl">
            <CardHeader className="pb-3">
              <CardTitle className="text-base text-destructive flex items-center gap-2">
                <AlertCircle className="h-5 w-5" />
                Reject Business Registration
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-muted-foreground">
                  Reason for Rejection <span className="text-destructive">*</span>
                </label>
                <Input
                  placeholder="e.g. Invalid FSSAI certificate or address details unverified."
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  className="text-xs"
                  autoFocus
                />
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" size="sm" onClick={() => setRejectId(null)}>
                  Cancel
                </Button>
                <Button
                  variant="destructive"
                  size="sm"
                  disabled={!rejectReason.trim() || actionId === rejectId}
                  onClick={() => void handleReject(rejectId, rejectReason.trim())}
                >
                  Confirm Reject & Notify
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
