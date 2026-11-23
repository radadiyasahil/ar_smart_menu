import type {
  AdminBusiness,
  AdminDashboardStats,
  AdminNotification,
  AdminNotificationsResponse,
  AdminOperationsSummary,
  AdminProductReviewItem,
  AdminUpdateBusinessPayload,
  BusinessStatusFilter,
  CreateSubscriptionPlanPayload,
  GstRateSetting,
  ProcessingJob,
  SubscriptionHistoryItem,
  SubscriptionInvoice,
  SubscriptionPlan,
  SupportContactSetting,
  UpdateSubscriptionPlanPayload,
  UpdateSupportContactPayload,
} from '@/types/admin'
import type { ApiEnvelope, PagedResult } from '@/types/api'

import { apiClient } from './apiClient'
import { ensureAdminAuth, getAdminToken } from './authService'

export type {
  AdminNotification,
  AdminNotificationsResponse,
  AdminUpdateBusinessPayload,
  GstRateSetting,
  SubscriptionHistoryItem,
  SubscriptionInvoice,
  SupportContactSetting,
  UpdateSupportContactPayload,
}

export interface BusinessListParams {
  status?: BusinessStatusFilter
  city?: string
  search?: string
  page?: number
  limit?: number
}

function statusToApi(status?: BusinessStatusFilter): number | undefined {
  if (!status || status === 'all') return undefined
  const map: Record<string, number> = {
    pending: 0,
    active: 1,
    suspended: 2,
    rejected: 3,
    deactivated: 4,
  }
  return map[status]
}

