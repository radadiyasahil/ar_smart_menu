import { Check, RefreshCw, X } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

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
  BUSINESS_STATUS_LABELS,
  BUSINESS_TYPE_LABELS,
  type AdminBusiness,
  type BusinessStatusFilter,
  businessStatusKey,
} from '@/types/admin'

const STATUS_TABS: { label: string; value: BusinessStatusFilter }[] = [
  { label: 'All', value: 'all' },
  { label: 'Pending', value: 'pending' },
  { label: 'Active', value: 'active' },
  { label: 'Rejected', value: 'rejected' },
  { label: 'Suspended', value: 'suspended' },
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
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load')
    } finally {
      setLoading(false)
    }
  }, [statusFilter, search])

  useEffect(() => {
    void load()
  }, [load])

  const handleApprove = async (id: string) => {
    setActionId(id)
    try {
      await adminService.approveBusiness(id)
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Approve failed')
    } finally {
      setActionId(null)
    }
  }

  const handleReject = async () => {
    if (!rejectId || !rejectReason.trim()) return
    setActionId(rejectId)
    try {
      await adminService.rejectBusiness(rejectId, rejectReason.trim())
      setRejectId(null)
      setRejectReason('')
      await load()
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Reject failed')
    } finally {
      setActionId(null)
    }
  }

  const setTab = (value: BusinessStatusFilter) => {
    setStatusFilter(value)
    setSearchParams(value === 'all' ? {} : { status: value })
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-xl font-semibold">Business approvals</h2>
          <p className="text-sm text-muted-foreground">
            Review owner registration requests — {total} total
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

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

      <Input
        placeholder="Search by business name, owner, mobile..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        onKeyDown={(e) => e.key === 'Enter' && void load()}
        className="max-w-md"
      />

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">
          {error}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Businesses</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {loading ? (
            <div className="space-y-2 p-4">
              {Array.from({ length: 5 }).map((_, i) => (
                <Skeleton key={i} className="h-12 w-full" />
              ))}
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Business</TableHead>
                  <TableHead>Owner</TableHead>
                  <TableHead>City</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Products</TableHead>
                  <TableHead>Registered</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {businesses.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={8} className="h-24 text-center text-muted-foreground">
                      No businesses found for this filter.
                    </TableCell>
                  </TableRow>
                ) : (
                  businesses.map((b) => (
                    <TableRow key={b.id}>
                      <TableCell className="font-medium">{b.businessName}</TableCell>
                      <TableCell>
                        <div>{b.ownerName ?? '—'}</div>
                        <div className="text-xs text-muted-foreground">{b.ownerMobile}</div>
                      </TableCell>
                      <TableCell>{b.city}</TableCell>
                      <TableCell>
                        {BUSINESS_TYPE_LABELS[b.businessType] ?? 'Other'}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={businessStatusKey(b.status)} />
                      </TableCell>
                      <TableCell>{b.productCount}</TableCell>
                      <TableCell>{b.createdAt.slice(0, 10)}</TableCell>
                      <TableCell className="text-right">
                        {b.status === 0 && (
                          <div className="flex justify-end gap-2">
                            <Button
                              size="sm"
                              variant="default"
                              disabled={actionId === b.id}
                              onClick={() => void handleApprove(b.id)}
                            >
                              <Check className="mr-1 h-4 w-4" />
                              Approve
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              disabled={actionId === b.id}
                              onClick={() => setRejectId(b.id)}
                            >
                              <X className="mr-1 h-4 w-4" />
                              Reject
                            </Button>
                          </div>
                        )}
                        {b.status !== 0 && (
                          <Badge variant="muted">{BUSINESS_STATUS_LABELS[b.status]}</Badge>
                        )}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {rejectId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Reject business</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Input
                placeholder="Rejection reason (required)"
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
              />
              <div className="flex gap-2">
                <Button
                  variant="destructive"
                  disabled={!rejectReason.trim() || actionId === rejectId}
                  onClick={() => void handleReject()}
                >
                  Confirm reject
                </Button>
                <Button variant="outline" onClick={() => setRejectId(null)}>
                  Cancel
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  )
}
