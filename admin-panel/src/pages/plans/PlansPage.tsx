import {
  AlertCircle,
  Calendar,
  Check,
  CheckCircle2,
  CreditCard,
  Flame,
  Info,
  Layers,
  Pencil,
  Percent,
  Plus,
  Power,
  RotateCcw,
  Search,
  ShieldCheck,
  Sparkles,
  Tag,
  Trash2,
  Users,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Skeleton } from '@/components/ui/skeleton'
import { adminService } from '@/services/adminService'
import {
  type CreateSubscriptionPlanPayload,
  type SubscriptionPlan,
  type UpdateSubscriptionPlanPayload,
  formatPaise,
} from '@/types/admin'

interface PlanFormData {
  name: string
  slug: string
  durationDays: number
  basePriceRupees: number | string
  originalPriceRupees: number | string
  discountPercent: number | string
  maxProducts: number | string
  badge: string
  description: string
  facilitiesText: string
  includesShoot: boolean
  shootsPerYear: number | string
  whatsappSupport: boolean
  analyticsExport: boolean
  apiIntegration: boolean
  isActive: boolean
  displayOrder: number | string
}

const DEFAULT_FORM: PlanFormData = {
  name: '',
  slug: '',
  durationDays: 30,
  basePriceRupees: 599,
  originalPriceRupees: '',
  discountPercent: 0,
  maxProducts: 50,
  badge: '',
  description: '',
  facilitiesText:
    'Interactive 3D AR Menu Visualizer\nTable QR Codes + Standee PDF\nLive Kitchen Order Tickets (KOT)\nTable Billing POS & Round Tracking\nStandard WhatsApp & Email Support',
  includesShoot: false,
  shootsPerYear: 0,
  whatsappSupport: true,
  analyticsExport: false,
  apiIntegration: false,
  isActive: true,
  displayOrder: 1,
}

