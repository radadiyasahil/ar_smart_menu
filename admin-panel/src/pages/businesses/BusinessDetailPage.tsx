import {
  AlertCircle,
  ArrowLeft,
  Building,
  Check,
  CheckCircle,
  Clock,
  Crown,
  Download,
  FileText,
  History,
  Lock,
  MapPin,
  Phone,
  Play,
  Power,
  ReceiptText,
  RefreshCw,
  Save,
  ShieldAlert,
  Sparkles,
  Store,
  User,
  X,
} from 'lucide-react'
import { useCallback, useEffect, useState } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { adminService } from '@/services/adminService'
import {
  BUSINESS_STATUS_LABELS,
  BUSINESS_TYPE_LABELS,
  formatPaise,
  KYC_STATUS_LABELS,
  type AdminBusiness,
  type AdminUpdateBusinessPayload,
  type SubscriptionHistoryItem,
} from '@/types/admin'
import { cn } from '@/utils/cn'

interface BusinessFormData {
  businessName: string
  businessType: number
  city: string
  fullAddress: string
  ownerFullName: string
  ownerWhatsApp: string
  ownerKycStatus: number
  fssaiNumber: string
  gstNumber: string
  upiId: string
  bankAccountNumber: string
  bankIfsc: string
  adminNotes: string
}

const initialForm: BusinessFormData = {
  businessName: '',
  businessType: 0,
  city: '',
  fullAddress: '',
  ownerFullName: '',
  ownerWhatsApp: '',
  ownerKycStatus: 0,
  fssaiNumber: '',
  gstNumber: '',
  upiId: '',
  bankAccountNumber: '',
  bankIfsc: '',
  adminNotes: '',
}

function DetailField({
  label,
  value,
  onChange,
  placeholder,
  className,
  disabled,
  rightElement,
}: {
  label: string
  value: string
  onChange?: (val: string) => void
  placeholder?: string
  className?: string
  disabled?: boolean
  rightElement?: React.ReactNode
}) {
  return (
    <div className={cn('space-y-1.5', className)}>
      <label className="text-xs font-semibold text-muted-foreground">{label}</label>
      <div className="flex items-center gap-2">
        <Input
          value={value}
          onChange={(e) => onChange?.(e.target.value)}
          placeholder={placeholder}
          disabled={disabled}
          className={cn(disabled && 'bg-muted/50 cursor-not-allowed')}
        />
        {rightElement}
      </div>
    </div>
  )
}

