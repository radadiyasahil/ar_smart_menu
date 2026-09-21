import { ShieldCheck } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'

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
  BUSINESS_TYPE_LABELS,
  KYC_STATUS_LABELS,
  type AdminBusiness,
  businessStatusKey,
} from '@/types/admin'

/** KYC review — businesses whose owners submitted KYC (status ≥ submitted). */
export function KycReviewPage() {
  const [rows, setRows] = useState<AdminBusiness[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const result = await adminService.listBusinesses({ status: 'all', limit: 100 })
      setRows(result.items.filter((b) => b.ownerKycStatus >= 1))
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-semibold">
            <ShieldCheck className="h-5 w-5 text-primary" />
            KYC review
          </h2>
          <p className="text-sm text-muted-foreground">
            Owners who submitted KYC or bank verification
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()}>
          Refresh
        </Button>
      </div>

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">
          {error}
        </div>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Submitted KYC ({rows.length})</CardTitle>
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
                  <TableHead>Business</TableHead>
                  <TableHead>Owner</TableHead>
                  <TableHead>Mobile</TableHead>
                  <TableHead>KYC status</TableHead>
                  <TableHead>Business status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {rows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5} className="h-24 text-center text-muted-foreground">
                      No KYC submissions yet. Owners submit KYC from the mobile app Account tab.
                    </TableCell>
                  </TableRow>
                ) : (
                  rows.map((b) => (
                    <TableRow key={b.id}>
                      <TableCell>
                        <div className="font-medium">{b.businessName}</div>
                        <div className="text-xs text-muted-foreground">
                          {BUSINESS_TYPE_LABELS[b.businessType]} · {b.city}
                        </div>
                      </TableCell>
                      <TableCell>{b.ownerName ?? '—'}</TableCell>
                      <TableCell>{b.ownerMobile}</TableCell>
                      <TableCell>
                        <StatusBadge
                          status={
                            b.ownerKycStatus === 2
                              ? 'active'
                              : b.ownerKycStatus === 3
                                ? 'rejected'
                                : 'pending'
                          }
                        />
                        <span className="ml-2 text-xs text-muted-foreground">
                          {KYC_STATUS_LABELS[b.ownerKycStatus]}
                        </span>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={businessStatusKey(b.status)} />
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>
    </div>
  )
}