export const adminService = {
  async getDashboard(): Promise<AdminDashboardStats> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<AdminDashboardStats>>('/admin/dashboard')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load dashboard')
    }
    return res.data.data
  },

  async listBusinesses(params: BusinessListParams = {}): Promise<PagedResult<AdminBusiness>> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<PagedResult<AdminBusiness>>>(
      '/admin/businesses',
      {
        params: {
          page: params.page ?? 1,
          limit: params.limit ?? 20,
          city: params.city || undefined,
          search: params.search || undefined,
          status: statusToApi(params.status),
        },
      },
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load businesses')
    }
    return res.data.data
  },

  async getBusinessById(id: string): Promise<AdminBusiness> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<AdminBusiness>>(`/admin/businesses/${id}`)
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load business details')
    }
    return res.data.data
  },

  async updateBusiness(
    id: string,
    payload: AdminUpdateBusinessPayload,
  ): Promise<AdminBusiness> {
    await ensureAdminAuth()
    const res = await apiClient.put<ApiEnvelope<AdminBusiness>>(
      `/admin/businesses/${id}`,
      payload,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to update business')
    }
    return res.data.data
  },

  async approveBusiness(id: string, adminNotes?: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${id}/approve`,
      { adminNotes: adminNotes || undefined },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Approve failed')
    }
  },

  async rejectBusiness(id: string, reason: string, adminNotes?: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${id}/reject`,
      { reason, adminNotes: adminNotes || undefined },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Reject failed')
    }
  },

  async getProcessingQueue(): Promise<ProcessingJob[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ProcessingJob[]>('/processingqueue')
    return res.data ?? []
  },

  async retryProcessingJob(id: string): Promise<void> {
    await ensureAdminAuth()
    await apiClient.post(`/processingqueue/${id}/retry`)
  },

  async approveProduct(productId: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/products/${productId}/approve`,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to approve product')
    }
  },

  async rejectProduct(productId: string, reason: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/products/${productId}/reject`,
      { reason },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to reject product')
    }
  },

  async makeProductLive(productId: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/products/${productId}/make-live`,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to make product live')
    }
  },

  async submitQualityReview(
    jobId: string,
    decision: 1 | 2,
    rejectionReason?: string,
    improvementNotes?: string,
    productId?: string,
  ): Promise<void> {
    await ensureAdminAuth()
    try {
      await apiClient.post(`/qualityreview/${jobId}`, {
        decision,
        rejectionReason: rejectionReason || undefined,
        improvementNotes: improvementNotes || undefined,
        modelQualityScore: 85,
        textureQualityScore: 85,
        scaleAccuracyScore: 85,
        renderingQualityScore: 85,
      })
    } catch (e: unknown) {
      const targetId = productId || jobId
      if (decision === 1) {
        await this.approveProduct(targetId)
      } else {
        await this.rejectProduct(targetId, rejectionReason || 'Rejected by quality review')
      }
    }
  },

  async publishProcessingJob(jobId: string, productId?: string): Promise<void> {
    await ensureAdminAuth()
    try {
      await apiClient.post(`/qualityreview/${jobId}/publish`)
    } catch (e: unknown) {
      const targetId = productId || jobId
      try {
        await this.makeProductLive(targetId)
      } catch {
        const msg =
          (e as { response?: { data?: string } })?.response?.data ??
          'Publish failed — job must be approved first'
        throw new Error(typeof msg === 'string' ? msg : 'Publish failed')
      }
    }
  },

  async getProductReviewQueue(jobStatus?: number): Promise<AdminProductReviewItem[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<AdminProductReviewItem[]>>(
      '/admin/products/review-queue',
      { params: jobStatus !== undefined ? { jobStatus } : undefined },
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load product review queue')
    }
    return res.data.data
  },

  async enqueueProductProcessing(productId: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/products/${productId}/enqueue-processing`,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to start processing')
    }
  },

  async advanceJobToReview(jobId: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/processing-jobs/${jobId}/advance-to-review`,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to advance job to review')
    }
  },

  async listPlans(): Promise<SubscriptionPlan[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<SubscriptionPlan[]>>('/admin/plans')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load plans')
    }
    return res.data.data
  },

  async createPlan(payload: CreateSubscriptionPlanPayload): Promise<SubscriptionPlan> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<SubscriptionPlan>>('/admin/plans', payload)
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to create subscription plan')
    }
    return res.data.data
  },

  async updatePlan(id: string, payload: UpdateSubscriptionPlanPayload): Promise<SubscriptionPlan> {
    await ensureAdminAuth()
    const res = await apiClient.put<ApiEnvelope<SubscriptionPlan>>(`/admin/plans/${id}`, payload)
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to update subscription plan')
    }
    return res.data.data
  },

  async deletePlan(id: string): Promise<boolean> {
    await ensureAdminAuth()
    const res = await apiClient.delete<ApiEnvelope<boolean>>(`/admin/plans/${id}`)
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to delete subscription plan')
    }
    return res.data.data ?? true
  },

  async togglePlanStatus(id: string): Promise<SubscriptionPlan> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<SubscriptionPlan>>(`/admin/plans/${id}/toggle-status`)
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to toggle plan status')
    }
    return res.data.data
  },

  async setBusinessStatus(
    id: string,
    status: number,
    reason?: string,
    adminNotes?: string,
  ): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${id}/set-status`,
      {
        status,
        reason: reason || undefined,
        adminNotes: adminNotes || undefined,
      },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to update business status')
    }
  },

  async setProductStatus(productId: string, status: number): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/products/${productId}/set-status`,
      { status },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to update product status')
    }
  },

  async grantSubscription(
    businessId: string,
    payload: { planSlug: string; customDays?: number; notes?: string },
  ): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${businessId}/grant-subscription`,
      payload,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to grant subscription')
    }
  },

  async cancelSubscription(businessId: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${businessId}/cancel-subscription`,
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to cancel subscription')
    }
  },

  async updateBusinessSettings(
    businessId: string,
    payload: {
      customDishLimit?: number | null
      arViewEnabled?: boolean
      arPerViewChargePaise?: number
      arViewCredits?: number
    },
  ): Promise<AdminBusiness> {
    await ensureAdminAuth()
    const res = await apiClient.patch<ApiEnvelope<AdminBusiness>>(
      `/admin/businesses/${businessId}/settings`,
      payload,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to update business settings')
    }
    return res.data.data
  },

  async getNotifications(): Promise<AdminNotificationsResponse> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<AdminNotificationsResponse>>('/admin/notifications')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load notifications')
    }
    return res.data.data
  },

  async getOperationsSummary(): Promise<AdminOperationsSummary> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<AdminOperationsSummary>>('/admin/reports/operations-summary')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load operations summary')
    }
    return res.data.data
  },

  async downloadOperationsCsv(): Promise<void> {
    await ensureAdminAuth()
    const token = getAdminToken()
    const baseUrl = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5232/api'
    const res = await fetch(`${baseUrl}/admin/reports/operations-csv`, {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    })
    if (!res.ok) {
      throw new Error('Failed to download operations CSV report')
    }
    const blob = await res.blob()
    const blobUrl = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = blobUrl
    a.download = `ARSmartMenu_Operations_Report_${new Date().toISOString().slice(0, 10)}.csv`
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    window.URL.revokeObjectURL(blobUrl)
  },

  async getBusinessSubscriptionHistory(businessId: string): Promise<SubscriptionHistoryItem[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<SubscriptionHistoryItem[]>>(
      `/admin/businesses/${businessId}/subscriptions`,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load business subscriptions')
    }
    return res.data.data
  },

  async getBusinessSubscriptions(businessId: string): Promise<SubscriptionHistoryItem[]> {
    return this.getBusinessSubscriptionHistory(businessId)
  },

  async listSubscriptionHistory(params?: {
    businessId?: string
    search?: string
    status?: number
    fromDate?: string
    toDate?: string
  }): Promise<SubscriptionHistoryItem[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<SubscriptionHistoryItem[]>>(
      '/admin/subscriptions/history',
      { params },
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load subscription history')
    }
    return res.data.data
  },

  async getAllSubscriptionsHistory(): Promise<SubscriptionHistoryItem[]> {
    return this.listSubscriptionHistory()
  },

  async getSubscriptionInvoice(subscriptionId: string): Promise<SubscriptionInvoice> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<SubscriptionInvoice>>(
      `/subscriptions/${subscriptionId}/invoice`,
    )
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load subscription invoice')
    }
    return res.data.data
  },

  getSubscriptionInvoiceHtmlUrl(subscriptionId: string): string {
    const baseURL = apiClient.defaults.baseURL || '/api'
    const token = localStorage.getItem('ar_admin_token') || ''
    return `${baseURL}/subscriptions/${subscriptionId}/invoice/html?token=${encodeURIComponent(token)}`
  },

  async getGstRateSetting(): Promise<GstRateSetting> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<GstRateSetting>>('/admin/settings/gst-rate')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load GST rate setting')
    }
    return res.data.data
  },

  async updateGstRateSetting(gstRatePercent: number): Promise<GstRateSetting> {
    await ensureAdminAuth()
    const res = await apiClient.put<ApiEnvelope<GstRateSetting>>('/admin/settings/gst-rate', {
      gstRatePercent,
    })
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to update GST rate setting')
    }
    return res.data.data
  },

  async getSupportContactSetting(): Promise<SupportContactSetting> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<SupportContactSetting>>('/admin/settings/support-contact')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load support contact settings')
    }
    return res.data.data
  },

  async updateSupportContactSetting(payload: UpdateSupportContactPayload): Promise<SupportContactSetting> {
    await ensureAdminAuth()
    const res = await apiClient.put<ApiEnvelope<SupportContactSetting>>('/admin/settings/support-contact', payload)
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to update support contact settings')
    }
    return res.data.data
  },

  async resetOwnerPin(businessId: string, newPin: string): Promise<void> {
    await ensureAdminAuth()
    const res = await apiClient.post<ApiEnvelope<unknown>>(
      `/admin/businesses/${businessId}/reset-pin`,
      { newPin },
    )
    if (!res.data.success) {
      throw new Error(res.data.error ?? 'Failed to reset owner PIN')
    }
  },
}