export function PlansPage() {
  const [plans, setPlans] = useState<SubscriptionPlan[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Filters
  const [searchQuery, setSearchQuery] = useState('')
  const [statusFilter, setStatusFilter] = useState<'all' | 'active' | 'inactive'>('all')

  // Modals
  const [modalMode, setModalMode] = useState<'create' | 'edit' | null>(null)
  const [selectedPlan, setSelectedPlan] = useState<SubscriptionPlan | null>(null)
  const [formData, setFormData] = useState<PlanFormData>(DEFAULT_FORM)
  const [formSubmitting, setFormSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  // Delete modal
  const [planToDelete, setPlanToDelete] = useState<SubscriptionPlan | null>(null)
  const [isDeleting, setIsDeleting] = useState(false)

  const fetchPlans = async () => {
    try {
      setLoading(true)
      setError(null)
      const data = await adminService.listPlans()
      setPlans(data)
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load plans')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchPlans()
  }, [])

  const filteredPlans = useMemo(() => {
    return plans.filter((p) => {
      if (statusFilter === 'active' && !p.isActive) return false
      if (statusFilter === 'inactive' && p.isActive) return false

      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase()
        const matchesName = p.name.toLowerCase().includes(q)
        const matchesSlug = p.slug.toLowerCase().includes(q)
        const matchesBadge = p.badge?.toLowerCase().includes(q)
        const matchesDesc = p.description?.toLowerCase().includes(q)
        if (!matchesName && !matchesSlug && !matchesBadge && !matchesDesc) return false
      }
      return true
    })
  }, [plans, statusFilter, searchQuery])

  // Statistics
  const totalActive = useMemo(() => plans.filter((p) => p.isActive).length, [plans])
  const discountedCount = useMemo(
    () => plans.filter((p) => p.isActive && p.discountPercent > 0).length,
    [plans],
  )
  const totalSubscribers = useMemo(
    () => plans.reduce((acc, p) => acc + (p.subscriberCount ?? 0), 0),
    [plans],
  )

  const handleOpenCreate = () => {
    setModalMode('create')
    setSelectedPlan(null)
    setFormData({
      ...DEFAULT_FORM,
      displayOrder: plans.length + 1,
    })
    setFormError(null)
  }

  const handleOpenEdit = (plan: SubscriptionPlan) => {
    setModalMode('edit')
    setSelectedPlan(plan)
    const facilitiesList = Array.isArray(plan.facilities)
      ? plan.facilities
      : typeof plan.facilities === 'string'
        ? [plan.facilities]
        : []

    setFormData({
      name: plan.name,
      slug: plan.slug,
      durationDays: plan.durationDays,
      basePriceRupees: Math.round(plan.basePricePaise / 100),
      originalPriceRupees:
        plan.originalPricePaise != null ? Math.round(plan.originalPricePaise / 100) : '',
      discountPercent: plan.discountPercent,
      maxProducts: plan.maxProducts,
      badge: plan.badge ?? '',
      description: plan.description ?? '',
      facilitiesText: facilitiesList.join('\n'),
      includesShoot: plan.includesShoot,
      shootsPerYear: plan.shootsPerYear,
      whatsappSupport: Boolean(plan.whatsappSupport),
      analyticsExport: Boolean(plan.analyticsExport),
      apiIntegration: Boolean(plan.apiIntegration),
      isActive: plan.isActive,
      displayOrder: plan.displayOrder,
    })
    setFormError(null)
  }

  const handleSavePlan = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)

    if (!formData.name.trim()) {
      setFormError('Plan Name is required')
      return
    }

    if (!formData.slug.trim()) {
      setFormError('Slug is required')
      return
    }

    const duration = Number(formData.durationDays)
    if (isNaN(duration) || duration <= 0) {
      setFormError('Duration must be at least 1 day')
      return
    }

    const basePriceRupees = Number(formData.basePriceRupees)
    if (isNaN(basePriceRupees) || basePriceRupees < 0) {
      setFormError('Base price must be 0 (for free trial) or a positive amount')
      return
    }

    const discountPct = Number(formData.discountPercent || 0)
    if (isNaN(discountPct) || discountPct < 0 || discountPct > 100) {
      setFormError('Discount percent must be between 0 and 100%')
      return
    }

    const origPriceRupees = formData.originalPriceRupees !== '' ? Number(formData.originalPriceRupees) : null
    if (origPriceRupees != null && origPriceRupees < basePriceRupees) {
      setFormError('Original price must be greater than or equal to discounted base price')
      return
    }

    const facilities = formData.facilitiesText
      .split('\n')
      .map((f) => f.trim())
      .filter(Boolean)

    const basePricePaise = Math.round(basePriceRupees * 100)
    const originalPricePaise = origPriceRupees != null ? Math.round(origPriceRupees * 100) : null

    setFormSubmitting(true)
    try {
      if (modalMode === 'create') {
        const payload: CreateSubscriptionPlanPayload = {
          name: formData.name.trim(),
          slug: formData.slug.trim().toLowerCase(),
          basePricePaise,
          originalPricePaise,
          discountPercent: discountPct,
          durationDays: duration,
          maxProducts: Number(formData.maxProducts) || 50,
          description: formData.description.trim() || undefined,
          badge: formData.badge.trim() || undefined,
          facilities,
          includesShoot: formData.includesShoot,
          shootsPerYear: Number(formData.shootsPerYear) || 0,
          whatsappSupport: formData.whatsappSupport,
          analyticsExport: formData.analyticsExport,
          apiIntegration: formData.apiIntegration,
          displayOrder: Number(formData.displayOrder) || 1,
          isActive: formData.isActive,
        }
        await adminService.createPlan(payload)
        setSuccessMessage(`Plan "${formData.name}" created successfully!`)
      } else if (modalMode === 'edit' && selectedPlan) {
        const payload: UpdateSubscriptionPlanPayload = {
          name: formData.name.trim(),
          slug: formData.slug.trim().toLowerCase(),
          basePricePaise,
          originalPricePaise,
          discountPercent: discountPct,
          durationDays: duration,
          maxProducts: Number(formData.maxProducts) || 50,
          description: formData.description.trim() || undefined,
          badge: formData.badge.trim() || undefined,
          facilities,
          includesShoot: formData.includesShoot,
          shootsPerYear: Number(formData.shootsPerYear) || 0,
          whatsappSupport: formData.whatsappSupport,
          analyticsExport: formData.analyticsExport,
          apiIntegration: formData.apiIntegration,
          displayOrder: Number(formData.displayOrder) || 1,
          isActive: formData.isActive,
        }
        await adminService.updatePlan(selectedPlan.id, payload)
        setSuccessMessage(`Plan "${formData.name}" updated successfully! Note: Active subscribers continue unaffected.`)
      }

      setModalMode(null)
      await fetchPlans()
      setTimeout(() => setSuccessMessage(null), 5000)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to save plan')
    } finally {
      setFormSubmitting(false)
    }
  }

  const handleToggleStatus = async (plan: SubscriptionPlan) => {
    try {
      const updated = await adminService.togglePlanStatus(plan.id)
      setPlans((prev) => prev.map((p) => (p.id === plan.id ? updated : p)))
      setSuccessMessage(
        `Plan "${plan.name}" is now ${updated.isActive ? 'Active (Live)' : 'Disabled'}. Existing subscribers continue unaffected.`,
      )
      setTimeout(() => setSuccessMessage(null), 4000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to toggle status')
    }
  }

  const handleDeletePlan = async () => {
    if (!planToDelete) return
    setIsDeleting(true)
    try {
      await adminService.deletePlan(planToDelete.id)
      setSuccessMessage(
        `Plan "${planToDelete.name}" was safely removed/archived. Active subscribers will continue their plan until expiry without any disruption.`,
      )
      setPlanToDelete(null)
      await fetchPlans()
      setTimeout(() => setSuccessMessage(null), 5000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete plan')
    } finally {
      setIsDeleting(false)
    }
  }

  // Live GST & Total calculation in Form
  const previewBase = Number(formData.basePriceRupees) || 0
  const previewGst = Math.round(previewBase * 0.18 * 100) / 100
  const previewTotal = Math.round((previewBase + previewGst) * 100) / 100

  return (
    <div className="space-y-6">
      {/* Header with Title & Add Action */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="flex items-center gap-2 text-2xl font-bold tracking-tight text-foreground">
            <CreditCard className="h-6 w-6 text-primary" />
            Subscription Plans & Festival Pricing
          </h2>
          <p className="text-sm text-muted-foreground">
            Configure dynamic plans, set festival discounts (e.g. Diwali / New Year offers), and manage pricing anytime.
            Changes apply to new purchases and renewals without disrupting active businesses.
          </p>
        </div>
        <Button onClick={handleOpenCreate} className="gap-2 shrink-0">
          <Plus className="h-4 w-4" />
          Add New Plan
        </Button>
      </div>

      {/* Success Notification Alert */}
      {successMessage && (
        <div className="flex items-center gap-3 rounded-lg border border-success/30 bg-success/10 p-4 text-sm font-medium text-success">
          <CheckCircle2 className="h-5 w-5 shrink-0" />
          <span>{successMessage}</span>
          <button
            onClick={() => setSuccessMessage(null)}
            className="ml-auto text-success/70 hover:text-success"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {/* Error Alert */}
      {error && (
        <div className="flex items-center gap-3 rounded-lg border border-danger/30 bg-danger/10 p-4 text-sm font-medium text-danger">
          <AlertCircle className="h-5 w-5 shrink-0" />
          <span>{error}</span>
          <button
            onClick={() => setError(null)}
            className="ml-auto text-danger/70 hover:text-danger"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {/* Metric Cards */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Card className="border-border bg-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Total Active Plans
            </CardTitle>
            <Layers className="h-4 w-4 text-primary" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">{totalActive}</div>
            <p className="text-xs text-muted-foreground">Visible on owner app</p>
          </CardContent>
        </Card>

        <Card className="border-border bg-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Festival Discounts
            </CardTitle>
            <Flame className="h-4 w-4 text-amber-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-amber-500">{discountedCount}</div>
            <p className="text-xs text-muted-foreground">Plans with active % OFF</p>
          </CardContent>
        </Card>

        <Card className="border-border bg-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Active Subscribers
            </CardTitle>
            <Users className="h-4 w-4 text-success" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-success">{totalSubscribers}</div>
            <p className="text-xs text-muted-foreground">Businesses currently active</p>
          </CardContent>
        </Card>

        <Card className="border-border bg-card">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Monthly Base Benchmark
            </CardTitle>
            <Percent className="h-4 w-4 text-primary" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">₹599/mo</div>
            <p className="text-xs text-muted-foreground">Standard monthly rate</p>
          </CardContent>
        </Card>
      </div>

      {/* Safety Notice Banner */}
      <div className="flex items-start gap-3 rounded-lg border border-primary/20 bg-primary/5 p-4 text-xs text-foreground/80">
        <ShieldCheck className="mt-0.5 h-4 w-4 shrink-0 text-primary" />
        <div className="space-y-1">
          <span className="font-semibold text-primary">Enterprise Business Protection & Safety Guarantee</span>
          <p>
            When you edit amounts or delete a plan, active business subscriptions are <strong>never interrupted or charged extra</strong>.
            Their active duration, features, and dish limits continue until their scheduled expiration date. Deleting a plan archives it so no new businesses can buy it, ensuring zero service disruptions.
          </p>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-wrap items-center gap-3">
        <div className="relative min-w-[240px] flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search plan by name, slug, badge..."
            className="pl-9"
          />
        </div>

        <div className="flex items-center gap-1 rounded-lg border border-border bg-card p-1">
          {(['all', 'active', 'inactive'] as const).map((status) => (
            <button
              key={status}
              onClick={() => setStatusFilter(status)}
              className={`rounded px-3 py-1.5 text-xs font-medium capitalize transition ${
                statusFilter === status
                  ? 'bg-primary text-primary-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              {status}
            </button>
          ))}
        </div>

        {(searchQuery || statusFilter !== 'all') && (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setSearchQuery('')
              setStatusFilter('all')
            }}
            className="gap-1 text-xs"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Reset
          </Button>
        )}
      </div>

      {/* Plans List / Grid */}
      {loading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-72 w-full rounded-xl" />
          ))}
        </div>
      ) : filteredPlans.length === 0 ? (
        <div className="rounded-xl border border-dashed border-border p-12 text-center">
          <CreditCard className="mx-auto h-10 w-10 text-muted-foreground" />
          <h3 className="mt-3 text-base font-semibold text-foreground">No subscription plans found</h3>
          <p className="mt-1 text-sm text-muted-foreground">
            {searchQuery || statusFilter !== 'all'
              ? 'Try adjusting your filters or search keywords.'
              : 'Click "Add New Plan" to configure your first subscription plan.'}
          </p>
        </div>
      ) : (
        <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
          {filteredPlans.map((plan) => {
            const isFree = plan.basePricePaise === 0
            const facilitiesList = Array.isArray(plan.facilities)
              ? plan.facilities
              : typeof plan.facilities === 'string'
                ? [plan.facilities]
                : []

            return (
              <Card
                key={plan.id}
                className={`relative flex flex-col justify-between overflow-hidden border transition hover:shadow-md ${
                  plan.isActive ? 'border-border bg-card' : 'border-border/60 bg-muted/20 opacity-80'
                }`}
              >
                {/* Top Badge Ribbon */}
                {plan.badge && (
                  <div className="bg-gradient-to-r from-amber-500 to-primary px-3 py-1 text-center text-xs font-bold text-white shadow-sm">
                    {plan.badge}
                  </div>
                )}

                <CardHeader className="space-y-2 pb-3">
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <CardTitle className="text-lg font-bold text-foreground">
                        {plan.name}
                      </CardTitle>
                      <span className="font-mono text-xs text-muted-foreground">
                        slug: {plan.slug}
                      </span>
                    </div>

                    <div className="flex flex-col items-end gap-1">
                      <Badge variant={plan.isActive ? 'success' : 'muted'}>
                        {plan.isActive ? 'Active' : 'Disabled'}
                      </Badge>
                      {plan.subscriberCount != null && plan.subscriberCount > 0 && (
                        <span className="flex items-center gap-1 rounded bg-primary/10 px-1.5 py-0.5 text-[11px] font-semibold text-primary">
                          <Users className="h-3 w-3" />
                          {plan.subscriberCount} subscribed
                        </span>
                      )}
                    </div>
                  </div>

                  {plan.description && (
                    <p className="text-xs text-muted-foreground line-clamp-2">
                      {plan.description}
                    </p>
                  )}
                </CardHeader>

                <CardContent className="space-y-4 text-sm flex-1">
                  {/* Pricing Box */}
                  <div className="rounded-lg border border-border bg-muted/30 p-3 space-y-1">
                    <div className="flex items-baseline gap-2">
                      {isFree ? (
                        <span className="text-2xl font-extrabold text-foreground">FREE</span>
                      ) : (
                        <>
                          <span className="text-2xl font-extrabold text-foreground">
                            {formatPaise(plan.basePricePaise)}
                          </span>
                          <span className="text-xs text-muted-foreground">
                            + 18% GST ({formatPaise(plan.gstPaise)})
                          </span>
                        </>
                      )}

                      {plan.originalPricePaise && plan.originalPricePaise > plan.basePricePaise && (
                        <span className="text-sm text-muted-foreground line-through">
                          {formatPaise(plan.originalPricePaise)}
                        </span>
                      )}

                      {plan.discountPercent > 0 && (
                        <Badge variant="warning" className="ml-auto text-[11px] font-bold">
                          {plan.discountPercent}% OFF
                        </Badge>
                      )}
                    </div>

                    {!isFree && (
                      <div className="text-xs font-semibold text-foreground/80">
                        Total with GST: {formatPaise(plan.totalPricePaise)}
                      </div>
                    )}
                  </div>

                  {/* Plan Specs */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="flex items-center gap-1.5 text-muted-foreground">
                      <Calendar className="h-3.5 w-3.5 text-primary" />
                      <span>{plan.durationDays} Days Duration</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-muted-foreground">
                      <Layers className="h-3.5 w-3.5 text-primary" />
                      <span>Up to {plan.maxProducts >= 999999 ? 'Unlimited' : plan.maxProducts} Dishes</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-muted-foreground">
                      <Sparkles className="h-3.5 w-3.5 text-primary" />
                      <span>
                        {plan.includesShoot ? `${plan.shootsPerYear} shoot(s)/yr` : 'No Shoot'}
                      </span>
                    </div>
                    <div className="flex items-center gap-1.5 text-muted-foreground">
                      <Tag className="h-3.5 w-3.5 text-primary" />
                      <span>Order: #{plan.displayOrder}</span>
                    </div>
                  </div>

                  {/* Facilities Bullet Points */}
                  {facilitiesList.length > 0 && (
                    <div className="space-y-1.5 border-t border-border pt-3">
                      <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                        Included Features
                      </span>
                      <ul className="space-y-1 text-xs text-foreground/90 max-h-36 overflow-y-auto pr-1">
                        {facilitiesList.slice(0, 5).map((facility, idx) => (
                          <li key={idx} className="flex items-start gap-1.5">
                            <Check className="mt-0.5 h-3.5 w-3.5 shrink-0 text-success" />
                            <span className="line-clamp-1">{facility}</span>
                          </li>
                        ))}
                        {facilitiesList.length > 5 && (
                          <li className="text-[11px] text-muted-foreground font-medium pl-5">
                            +{facilitiesList.length - 5} more features...
                          </li>
                        )}
                      </ul>
                    </div>
                  )}
                </CardContent>

                {/* Bottom Action Footer */}
                <div className="flex items-center justify-between border-t border-border bg-muted/10 p-3 gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleToggleStatus(plan)}
                    className="gap-1.5 text-xs"
                    title={plan.isActive ? 'Deactivate (Disable) Plan' : 'Activate Plan'}
                  >
                    <Power className={`h-3.5 w-3.5 ${plan.isActive ? 'text-success' : 'text-muted-foreground'}`} />
                    {plan.isActive ? 'Active' : 'Disabled'}
                  </Button>

                  <div className="flex items-center gap-1">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleOpenEdit(plan)}
                      className="gap-1 text-xs"
                    >
                      <Pencil className="h-3.5 w-3.5 text-primary" />
                      Edit
                    </Button>

                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => setPlanToDelete(plan)}
                      className="text-danger hover:bg-danger/10 hover:text-danger p-2"
                      title="Safely Delete / Archive Plan"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </Card>
            )
          })}
        </div>
      )}

      {/* Add / Edit Plan Modal */}
      {modalMode && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs">
          <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-xl border border-border bg-card p-6 shadow-2xl space-y-5">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <div>
                <h3 className="text-lg font-bold text-foreground">
                  {modalMode === 'create' ? 'Create New Subscription Plan' : `Edit Plan: ${selectedPlan?.name}`}
                </h3>
                <p className="text-xs text-muted-foreground">
                  {modalMode === 'create'
                    ? 'Add a new standard or festival plan with special discounts.'
                    : 'Update pricing or discount terms. Note: Active businesses continue their bought terms safely.'}
                </p>
              </div>
              <button
                onClick={() => setModalMode(null)}
                className="rounded-lg p-1.5 text-muted-foreground hover:bg-muted"
              >
                <X className="h-5 w-5" />
              </button>
            </div>

            {formError && (
              <div className="flex items-center gap-2 rounded-lg border border-danger/30 bg-danger/10 p-3 text-xs font-semibold text-danger">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}

            <form onSubmit={handleSavePlan} className="space-y-4">
              {/* Row 1: Name and Slug */}
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">
                    Plan Name <span className="text-danger">*</span>
                  </label>
                  <Input
                    required
                    value={formData.name}
                    onChange={(e) => {
                      const name = e.target.value
                      setFormData((prev) => ({
                        ...prev,
                        name,
                        // Auto-generate slug on creation if empty
                        slug:
                          modalMode === 'create' && !prev.slug
                            ? name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
                            : prev.slug,
                      }))
                    }}
                    placeholder="e.g. Diwali Dhamaka Starter"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">
                    Slug (URL identifier) <span className="text-danger">*</span>
                  </label>
                  <Input
                    required
                    value={formData.slug}
                    onChange={(e) =>
                      setFormData((prev) => ({
                        ...prev,
                        slug: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ''),
                      }))
                    }
                    placeholder="e.g. diwali-starter-2026"
                  />
                </div>
              </div>

              {/* Row 2: Duration & Max Products */}
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">
                    Duration (Days) <span className="text-danger">*</span>
                  </label>
                  <Input
                    type="number"
                    min={1}
                    value={formData.durationDays}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, durationDays: Number(e.target.value) }))
                    }
                    placeholder="30"
                  />
                  <span className="text-[10px] text-muted-foreground">30=1mo, 90=3mo, 365=1yr</span>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">Max Products</label>
                  <Input
                    type="number"
                    min={1}
                    value={formData.maxProducts}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, maxProducts: e.target.value }))
                    }
                    placeholder="50"
                  />
                  <span className="text-[10px] text-muted-foreground">e.g. 50, 250, or 999999 for Unlimited</span>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">Display Order</label>
                  <Input
                    type="number"
                    value={formData.displayOrder}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, displayOrder: e.target.value }))
                    }
                    placeholder="1"
                  />
                  <span className="text-[10px] text-muted-foreground">Sort priority on app</span>
                </div>
              </div>

              {/* Row 3: Pricing and Festival Discounts */}
              <div className="rounded-lg border border-border bg-muted/20 p-3 space-y-3">
                <span className="text-xs font-bold uppercase tracking-wider text-primary flex items-center gap-1.5">
                  <Percent className="h-3.5 w-3.5" />
                  Pricing & Festival Discounts
                </span>

                <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
                  <div className="space-y-1">
                    <label className="text-xs font-semibold text-foreground">
                      Base Price (₹) <span className="text-danger">*</span>
                    </label>
                    <Input
                      type="number"
                      min={0}
                      value={formData.basePriceRupees}
                      onChange={(e) =>
                        setFormData((prev) => ({ ...prev, basePriceRupees: e.target.value }))
                      }
                      placeholder="599"
                    />
                    <span className="text-[10px] text-muted-foreground">Exclusive of 18% GST</span>
                  </div>

                  <div className="space-y-1">
                    <label className="text-xs font-semibold text-foreground">Discount % (Optional)</label>
                    <Input
                      type="number"
                      min={0}
                      max={100}
                      value={formData.discountPercent}
                      onChange={(e) =>
                        setFormData((prev) => ({ ...prev, discountPercent: e.target.value }))
                      }
                      placeholder="e.g. 20"
                    />
                    <span className="text-[10px] text-muted-foreground">Festival discount %</span>
                  </div>

                  <div className="space-y-1">
                    <label className="text-xs font-semibold text-foreground">Original Strikethrough Price (₹)</label>
                    <Input
                      type="number"
                      min={0}
                      value={formData.originalPriceRupees}
                      onChange={(e) =>
                        setFormData((prev) => ({ ...prev, originalPriceRupees: e.target.value }))
                      }
                      placeholder="e.g. 799"
                    />
                    <span className="text-[10px] text-muted-foreground">Shown with strikethrough</span>
                  </div>
                </div>

                {/* Real-time Calculation Summary */}
                <div className="flex items-center justify-between rounded-md bg-card p-2.5 text-xs border border-border">
                  <span className="text-muted-foreground">
                    Live Calculation: Base ₹{previewBase.toLocaleString()} + 18% GST (₹
                    {previewGst.toLocaleString()})
                  </span>
                  <span className="font-bold text-foreground">
                    Total: ₹{previewTotal.toLocaleString()}
                  </span>
                </div>
              </div>

              {/* Row 4: Badge & Description */}
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">Promotional Badge Ribbon</label>
                  <Input
                    value={formData.badge}
                    onChange={(e) => setFormData((prev) => ({ ...prev, badge: e.target.value }))}
                    placeholder="e.g. 🔥 Diwali Dhamaka (Save 30%)"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-semibold text-foreground">Short Description</label>
                  <Input
                    value={formData.description}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, description: e.target.value }))
                    }
                    placeholder="e.g. Complete 3D AR smart menu package for cafes."
                  />
                </div>
              </div>

              {/* Row 5: Features / Facilities List */}
              <div className="space-y-1">
                <label className="text-xs font-semibold text-foreground">
                  Features / Facilities List (One per line)
                </label>
                <textarea
                  rows={4}
                  value={formData.facilitiesText}
                  onChange={(e) =>
                    setFormData((prev) => ({ ...prev, facilitiesText: e.target.value }))
                  }
                  className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs text-foreground shadow-xs focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring font-mono"
                  placeholder="30 Days Platform Access&#10;Interactive 3D AR Menu Visualizer&#10;Live Kitchen Order Tickets (KOT)&#10;Table Billing POS"
                />
              </div>

              {/* Row 6: Toggles & Feature Checkboxes */}
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 rounded-lg border border-border p-3 text-xs">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.isActive}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, isActive: e.target.checked }))
                    }
                    className="rounded border-input text-primary"
                  />
                  <span className="font-semibold text-foreground">Active (Live)</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.whatsappSupport}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, whatsappSupport: e.target.checked }))
                    }
                    className="rounded border-input text-primary"
                  />
                  <span>WhatsApp Support</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.analyticsExport}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, analyticsExport: e.target.checked }))
                    }
                    className="rounded border-input text-primary"
                  />
                  <span>Analytics Export</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.apiIntegration}
                    onChange={(e) =>
                      setFormData((prev) => ({ ...prev, apiIntegration: e.target.checked }))
                    }
                    className="rounded border-input text-primary"
                  />
                  <span>API Integration</span>
                </label>
              </div>

              {/* Modal Buttons */}
              <div className="flex items-center justify-end gap-2 border-t border-border pt-3">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setModalMode(null)}
                  disabled={formSubmitting}
                >
                  Cancel
                </Button>
                <Button type="submit" disabled={formSubmitting}>
                  {formSubmitting ? 'Saving...' : modalMode === 'create' ? 'Create Plan' : 'Save Changes'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Delete / Archive Confirmation Modal */}
      {planToDelete && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-xs">
          <div className="w-full max-w-md rounded-xl border border-border bg-card p-6 shadow-2xl space-y-4">
            <div className="flex items-start gap-3">
              <div className="rounded-full bg-danger/10 p-2 text-danger">
                <AlertCircle className="h-6 w-6" />
              </div>
              <div className="space-y-1">
                <h3 className="text-base font-bold text-foreground">
                  Delete Plan "{planToDelete.name}"?
                </h3>
                <p className="text-xs text-muted-foreground">
                  Slug: <span className="font-mono">{planToDelete.slug}</span>
                </p>
              </div>
            </div>

            <div className="rounded-lg border border-border bg-muted/30 p-3 text-xs space-y-2">
              <div className="flex items-center justify-between font-semibold">
                <span className="text-muted-foreground">Active Subscribers:</span>
                <span className="text-primary font-bold">{planToDelete.subscriberCount ?? 0} businesses</span>
              </div>
              <div className="flex items-start gap-2 text-foreground/80 text-[11px] leading-relaxed">
                <Info className="h-4 w-4 shrink-0 text-primary mt-0.5" />
                <span>
                  <strong>Safe Archival Guarantee:</strong> This plan will be safely archived and hidden from new customer signups. Existing businesses who already purchased this plan will <strong>not be stopped or interrupted</strong>; their subscriptions will remain active until their scheduled expiration date.
                </span>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <Button
                variant="outline"
                size="sm"
                onClick={() => setPlanToDelete(null)}
                disabled={isDeleting}
              >
                Cancel
              </Button>
              <Button
                variant="destructive"
                size="sm"
                onClick={handleDeletePlan}
                disabled={isDeleting}
                className="gap-1.5"
              >
                {isDeleting ? 'Archiving...' : 'Yes, Safely Archive Plan'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
