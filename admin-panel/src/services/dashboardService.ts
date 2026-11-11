import { apiClient } from './apiClient'
import { ensureAdminAuth } from './authService'
import type {
  ActivityItem,
  DashboardStats,
  RevenueDataPoint,
} from '@/types/dashboard'
import type { BusinessRow } from '@/types/business'

interface ApiEnvelope<T> {
  success: boolean
  data?: T
  error?: string
}

interface AdminDashboardDto {
  totalBusinesses: number
  activeBusinesses: number
  pendingApprovals: number
  pendingProductReviews: number
  totalScans: number
  totalArViews: number
  totalProducts: number
}

interface AdminBusinessItem {
  id: string
  businessName: string
  businessType: number
  city: string
  status: number
  ownerMobile: string
  ownerName?: string
  productCount: number
  createdAt: string
}

interface PagedResult<T> {
  items: T[]
  total: number
  page: number
  limit: number
}

const businessTypeLabels = ['Restaurant', 'Café', 'Bakery', 'Clothing', 'Furniture']
const statusMap: Record<number, BusinessRow['status']> = {
  0: 'pending',
  1: 'active',
  2: 'suspended',
  3: 'rejected',
}

function mapBusiness(row: AdminBusinessItem): BusinessRow {
  return {
    id: row.id,
    businessName: row.businessName,
    ownerName: row.ownerName ?? row.ownerMobile,
    category: businessTypeLabels[row.businessType] ?? 'Other',
    city: row.city,
    plan: '—',
    status: statusMap[row.status] ?? 'pending',
    joinedDate: row.createdAt.slice(0, 10),
  }
}

/** Real dashboard service — ASP.NET Core admin + pipeline APIs. */
export const dashboardService = {
  async getStats(): Promise<DashboardStats> {
    await ensureAdminAuth()
    const [dashRes, queueRes] = await Promise.all([
      apiClient.get<ApiEnvelope<AdminDashboardDto>>('/admin/dashboard'),
      apiClient.get<unknown[]>('/processingqueue').catch(() => ({ data: [] as unknown[] })),
    ])
    const d = dashRes.data.data!
    const queue = Array.isArray(queueRes.data) ? queueRes.data.length : 0
    return {
      totalBusinesses: d.totalBusinesses,
      totalArViews: d.totalArViews,
      totalRevenue: 0,
      pendingApprovals: d.pendingApprovals,
      pendingProductReviews: d.pendingProductReviews ?? 0,
      processingQueue: queue,
    }
  },

  async getRevenueChart(): Promise<RevenueDataPoint[]> {
    await ensureAdminAuth()
    try {
      const res = await apiClient.get<ApiEnvelope<{ labels: string[]; values: number[] }>>(
        '/analytics/chart',
        { params: { range: '30d', metric: 'scans' } },
      )
      const chart = res.data.data
      if (!chart) return []
      return chart.labels.map((date, i) => ({
        date,
        revenue: chart.values[i] ?? 0,
        subscriptions: 0,
        bookings: 0,
      }))
    } catch {
      return []
    }
  },

  async getRecentActivity(): Promise<ActivityItem[]> {
    await ensureAdminAuth()
    const businesses = await this.getRecentBusinesses()
    return businesses.slice(0, 5).map((b, i) => ({
      id: String(i + 1),
      type: 'business' as const,
      title: b.status === 'pending' ? 'Business pending approval' : 'Business registered',
      description: `${b.businessName} — ${b.city}`,
      timestamp: new Date().toISOString(),
    }))
  },

  async getRecentBusinesses(): Promise<BusinessRow[]> {
    await ensureAdminAuth()
    const res = await apiClient.get<ApiEnvelope<PagedResult<AdminBusinessItem>>>(
      '/admin/businesses',
      { params: { page: 1, limit: 20 } },
    )
    return (res.data.data?.items ?? []).map(mapBusiness)
  },
}
