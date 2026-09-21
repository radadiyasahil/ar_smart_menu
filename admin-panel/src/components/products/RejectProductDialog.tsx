import { useState } from 'react'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { cn } from '@/utils/cn'

interface RejectProductDialogProps {
  productName: string
  isSubmitting?: boolean
  onConfirm: (reason: string, improvementNotes: string) => void
  onCancel: () => void
}

/** Modal for admin product rejection with reason + improvement guidance for owner. */
export function RejectProductDialog({
  productName,
  isSubmitting,
  onConfirm,
  onCancel,
}: RejectProductDialogProps) {
  const [reason, setReason] = useState('')
  const [improvementNotes, setImprovementNotes] = useState('')

  const canSubmit = reason.trim().length > 0 && !isSubmitting

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle>Reject product</CardTitle>
          <p className="text-sm text-muted-foreground">
            {productName} — feedback is shown to the owner in their app.
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <label htmlFor="reject-reason" className="text-sm font-medium">
              Why are you rejecting? <span className="text-danger">*</span>
            </label>
            <Input
              id="reject-reason"
              placeholder="e.g. Photos are blurry / wrong angles"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
          </div>
          <div className="space-y-2">
            <label htmlFor="reject-improve" className="text-sm font-medium">
              What should the owner improve?
            </label>
            <textarea
              id="reject-improve"
              rows={4}
              placeholder="e.g. Retake top and front photos in daylight. Keep the dish centered."
              value={improvementNotes}
              onChange={(e) => setImprovementNotes(e.target.value)}
              className={cn(
                'flex w-full rounded-lg border border-border bg-card px-3 py-2 text-sm',
                'text-foreground placeholder:text-muted-foreground',
                'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30',
              )}
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="destructive"
              disabled={!canSubmit}
              onClick={() => onConfirm(reason.trim(), improvementNotes.trim())}
            >
              Confirm reject
            </Button>
            <Button variant="outline" disabled={isSubmitting} onClick={onCancel}>
              Cancel
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
