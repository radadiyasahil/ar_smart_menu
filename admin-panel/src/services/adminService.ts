import type {
  AdminBusiness,
  AdminDashboardStats,
  AdminProductReviewItem,
  BusinessStatusFilter,
  ProcessingJob,
  SubscriptionPlan,
} from '@/types/admin'
import type { ApiEnvelope, PagedResult } from '@/types/api'

import { apiClient } from './apiClient'
import { ensureAdminAuth } from './authService'

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

  async submitQualityReview(
    jobId: string,
    decision: 1 | 2,
    rejectionReason?: string,
    improvementNotes?: string,
  ): Promise<void> {
    await ensureAdminAuth()
    await apiClient.post(`/qualityreview/${jobId}`, {
      decision,
      rejectionReason: rejectionReason || undefined,
      improvementNotes: improvementNotes || undefined,
      modelQualityScore: 85,
      textureQualityScore: 85,
      scaleAccuracyScore: 85,
      renderingQualityScore: 85,
    })
  },

  async publishProcessingJob(jobId: string): Promise<void> {
    await ensureAdminAuth()
    try {
      await apiClient.post(`/qualityreview/${jobId}/publish`)
    } catch (e: unknown) {
      const msg =
        (e as { response?: { data?: string } })?.response?.data ??
        'Publish failed — job must be approved first'
      throw new Error(typeof msg === 'string' ? msg : 'Publish failed')
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
    const res = await apiClient.get<ApiEnvelope<SubscriptionPlan[]>>('/subscriptions/plans')
    if (!res.data.success || !res.data.data) {
      throw new Error(res.data.error ?? 'Failed to load plans')
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
}
