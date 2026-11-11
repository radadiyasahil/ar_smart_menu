import {
  AlertCircle,
  Building,
  Check,
  CheckCircle,
  Clock,
  Crown,
  FileText,
  MapPin,
  Play,
  Power,
  ShieldAlert,
  Sparkles,
  Store,
  User,
  X,
} from 'lucide-react'
import { useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import {
  BUSINESS_STATUS_LABELS,
  BUSINESS_TYPE_LABELS,
  KYC_STATUS_LABELS,
  type AdminBusiness,
} from '@/types/admin'

interface BusinessDetailModalProps {
  business: AdminBusiness
  isSubmitting?: boolean
  onClose: () => void
  onApprove: (id: string, notes?: string) => Promise<void>
  onReject: (id: string, reason: string, notes?: string) => Promise<void>
  onSetStatus?: (id: string, status: number, reason?: string, adminNotes?: string) => Promise<void>
  onGrantSubscription?: (
    id: string,
    payload: { planSlug: string; customDays?: number; notes?: string },
  ) => Promise<void>
  onCancelSubscription?: (id: string) => Promise<void>
}

export function BusinessDetailModal({
  business,
  isSubmitting,
  onClose,
  onApprove,
  onReject,
  onSetStatus,
  onGrantSubscription,
  onCancelSubscription,
}: BusinessDetailModalProps) {
  const [adminNotes, setAdminNotes] = useState(business.adminNotes ?? '')
  const [rejectReason, setRejectReason] = useState('')
  const [isRejecting, setIsRejecting] = useState(false)
  const [actionPrompt, setActionPrompt] = useState<'deactivate' | 'suspend' | null>(null)
  const [statusReason, setStatusReason] = useState('')
  const [planActionLoading, setPlanActionLoading] = useState(false)

  const isPending = business.status === 0
  const isActive = business.status === 1
  const isSuspended = business.status === 2
  const isRejected = business.status === 3
  const isDeactivated = business.status === 4

  const kycLabel = KYC_STATUS_LABELS[business.ownerKycStatus] ?? 'Pending'
  const isKycVerified = business.ownerKycStatus === 2

  const handleGrantPlan = async (planSlug: string, customDays?: number) => {
    if (!onGrantSubscription) return
    setPlanActionLoading(true)
    try {
      await onGrantSubscription(business.id, {
        planSlug,
        customDays,
        notes: `Super Admin provisioned plan: ${planSlug}`,
      })
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to grant plan')
    } finally {
      setPlanActionLoading(false)
    }
  }

  const handleCancelPlan = async () => {
    if (!onCancelSubscription) return
    if (!window.confirm('Are you sure you want to expire and cancel this subscription immediately? The business features will be locked.')) {
      return
    }
    setPlanActionLoading(true)
    try {
      await onCancelSubscription(business.id)
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to cancel plan')
    } finally {
      setPlanActionLoading(false)
    }
  }

  const handleApproveClick = async () => {
    await onApprove(business.id, adminNotes.trim() || undefined)
  }

  const handleRejectClick = async () => {
    if (!rejectReason.trim()) return
    await onReject(business.id, rejectReason.trim(), adminNotes.trim() || undefined)
  }

  const handleStatusChange = async (targetStatus: number, reason?: string) => {
    if (!onSetStatus) return
    await onSetStatus(business.id, targetStatus, reason, adminNotes.trim() || undefined)
    setActionPrompt(null)
    setStatusReason('')
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs">
      <Card className="flex max-h-[92vh] w-full max-w-2xl flex-col overflow-hidden shadow-2xl">
        {/* Header */}
        <CardHeader className="flex flex-row items-center justify-between border-b border-border bg-muted/30 pb-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <Store className="h-5 w-5 text-primary" />
              <CardTitle className="text-xl font-bold">{business.businessName}</CardTitle>
              <Badge
                variant={
                  isPending
                    ? 'warning'
                    : isActive
                      ? 'success'
                      : isDeactivated
                        ? 'muted'
                        : 'danger'
                }
                className="text-xs"
              >
                {BUSINESS_STATUS_LABELS[business.status] ?? 'Unknown'}
              </Badge>
            </div>
            <p className="text-xs text-muted-foreground flex items-center gap-2">
              <MapPin className="h-3.5 w-3.5" />
              {business.city} • Registered on {business.createdAt.slice(0, 10)}
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose} className="h-8 w-8 p-0">
            <X className="h-5 w-5" />
          </Button>
        </CardHeader>

        {/* Modal Body */}
        <CardContent className="flex-1 space-y-5 overflow-y-auto p-6">
          {/* Section 1: Business Overview */}
          <div className="rounded-lg border border-border bg-card p-4 space-y-3">
            <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
              <Building className="h-4 w-4 text-primary" />
              Business & Location Details
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
              <div>
                <span className="text-xs text-muted-foreground">Business Type</span>
                <p className="font-medium text-foreground">
                  {BUSINESS_TYPE_LABELS[business.businessType] ?? 'Restaurant'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">City</span>
                <p className="font-medium text-foreground">{business.city}</p>
              </div>
              <div className="sm:col-span-2">
                <span className="text-xs text-muted-foreground">Full Address</span>
                <p className="font-medium text-foreground">
                  {business.fullAddress ?? 'Not provided'}
                </p>
              </div>
            </div>
          </div>

          {/* Section 2: Owner Profile & Identity */}
          <div className="rounded-lg border border-border bg-card p-4 space-y-3">
            <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
              <User className="h-4 w-4 text-primary" />
              Owner & Contact Information
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
              <div>
                <span className="text-xs text-muted-foreground">Owner Full Name</span>
                <p className="font-medium text-foreground">{business.ownerName ?? '—'}</p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">Mobile Number</span>
                <p className="font-medium text-foreground">{business.ownerMobile}</p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">WhatsApp Number</span>
                <p className="font-medium text-foreground">
                  {business.ownerWhatsApp ?? business.ownerMobile}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">KYC Verification Status</span>
                <div className="flex items-center gap-1.5 mt-0.5">
                  <span
                    className={`inline-flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full ${
                      isKycVerified
                        ? 'bg-success/15 text-success'
                        : 'bg-warning/15 text-warning'
                    }`}
                  >
                    {isKycVerified ? (
                      <CheckCircle className="h-3 w-3" />
                    ) : (
                      <Clock className="h-3 w-3" />
                    )}
                    {kycLabel}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Section 3: Tax, Licensing & Banking */}
          <div className="rounded-lg border border-border bg-card p-4 space-y-3">
            <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
              <FileText className="h-4 w-4 text-primary" />
              Compliance, Tax & Settlement Bank
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
              <div>
                <span className="text-xs text-muted-foreground">FSSAI License</span>
                <p className="font-mono text-xs font-semibold text-foreground">
                  {business.fssaiNumber || 'Not provided'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">GSTIN</span>
                <p className="font-mono text-xs font-semibold text-foreground">
                  {business.gstNumber || 'Not provided'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">UPI Payment ID</span>
                <p className="font-mono text-xs font-semibold text-foreground">
                  {business.upiId || 'Not configured'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">Bank Account</span>
                <p className="font-mono text-xs font-semibold text-foreground">
                  {business.bankAccountNumber
                    ? `••••${business.bankAccountNumber.slice(-4)}`
                    : 'Not configured'}
                  {business.bankIfsc ? ` (${business.bankIfsc})` : ''}
                </p>
              </div>
              {business.ownerPanNumber && (
                <div>
                  <span className="text-xs text-muted-foreground">Owner PAN</span>
                  <p className="font-mono text-xs font-semibold text-foreground">
                    {business.ownerPanNumber}
                  </p>
                </div>
              )}
              {business.ownerAadhaarLast4 && (
                <div>
                  <span className="text-xs text-muted-foreground">Aadhaar Last 4</span>
                  <p className="font-mono text-xs font-semibold text-foreground">
                    •••• •••• {business.ownerAadhaarLast4}
                  </p>
                </div>
              )}
            </div>
          </div>

          {/* Section 4: Subscription & Licensing Management */}
          <div className="rounded-lg border border-border bg-card p-4 space-y-3">
            <div className="flex items-center justify-between">
              <h4 className="text-sm font-semibold text-foreground flex items-center gap-2">
                <Crown className="h-4 w-4 text-amber-500" />
                Subscription & Licensing
              </h4>
              <Badge
                variant={
                  business.subscriptionStatus === 'Active'
                    ? 'success'
                    : business.subscriptionStatus === 'Trial'
                      ? 'warning'
                      : business.subscriptionStatus === 'Expired'
                        ? 'danger'
                        : 'muted'
                }
                className="text-xs"
              >
                {business.subscriptionStatus === 'Active'
                  ? 'Active Plan'
                  : business.subscriptionStatus === 'Trial'
                    ? '7-Day Free Trial'
                    : business.subscriptionStatus === 'Expired'
                      ? 'Plan Expired'
                      : 'No Active Subscription'}
              </Badge>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-sm">
              <div>
                <span className="text-xs text-muted-foreground">Current Plan</span>
                <p className="font-semibold text-foreground">
                  {business.subscriptionPlanName ||
                    (business.subscriptionStatus === 'Trial' ? '7-Day Free Trial' : 'None')}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">Remaining Validity</span>
                <p className="font-semibold text-foreground">
                  {business.subscriptionDaysRemaining != null &&
                  business.subscriptionDaysRemaining > 0
                    ? `${business.subscriptionDaysRemaining} days remaining`
                    : business.subscriptionStatus === 'Active' ||
                        business.subscriptionStatus === 'Trial'
                      ? 'Ending today'
                      : '0 days'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">Plan Starts</span>
                <p className="font-mono text-xs text-foreground">
                  {business.subscriptionStartsAt
                    ? business.subscriptionStartsAt.slice(0, 10)
                    : '—'}
                </p>
              </div>
              <div>
                <span className="text-xs text-muted-foreground">Plan Expires</span>
                <p className="font-mono text-xs text-foreground">
                  {business.subscriptionEndsAt
                    ? business.subscriptionEndsAt.slice(0, 10)
                    : '—'}
                </p>
              </div>
            </div>

            {/* Admin Direct Grant Actions */}
            <div className="pt-2 border-t border-border/60">
              <span className="text-[11px] font-semibold text-muted-foreground block mb-2">
                Super Admin Plan Provisioning:
              </span>
              <div className="flex flex-wrap gap-1.5">
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 text-xs border-amber-500/30 text-amber-600 hover:bg-amber-500/10"
                  disabled={isSubmitting || planActionLoading}
                  onClick={() => handleGrantPlan('trial-7-days')}
                >
                  <Sparkles className="mr-1 h-3 w-3" />
                  Grant 7D Trial
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 text-xs hover:bg-muted"
                  disabled={isSubmitting || planActionLoading}
                  onClick={() => handleGrantPlan('plan-3-months')}
                >
                  Grant 3M Starter
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 text-xs border-primary/30 text-primary hover:bg-primary/10"
                  disabled={isSubmitting || planActionLoading}
                  onClick={() => handleGrantPlan('plan-6-months')}
                >
                  Grant 6M Growth
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-7 text-xs border-amber-600/40 text-amber-700 dark:text-amber-400 hover:bg-amber-600/10 font-semibold"
                  disabled={isSubmitting || planActionLoading}
                  onClick={() => handleGrantPlan('plan-1-year')}
                >
                  <Crown className="mr-1 h-3 w-3 text-amber-500" />
                  Grant 1Y VIP
                </Button>
                <Button
                  size="sm"
                  variant="ghost"
                  className="h-7 text-xs text-muted-foreground hover:bg-muted"
                  disabled={isSubmitting || planActionLoading}
                  onClick={() => handleGrantPlan('plan-3-months', 30)}
                >
                  +30 Days Ext.
                </Button>
                {(business.subscriptionStatus === 'Active' ||
                  business.subscriptionStatus === 'Trial') && (
                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-7 text-xs text-danger hover:bg-danger/10"
                    disabled={isSubmitting || planActionLoading}
                    onClick={handleCancelPlan}
                  >
                    Expire Plan
                  </Button>
                )}
              </div>
            </div>
          </div>

          {/* Rejection / Admin Notes info if previously rejected */}
          {business.rejectionReason && (
            <div className="rounded-md bg-danger/10 p-3 text-xs text-danger border border-danger/30 flex items-start gap-2">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold">Rejection Reason: </span>
                {business.rejectionReason}
              </div>
            </div>
          )}

          {/* Admin Notes Field */}
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-muted-foreground">
              Internal Admin Notes (Optional)
            </label>
            <Input
              placeholder="e.g. Verified FSSAI certificate on portal, approved for 10 tables."
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              className="text-xs"
            />
          </div>

          {/* Rejection Sub-Panel (toggled if admin clicks Reject) */}
          {isRejecting && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-danger flex items-center gap-1.5">
                  <AlertCircle className="h-4 w-4" /> Specify Rejection Reason
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-6 text-xs text-muted-foreground"
                  onClick={() => setIsRejecting(false)}
                >
                  Cancel
                </Button>
              </div>
              <Input
                placeholder="Reason for rejection (sent to owner via WhatsApp/App)..."
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                className="text-xs"
                autoFocus
              />
              <Button
                variant="destructive"
                size="sm"
                className="w-full text-xs"
                disabled={!rejectReason.trim() || isSubmitting}
                onClick={handleRejectClick}
              >
                Confirm Rejection & Notify Owner
              </Button>
            </div>
          )}

          {/* Deactivation / Suspension Sub-Panel */}
          {actionPrompt && (
            <div className="rounded-lg border border-warning/30 bg-warning/5 p-4 space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-foreground flex items-center gap-1.5">
                  <ShieldAlert className="h-4 w-4 text-warning" />
                  {actionPrompt === 'deactivate'
                    ? 'Deactivate Business Operations'
                    : 'Suspend Business Operations'}
                </span>
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-6 text-xs text-muted-foreground"
                  onClick={() => setActionPrompt(null)}
                >
                  Cancel
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                {actionPrompt === 'deactivate'
                  ? 'Deactivating will mark the restaurant as temporarily closed/inactive for diner QR scans. All menus, tables, and settings are preserved. The owner or admin can reactivate anytime.'
                  : 'Suspending halts table ordering and QR access until resolved.'}
              </p>
              <Input
                placeholder="Reason or operational note (optional)..."
                value={statusReason}
                onChange={(e) => setStatusReason(e.target.value)}
                className="text-xs"
                autoFocus
              />
              <Button
                variant={actionPrompt === 'deactivate' ? 'default' : 'destructive'}
                size="sm"
                className="w-full text-xs"
                disabled={isSubmitting}
                onClick={() =>
                  void handleStatusChange(
                    actionPrompt === 'deactivate' ? 4 : 2,
                    statusReason.trim() || undefined,
                  )
                }
              >
                {actionPrompt === 'deactivate'
                  ? 'Confirm Deactivation'
                  : 'Confirm Suspension'}
              </Button>
            </div>
          )}
        </CardContent>

        {/* Modal Footer Actions */}
        <div className="flex flex-wrap items-center justify-between gap-3 border-t border-border bg-muted/20 px-6 py-4">
          <Button variant="outline" size="sm" onClick={onClose}>
            Close
          </Button>

          {isPending && !isRejecting && !actionPrompt && (
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                className="text-danger hover:bg-danger/10"
                disabled={isSubmitting}
                onClick={() => setIsRejecting(true)}
              >
                <X className="mr-1.5 h-4 w-4" />
                Reject
              </Button>
              <Button
                size="sm"
                className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                disabled={isSubmitting}
                onClick={handleApproveClick}
              >
                <Check className="mr-1.5 h-4 w-4" />
                Approve Business
              </Button>
            </div>
          )}

          {!isPending && !isRejecting && !actionPrompt && (
            <div className="flex items-center gap-2">
              {/* Reverse Strategy: Reactivate button if deactivated, suspended, or rejected */}
              {(isDeactivated || isSuspended || isRejected) && (
                <Button
                  size="sm"
                  className="bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                  disabled={isSubmitting}
                  onClick={() => void handleStatusChange(1)}
                  title="Reverse strategy: Instantly restore business back to active and live status"
                >
                  <Play className="mr-1.5 h-4 w-4 fill-current" />
                  Reactivate Business & Go Live
                </Button>
              )}

              {/* If Active: Provide option to Deactivate or Suspend */}
              {isActive && (
                <>
                  <Button
                    size="sm"
                    variant="outline"
                    className="text-warning border-warning/30 hover:bg-warning/10"
                    disabled={isSubmitting}
                    onClick={() => setActionPrompt('deactivate')}
                    title="Temporarily deactivate business (diner scans show closed; 100% reversible)"
                  >
                    <Power className="mr-1.5 h-3.5 w-3.5" />
                    Deactivate Business
                  </Button>
                  <Button
                    size="sm"
                    variant="destructive"
                    className="text-xs"
                    disabled={isSubmitting}
                    onClick={() => setActionPrompt('suspend')}
                  >
                    <ShieldAlert className="mr-1.5 h-3.5 w-3.5" />
                    Suspend
                  </Button>
                </>
              )}
            </div>
          )}
        </div>
      </Card>
    </div>
  )
}
