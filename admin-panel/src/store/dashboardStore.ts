import { create } from 'zustand'

import type {
  ActivityItem,
  DashboardStats,
  RevenueDataPoint,
} from '@/types/dashboard'
import type { BusinessRow } from '@/types/business'
import { dashboardService } from '@/services/dashboardService'

interface DashboardState {
  stats: DashboardStats | null
  revenue: RevenueDataPoint[]
  activity: ActivityItem[]
  recentBusinesses: BusinessRow[]
  isLoading: boolean
  error: string | null
  fetchDashboard: () => Promise<void>
}

export const useDashboardStore = create<DashboardState>((set) => ({
  stats: null,
  revenue: [],
  activity: [],
  recentBusinesses: [],
  isLoading: false,
  error: null,

  fetchDashboard: async () => {
    set({ isLoading: true, error: null })
    try {
      const [stats, revenue, activity, recentBusinesses] = await Promise.all([
        dashboardService.getStats(),
        dashboardService.getRevenueChart(),
        dashboardService.getRecentActivity(),
        dashboardService.getRecentBusinesses(),
      ])
      set({ stats, revenue, activity, recentBusinesses, isLoading: false })
    } catch {
      set({ isLoading: false, error: 'Failed to load dashboard data' })
    }
  },
}))
