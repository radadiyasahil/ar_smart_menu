import { useEffect } from 'react'

import { useDashboardStore } from '@/store/dashboardStore'

/** Hook to load dashboard data on mount. */
export function useDashboard() {
  const { fetchDashboard, ...state } = useDashboardStore()

  useEffect(() => {
    void fetchDashboard()
  }, [fetchDashboard])

  return state
}