export function BusinessDetailPage() {
  const { id } = useParams<{ id: string }>()
  const location = useLocation()
  const navigate = useNavigate()

  // State
  const [business, setBusiness] = useState<AdminBusiness | null>(
    (location.state as { business?: AdminBusiness })?.business ?? null,
  )
  const [isLoading, setIsLoading] = useState(!business)
  const [isSaving, setIsSaving] = useState(false)
  const [saveSuccessMsg, setSaveSuccessMsg] = useState<string | null>(null)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [form, setForm] = useState<BusinessFormData>(initialForm)

  // Subscription Provisioning & History
  const [planActionLoading, setPlanActionLoading] = useState(false)
  const [historyList, setHistoryList] = useState<SubscriptionHistoryItem[]>([])
  const [isLoadingHistory, setIsLoadingHistory] = useState(false)

  // Status Action Modals / Prompts
  const [isRejecting, setIsRejecting] = useState(false)
  const [rejectReason, setRejectReason] = useState('')
  const [actionPrompt, setActionPrompt] = useState<'deactivate' | 'suspend' | null>(null)
  const [statusReason, setStatusReason] = useState('')

  const updateField = <K extends keyof BusinessFormData>(key: K, val: BusinessFormData[K]) => {
    setForm((prev) => ({ ...prev, [key]: val }))
  }

  const populateForm = useCallback((b: AdminBusiness) => {
    setForm({
      businessName: b.businessName || '',
      businessType: b.businessType ?? 0,
      city: b.city || '',
      fullAddress: b.fullAddress || '',
      ownerFullName: b.ownerName || '',
      ownerWhatsApp: b.ownerWhatsApp || b.ownerMobile || '',
      ownerKycStatus: b.ownerKycStatus ?? 0,
      fssaiNumber: b.fssaiNumber || '',
      gstNumber: b.gstNumber || '',
      upiId: b.upiId || '',
      bankAccountNumber: b.bankAccountNumber || '',
      bankIfsc: b.bankIfsc || '',
      adminNotes: b.adminNotes || '',
    })
  }, [])

  const loadBusiness = useCallback(async () => {
    if (!id) return
    setIsLoading(true)
    setErrorMessage(null)
    try {
      const data = await adminService.getBusinessById(id)
      setBusiness(data)
      populateForm(data)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to load business details')
    } finally {
      setIsLoading(false)
    }
  }, [id, populateForm])

  const loadSubscriptionHistory = useCallback(async (businessId: string) => {
    setIsLoadingHistory(true)
    try {
      const history = await adminService.getBusinessSubscriptionHistory(businessId)
      setHistoryList(history)
    } catch (err) {
      console.error('Failed to load subscription history:', err)
    } finally {
      setIsLoadingHistory(false)
    }
  }, [])

  useEffect(() => {
    if (business) {
      populateForm(business)
      void loadSubscriptionHistory(business.id)
    }
    void loadBusiness()
  }, [id]) // eslint-disable-line react-hooks/exhaustive-deps

  const handleSaveChanges = async (customPayload?: AdminUpdateBusinessPayload) => {
    if (!id) return
    setIsSaving(true)
    setSaveSuccessMsg(null)
    setErrorMessage(null)

    const payload: AdminUpdateBusinessPayload = customPayload ?? {
      businessName: form.businessName.trim(),
      businessType: form.businessType,
      city: form.city.trim(),
      fullAddress: form.fullAddress.trim(),
      ownerFullName: form.ownerFullName.trim(),
      ownerWhatsApp: form.ownerWhatsApp.trim(),
      ownerKycStatus: form.ownerKycStatus,
      fssaiNumber: form.fssaiNumber.trim(),
      gstNumber: form.gstNumber.trim(),
      upiId: form.upiId.trim(),
      bankAccountNumber: form.bankAccountNumber.trim(),
      bankIfsc: form.bankIfsc.trim(),
      adminNotes: form.adminNotes.trim(),
    }

    try {
      const updated = await adminService.updateBusiness(id, payload)
      setBusiness(updated)
      populateForm(updated)
      setSaveSuccessMsg('Business details updated successfully!')
      setTimeout(() => setSaveSuccessMsg(null), 4000)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to update business')
    } finally {
      setIsSaving(false)
    }
  }

  // Quick Action Handlers
  const handleApprove = async () => {
    if (!id) return
    setIsSaving(true)
    try {
      await adminService.approveBusiness(id, form.adminNotes.trim() || undefined)
      await loadBusiness()
      setSaveSuccessMsg('Business approved and activated successfully!')
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to approve business')
    } finally {
      setIsSaving(false)
    }
  }

  const handleRejectConfirm = async () => {
    if (!id || !rejectReason.trim()) return
    setIsSaving(true)
    try {
      await adminService.rejectBusiness(id, rejectReason.trim(), form.adminNotes.trim() || undefined)
      setIsRejecting(false)
      setRejectReason('')
      await loadBusiness()
      setSaveSuccessMsg('Business rejected successfully')
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to reject business')
    } finally {
      setIsSaving(false)
    }
  }

  const handleAdminResetPin = async () => {
    if (!id) return
    const newPin = window.prompt(
      `Enter new 4 to 6-digit PIN for ${business?.ownerName || 'owner'} (Mobile: ${business?.ownerMobile}):`,
      '1234',
    )
    if (!newPin || !newPin.trim()) return
    if (newPin.trim().length < 4) {
      alert('PIN must be at least 4 digits')
      return
    }

    setIsSaving(true)
    try {
      await adminService.resetOwnerPin(id, newPin.trim())
      setSaveSuccessMsg(`Owner PIN has been successfully reset to: ${newPin.trim()}. Please inform the owner.`)
      setTimeout(() => setSaveSuccessMsg(null), 6000)
    } catch (e) {
      setErrorMessage(e instanceof Error ? e.message : 'Failed to reset owner PIN')
    } finally {
      setIsSaving(false)
    }
  }

  const handleStatusChangeConfirm = async (targetStatus: number, reason?: string) => {
    if (!id) return
    setIsSaving(true)
    try {
      await adminService.setBusinessStatus(id, targetStatus, reason, form.adminNotes.trim() || undefined)
      setActionPrompt(null)
      setStatusReason('')
      await loadBusiness()
      setSaveSuccessMsg('Business status updated successfully')
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Failed to update business status')
    } finally {
      setIsSaving(false)
    }
  }

  const handleGrantPlan = async (planSlug: string, customDays?: number) => {
    if (!id) return
    setPlanActionLoading(true)
    try {
      await adminService.grantSubscription(id, {
        planSlug,
        customDays,
        notes: `Super Admin provisioned plan: ${planSlug}`,
      })
      await loadBusiness()
      await loadSubscriptionHistory(id)
      setSaveSuccessMsg(`Plan ${planSlug} provisioned successfully!`)
      setTimeout(() => setSaveSuccessMsg(null), 4000)
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to grant plan')
    } finally {
      setPlanActionLoading(false)
    }
  }

  const handleCancelPlan = async () => {
    if (!id) return
    if (!window.confirm('Are you sure you want to expire and cancel this subscription immediately? The business features will be locked.')) {
      return
    }
    setPlanActionLoading(true)
    try {
      await adminService.cancelSubscription(id)
      await loadBusiness()
      await loadSubscriptionHistory(id)
      setSaveSuccessMsg('Subscription expired successfully')
      setTimeout(() => setSaveSuccessMsg(null), 4000)
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Failed to cancel plan')
    } finally {
      setPlanActionLoading(false)
    }
  }

  if (isLoading && !business) {
    return (
      <div className="space-y-6 p-6">
        <div className="flex items-center gap-4">
          <Skeleton className="h-10 w-24" />
          <Skeleton className="h-10 w-64" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Skeleton className="h-72 w-full rounded-xl" />
          <Skeleton className="h-72 w-full rounded-xl" />
          <Skeleton className="h-72 w-full rounded-xl" />
          <Skeleton className="h-72 w-full rounded-xl" />
        </div>
      </div>
    )
  }

  if (!business) {
    return (
      <div className="p-8 text-center space-y-4">
        <AlertCircle className="mx-auto h-12 w-12 text-danger" />
        <h2 className="text-xl font-bold">Business Not Found</h2>
        <p className="text-muted-foreground">{errorMessage || 'The requested business could not be loaded.'}</p>
        <Button onClick={() => navigate('/businesses')} variant="outline">
          <ArrowLeft className="mr-2 h-4 w-4" /> Back to Businesses
        </Button>
      </div>
    )
  }

  const isPending = business.status === 0
  const isActive = business.status === 1
  const isSuspended = business.status === 2
  const isRejected = business.status === 3
  const isDeactivated = business.status === 4

  const isKycVerified = business.ownerKycStatus === 2
  const kycLabel = KYC_STATUS_LABELS[business.ownerKycStatus] ?? 'Pending'

  return (
    <div className="space-y-6 pb-16">
      {/* Top Breadcrumb & Page Header */}
      <div className="flex flex-col gap-4 border-b border-border bg-card p-4 sm:p-6 rounded-xl shadow-xs">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="flex flex-col sm:flex-row sm:items-center gap-3">
            <Button
              variant="outline"
              size="sm"
              onClick={() => navigate('/businesses')}
              className="h-9 px-3 gap-1.5 w-fit"
            >
              <ArrowLeft className="h-4 w-4" />
              <span>Back to Businesses</span>
            </Button>
            <div className="h-6 w-px bg-border hidden sm:block" />
            <div className="flex items-start sm:items-center gap-2.5">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary shrink-0">
                <Store className="h-5 w-5" />
              </div>
              <div>
                <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-foreground flex flex-wrap items-center gap-2">
                  {business.businessName}
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
                    className="text-xs font-semibold"
                  >
                    {BUSINESS_STATUS_LABELS[business.status] ?? 'Unknown'}
                  </Badge>
                </h1>
                <p className="text-xs text-muted-foreground flex flex-wrap items-center gap-1.5 sm:gap-2 mt-0.5">
                  <span className="flex items-center gap-1">
                    <MapPin className="h-3.5 w-3.5 text-primary" />
                    {business.city}
                  </span>
                  <span>•</span>
                  <span>Registered {business.createdAt.slice(0, 10)}</span>
                  <span className="hidden sm:inline">•</span>
                  <span className="font-mono text-[11px] text-muted-foreground/80">ID: {business.id.slice(0, 8)}</span>
                </p>
              </div>
            </div>
          </div>

          {/* Header Action Buttons */}
          <div className="flex flex-wrap items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => void loadBusiness()}
              disabled={isLoading || isSaving}
              className="h-9"
              title="Refresh business data"
            >
              <RefreshCw className={`h-4 w-4 mr-1.5 ${isLoading ? 'animate-spin' : ''}`} />
              Refresh
            </Button>

            <Button
              size="sm"
              onClick={() => void handleSaveChanges()}
              disabled={isSaving}
              className="h-9 bg-primary text-primary-foreground font-semibold px-4"
            >
              <Save className="h-4 w-4 mr-1.5" />
              {isSaving ? 'Saving...' : 'Save All Changes'}
            </Button>

            {/* Quick Status Modifiers */}
            {isPending && (
              <>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-9 text-danger border-danger/30 hover:bg-danger/10"
                  onClick={() => setIsRejecting(true)}
                  disabled={isSaving}
                >
                  <X className="mr-1.5 h-4 w-4" /> Reject
                </Button>
                <Button
                  size="sm"
                  className="h-9 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                  onClick={handleApprove}
                  disabled={isSaving}
                >
                  <Check className="mr-1.5 h-4 w-4" /> Approve & Go Live
                </Button>
              </>
            )}

            {(isDeactivated || isSuspended || isRejected) && (
              <Button
                size="sm"
                className="h-9 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold"
                onClick={() => void handleStatusChangeConfirm(1)}
                disabled={isSaving}
              >
                <Play className="mr-1.5 h-4 w-4 fill-current" /> Reactivate & Go Live
              </Button>
            )}

            {isActive && (
              <>
                <Button
                  size="sm"
                  variant="outline"
                  className="h-9 text-warning border-warning/30 hover:bg-warning/10"
                  onClick={() => setActionPrompt('deactivate')}
                  disabled={isSaving}
                >
                  <Power className="mr-1.5 h-3.5 w-3.5" /> Deactivate
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  className="h-9"
                  onClick={() => setActionPrompt('suspend')}
                  disabled={isSaving}
                >
                  <ShieldAlert className="mr-1.5 h-3.5 w-3.5" /> Suspend
                </Button>
              </>
            )}
          </div>
        </div>

        {/* Status Alerts & Notifications */}
        {saveSuccessMsg && (
          <div className="rounded-lg bg-emerald-500/10 border border-emerald-500/30 p-3 text-sm text-emerald-600 dark:text-emerald-400 flex items-center gap-2">
            <CheckCircle className="h-5 w-5 shrink-0" />
            <span>{saveSuccessMsg}</span>
          </div>
        )}

        {errorMessage && (
          <div className="rounded-lg bg-danger/10 border border-danger/30 p-3 text-sm text-danger flex items-center gap-2">
            <AlertCircle className="h-5 w-5 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {business.rejectionReason && (
          <div className="rounded-lg bg-danger/10 border border-danger/30 p-3 text-xs text-danger flex items-start gap-2">
            <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
            <div>
              <span className="font-semibold">Current Rejection Reason: </span>
              {business.rejectionReason}
            </div>
          </div>
        )}

        {/* Inline Rejection Sub-Panel */}
        {isRejecting && (
          <div className="rounded-xl border border-danger/40 bg-danger/5 p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-bold text-danger flex items-center gap-2">
                <AlertCircle className="h-4 w-4" /> Reject Business Application
              </span>
              <Button
                variant="ghost"
                size="sm"
                className="h-7 text-xs"
                onClick={() => setIsRejecting(false)}
              >
                Cancel
              </Button>
            </div>
            <Input
              placeholder="Reason for rejection (sent to owner via WhatsApp/SMS)..."
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
              className="text-sm"
              autoFocus
            />
            <div className="flex justify-end gap-2">
              <Button
                variant="destructive"
                size="sm"
                disabled={!rejectReason.trim() || isSaving}
                onClick={handleRejectConfirm}
              >
                Confirm Rejection & Notify Owner
              </Button>
            </div>
          </div>
        )}

        {/* Inline Suspension/Deactivation Sub-Panel */}
        {actionPrompt && (
          <div className="rounded-xl border border-warning/40 bg-warning/5 p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-sm font-bold text-foreground flex items-center gap-2">
                <ShieldAlert className="h-4 w-4 text-warning" />
                {actionPrompt === 'deactivate'
                  ? 'Deactivate Business Operations'
                  : 'Suspend Business Operations'}
              </span>
              <Button
                variant="ghost"
                size="sm"
                className="h-7 text-xs"
                onClick={() => setActionPrompt(null)}
              >
                Cancel
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              {actionPrompt === 'deactivate'
                ? 'Deactivating will mark the restaurant as temporarily closed for diner QR scans. All menus, tables, and settings are preserved. You can reactivate anytime.'
                : 'Suspending halts table ordering and QR access until resolved.'}
            </p>
            <Input
              placeholder="Reason or operational note (optional)..."
              value={statusReason}
              onChange={(e) => setStatusReason(e.target.value)}
              className="text-sm"
              autoFocus
            />
            <div className="flex justify-end gap-2">
              <Button
                variant={actionPrompt === 'deactivate' ? 'default' : 'destructive'}
                size="sm"
                disabled={isSaving}
                onClick={() =>
                  void handleStatusChangeConfirm(
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
          </div>
        )}
      </div>

      {/* Main Full-Page Grid Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left Column (2 cols wide on desktop) */}
        <div className="lg:col-span-2 space-y-6">
          {/* Card 1: Business Overview & Location */}
          <Card className="shadow-xs">
            <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-3">
              <div className="flex items-center gap-2">
                <Building className="h-5 w-5 text-primary" />
                <CardTitle className="text-base font-bold">Business Profile & Location</CardTitle>
              </div>
              <Badge variant="muted" className="text-xs">
                {business.productCount} Dishes on Menu
              </Badge>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <DetailField
                  label="Business / Restaurant Name *"
                  value={form.businessName}
                  onChange={(val) => updateField('businessName', val)}
                  placeholder="Enter business name"
                />

                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-muted-foreground">
                    Business Category *
                  </label>
                  <select
                    value={form.businessType}
                    onChange={(e) => updateField('businessType', Number(e.target.value))}
                    aria-label="Business Category"
                    className="flex h-10 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
                  >
                    {BUSINESS_TYPE_LABELS.map((label, idx) => (
                      <option key={label} value={idx}>
                        {label}
                      </option>
                    ))}
                  </select>
                </div>

                <DetailField
                  label="City *"
                  value={form.city}
                  onChange={(val) => updateField('city', val)}
                  placeholder="e.g. Mumbai, Bangalore"
                />

                <DetailField
                  label="Full Address"
                  value={form.fullAddress}
                  onChange={(val) => updateField('fullAddress', val)}
                  placeholder="e.g. Shop 4, Marine Plaza, MG Road"
                  className="sm:col-span-2"
                />
              </div>

              <div className="flex justify-end pt-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    void handleSaveChanges({
                      businessName: form.businessName.trim(),
                      businessType: form.businessType,
                      city: form.city.trim(),
                      fullAddress: form.fullAddress.trim(),
                    })
                  }
                  disabled={isSaving}
                  className="text-xs"
                >
                  <Save className="h-3.5 w-3.5 mr-1" />
                  Save Profile Details
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Card 2: Owner & Identity KYC */}
          <Card className="shadow-xs">
            <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-3">
              <div className="flex items-center gap-2">
                <User className="h-5 w-5 text-primary" />
                <CardTitle className="text-base font-bold">Owner Profile & KYC Identity</CardTitle>
              </div>
              <span
                className={`inline-flex items-center gap-1 text-xs font-semibold px-2.5 py-1 rounded-full ${
                  isKycVerified
                    ? 'bg-success/15 text-success'
                    : 'bg-warning/15 text-warning'
                }`}
              >
                {isKycVerified ? (
                  <CheckCircle className="h-3.5 w-3.5" />
                ) : (
                  <Clock className="h-3.5 w-3.5" />
                )}
                {kycLabel}
              </span>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <DetailField
                  label="Owner Full Name"
                  value={form.ownerFullName}
                  onChange={(val) => updateField('ownerFullName', val)}
                  placeholder="e.g. Ramesh Patel"
                />

                <DetailField
                  label="Mobile Number (Login Identifier)"
                  value={business.ownerMobile}
                  disabled
                  rightElement={
                    <div className="flex items-center gap-1.5 shrink-0">
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-10 px-3"
                        onClick={() => window.open(`tel:${business.ownerMobile}`, '_blank')}
                        title="Call Owner"
                      >
                        <Phone className="h-4 w-4" />
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-10 px-2.5 text-xs text-amber-600 hover:bg-amber-500/10 border-amber-500/30 font-semibold"
                        onClick={handleAdminResetPin}
                        disabled={isSaving}
                        title="Emergency Admin Reset Owner PIN"
                      >
                        <Lock className="h-3.5 w-3.5 mr-1" /> Reset PIN
                      </Button>
                    </div>
                  }
                />

                <DetailField
                  label="WhatsApp Number"
                  value={form.ownerWhatsApp}
                  onChange={(val) => updateField('ownerWhatsApp', val)}
                  placeholder="e.g. 9876543210"
                />

                <div className="space-y-1.5">
                  <label className="text-xs font-semibold text-muted-foreground">
                    KYC Verification Status
                  </label>
                  <select
                    value={form.ownerKycStatus}
                    onChange={(e) => updateField('ownerKycStatus', Number(e.target.value))}
                    aria-label="KYC Verification Status"
                    className="flex h-10 w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
                  >
                    <option value={0}>0 - Pending</option>
                    <option value={1}>1 - Submitted (Review Pending)</option>
                    <option value={2}>2 - Verified</option>
                    <option value={3}>3 - Rejected</option>
                  </select>
                </div>

                {business.ownerPanNumber && (
                  <DetailField
                    label="PAN Number"
                    value={business.ownerPanNumber}
                    disabled
                    rightElement={<Lock className="h-4 w-4 text-muted-foreground shrink-0" />}
                  />
                )}

                {business.ownerAadhaarLast4 && (
                  <DetailField
                    label="Aadhaar (Last 4 Digits)"
                    value={`•••• •••• ${business.ownerAadhaarLast4}`}
                    disabled
                    rightElement={<Lock className="h-4 w-4 text-muted-foreground shrink-0" />}
                  />
                )}
              </div>

              <div className="flex justify-end pt-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    void handleSaveChanges({
                      ownerFullName: form.ownerFullName.trim(),
                      ownerWhatsApp: form.ownerWhatsApp.trim(),
                      ownerKycStatus: form.ownerKycStatus,
                    })
                  }
                  disabled={isSaving}
                  className="text-xs"
                >
                  <Save className="h-3.5 w-3.5 mr-1" />
                  Save Owner & KYC Info
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Card 3: Compliance, Tax & Settlement Bank */}
          <Card className="shadow-xs">
            <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-3">
              <div className="flex items-center gap-2">
                <FileText className="h-5 w-5 text-primary" />
                <CardTitle className="text-base font-bold">Compliance, Tax & Settlement Bank</CardTitle>
              </div>
              <Badge
                variant={business.bankPennyVerified ? 'success' : 'muted'}
                className="text-xs font-semibold"
              >
                {business.bankPennyVerified ? 'Bank Penny Verified' : 'Bank Unverified'}
              </Badge>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <DetailField
                  label="FSSAI License Number"
                  value={form.fssaiNumber}
                  onChange={(val) => updateField('fssaiNumber', val)}
                  placeholder="14-digit FSSAI Number"
                />

                <DetailField
                  label="GSTIN Number (Optional)"
                  value={form.gstNumber}
                  onChange={(val) => updateField('gstNumber', val)}
                  placeholder="15-character GSTIN"
                />

                <DetailField
                  label="UPI Payment ID (for Direct Diner Payouts)"
                  value={form.upiId}
                  onChange={(val) => updateField('upiId', val)}
                  placeholder="e.g. restaurant@okaxis"
                />

                <DetailField
                  label="Bank Account Number"
                  value={form.bankAccountNumber}
                  onChange={(val) => updateField('bankAccountNumber', val)}
                  placeholder="Account Number"
                />

                <DetailField
                  label="Bank IFSC Code"
                  value={form.bankIfsc}
                  onChange={(val) => updateField('bankIfsc', val.toUpperCase())}
                  placeholder="11-character IFSC Code (e.g. SBIN0001234)"
                  className="sm:col-span-2"
                />
              </div>

              <div className="flex justify-end pt-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() =>
                    void handleSaveChanges({
                      fssaiNumber: form.fssaiNumber.trim(),
                      gstNumber: form.gstNumber.trim(),
                      upiId: form.upiId.trim(),
                      bankAccountNumber: form.bankAccountNumber.trim(),
                      bankIfsc: form.bankIfsc.trim(),
                    })
                  }
                  disabled={isSaving}
                  className="text-xs"
                >
                  <Save className="h-3.5 w-3.5 mr-1" />
                  Save Compliance & Bank Details
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Card 4: Internal Admin Notes */}
          <Card className="shadow-xs">
            <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-3">
              <CardTitle className="text-base font-bold flex items-center gap-2">
                <FileText className="h-5 w-5 text-amber-500" />
                Internal Admin Notes
              </CardTitle>
            </CardHeader>
            <CardContent className="p-6 space-y-4">
              <p className="text-xs text-muted-foreground">
                Private notes visible only to super admins and staff. Use this to track verification audits, manual calls, or special arrangements.
              </p>
              <textarea
                value={form.adminNotes}
                onChange={(e) => updateField('adminNotes', e.target.value)}
                placeholder="e.g. Called owner on 20th Nov, confirmed physical store address, approved for 15 tables with high-res photo shoot."
                rows={4}
                className="w-full rounded-lg border border-border bg-card p-3 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/30"
              />
              <div className="flex justify-end">
                <Button
                  size="sm"
                  onClick={() =>
                    void handleSaveChanges({
                      adminNotes: form.adminNotes.trim(),
                    })
                  }
                  disabled={isSaving}
                  className="text-xs"
                >
                  <Save className="h-3.5 w-3.5 mr-1" />
                  Save Admin Notes
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right Column (1 col wide on desktop): Subscription & GST Billing */}
        <div className="space-y-6">
          <Card className="shadow-xs border-amber-500/20">
            <CardHeader className="flex flex-row items-center justify-between border-b border-border/60 pb-3 bg-amber-500/5">
              <div className="flex items-center gap-2">
                <Crown className="h-5 w-5 text-amber-500" />
                <CardTitle className="text-base font-bold">Subscription & Licensing</CardTitle>
              </div>
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
                className="text-xs font-semibold"
              >
                {business.subscriptionStatus === 'Active'
                  ? 'Active Plan'
                  : business.subscriptionStatus === 'Trial'
                    ? '7-Day Free Trial'
                    : business.subscriptionStatus === 'Expired'
                      ? 'Plan Expired'
                      : 'No Active Plan'}
              </Badge>
            </CardHeader>
            <CardContent className="p-6 space-y-5">
              {/* Plan Details Breakdown */}
              <div className="space-y-3 rounded-lg border border-border bg-muted/20 p-4 text-sm">
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground">Current Plan</span>
                  <span className="font-bold text-foreground">
                    {business.subscriptionPlanName ||
                      (business.subscriptionStatus === 'Trial' ? '7-Day Free Trial' : 'None')}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground">Remaining Validity</span>
                  <span className="font-semibold text-primary">
                    {business.subscriptionDaysRemaining != null &&
                    business.subscriptionDaysRemaining > 0
                      ? `${business.subscriptionDaysRemaining} days remaining`
                      : business.subscriptionStatus === 'Active' ||
                          business.subscriptionStatus === 'Trial'
                        ? 'Ending today'
                        : '0 days'}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground">Plan Starts</span>
                  <span className="font-mono text-xs">
                    {business.subscriptionStartsAt
                      ? business.subscriptionStartsAt.slice(0, 10)
                      : '—'}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs text-muted-foreground">Plan Expires</span>
                  <span className="font-mono text-xs">
                    {business.subscriptionEndsAt
                      ? business.subscriptionEndsAt.slice(0, 10)
                      : '—'}
                  </span>
                </div>
              </div>

              {/* Super Admin Plan Provisioning */}
              <div className="space-y-2">
                <span className="text-xs font-bold text-muted-foreground uppercase tracking-wider block">
                  Admin Plan Provisioning
                </span>
                <div className="grid grid-cols-2 gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-8 text-xs border-amber-500/30 text-amber-600 hover:bg-amber-500/10 justify-start"
                    disabled={planActionLoading}
                    onClick={() => handleGrantPlan('trial-7-days')}
                  >
                    <Sparkles className="mr-1.5 h-3.5 w-3.5 text-amber-500" />
                    7D Trial
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-8 text-xs hover:bg-muted justify-start"
                    disabled={planActionLoading}
                    onClick={() => handleGrantPlan('plan-3-months')}
                  >
                    3M Starter
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-8 text-xs border-primary/30 text-primary hover:bg-primary/10 justify-start"
                    disabled={planActionLoading}
                    onClick={() => handleGrantPlan('plan-6-months')}
                  >
                    6M Growth
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    className="h-8 text-xs border-amber-600/40 text-amber-700 dark:text-amber-400 hover:bg-amber-600/10 font-semibold justify-start"
                    disabled={planActionLoading}
                    onClick={() => handleGrantPlan('plan-1-year')}
                  >
                    <Crown className="mr-1.5 h-3.5 w-3.5 text-amber-500" />
                    1Y VIP
                  </Button>
                </div>

                <div className="flex gap-2 pt-1">
                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-8 text-xs text-muted-foreground hover:bg-muted flex-1"
                    disabled={planActionLoading}
                    onClick={() => handleGrantPlan('plan-3-months', 30)}
                  >
                    +30 Days Extension
                  </Button>

                  {(business.subscriptionStatus === 'Active' ||
                    business.subscriptionStatus === 'Trial') && (
                    <Button
                      size="sm"
                      variant="ghost"
                      className="h-8 text-xs text-danger hover:bg-danger/10"
                      disabled={planActionLoading}
                      onClick={handleCancelPlan}
                    >
                      Expire Plan
                    </Button>
                  )}
                </div>
              </div>

              {/* Past Subscriptions & GST Tax Invoices */}
              <div className="pt-4 border-t border-border/80 space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-bold text-foreground flex items-center gap-1.5">
                    <ReceiptText className="h-4 w-4 text-primary" />
                    Past Subscriptions & GST Tax Invoices
                  </span>
                  <Button
                    size="sm"
                    variant="ghost"
                    className="h-7 px-2 text-xs text-muted-foreground"
                    onClick={() => void loadSubscriptionHistory(business.id)}
                    disabled={isLoadingHistory}
                  >
                    <History className={`h-3.5 w-3.5 mr-1 ${isLoadingHistory ? 'animate-spin' : ''}`} />
                    Refresh
                  </Button>
                </div>

                {isLoadingHistory ? (
                  <div className="flex items-center justify-center p-4 text-xs text-muted-foreground">
                    <RefreshCw className="mr-2 h-4 w-4 animate-spin" />
                    Loading invoices...
                  </div>
                ) : historyList.length === 0 ? (
                  <div className="rounded-lg border border-dashed border-border/80 p-4 text-center text-xs text-muted-foreground">
                    No past subscriptions or invoices found for this business.
                  </div>
                ) : (
                  <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
                    {historyList.map((item) => (
                      <div
                        key={item.id}
                        className="rounded-lg border border-border/70 bg-card p-3 space-y-2 hover:border-border transition-colors shadow-2xs"
                      >
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-2">
                            <span className="font-semibold text-xs text-foreground">
                              {item.planName}
                            </span>
                            <Badge
                              variant={
                                item.status === 'Active'
                                  ? 'success'
                                  : item.status === 'Trial'
                                    ? 'warning'
                                    : item.status === 'Expired'
                                      ? 'danger'
                                      : 'muted'
                              }
                              className="text-[10px] px-1.5 py-0"
                            >
                              {item.status}
                            </Badge>
                          </div>
                          {item.invoiceNumber && (
                            <span className="font-mono text-[10px] text-muted-foreground font-medium">
                              #{item.invoiceNumber}
                            </span>
                          )}
                        </div>

                        <div className="text-[11px] text-muted-foreground">
                          {item.startsAt.slice(0, 10)} to {item.endsAt.slice(0, 10)}
                        </div>

                        <div className="flex items-center justify-between pt-1 border-t border-border/40">
                          <div className="text-xs font-semibold text-foreground">
                            {item.totalAmountPaise ? (
                              <>
                                {formatPaise(item.totalAmountPaise)}{' '}
                                <span className="text-[10px] font-normal text-muted-foreground">
                                  (incl. 18% GST)
                                </span>
                              </>
                            ) : (
                              'Free / Trial'
                            )}
                          </div>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 px-2.5 text-xs border-primary/30 text-primary hover:bg-primary/10"
                            onClick={() => {
                              const url = adminService.getSubscriptionInvoiceHtmlUrl(item.id)
                              window.open(url, '_blank')
                            }}
                            title="Download official GST Tax Invoice"
                          >
                            <Download className="mr-1.5 h-3 w-3" />
                            GST Bill
                          </Button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
