import { Box, RefreshCw } from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'

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
import { PROCESSING_STATUS_LABELS, type ProcessingJob } from '@/types/admin'

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

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="flex items-center gap-2 text-xl font-semibold">
            <Box className="h-5 w-5 text-primary" />
            3D processing queue
          </h2>
          <p className="text-sm text-muted-foreground">
            Approve or reject with feedback, then publish live + QR
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => void load()} disabled={loading}>
          <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {error && (
        <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">{error}</div>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="text-base">{jobs.length} jobs</CardTitle>
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
                  <TableHead>Business</TableHead>
                  <TableHead>Product</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Retries</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {jobs.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                      Queue is empty. Jobs appear when owners upload 4 product photos.
                    </TableCell>
                  </TableRow>
                ) : (
                  jobs.map((job) => (
                    <TableRow key={job.id}>
                      <TableCell className="font-medium">{job.businessName}</TableCell>
                      <TableCell>{job.productName ?? '—'}</TableCell>
                      <TableCell>
                        <StatusBadge status={statusBadgeKey(job.status)} />
                        <span className="ml-2 text-xs">
                          {PROCESSING_STATUS_LABELS[job.status] ?? job.status}
                        </span>
                      </TableCell>
                      <TableCell>{job.retryCount}</TableCell>
                      <TableCell>{job.createdAt.slice(0, 16).replace('T', ' ')}</TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          {job.status === 3 && (
                            <>
                              <Button
                                size="sm"
                                disabled={actionJobId === job.id}
                                onClick={() => handleApprove(job.id)}
                              >
                                Approve
                              </Button>
                              <Button
                                size="sm"
                                variant="destructive"
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
