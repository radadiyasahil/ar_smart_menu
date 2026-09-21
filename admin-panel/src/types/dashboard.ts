export interface DashboardStats {
  totalBusinesses: number
  totalArViews: number
  totalRevenue: number
  pendingApprovals: number
  pendingProductReviews: number
  processingQueue: number
}

export interface RevenueDataPoint {
  date: string
  revenue: number
  subscriptions: number
  bookings: number
}

export interface ActivityItem {
  id: string
  type: 'business' | 'kyc' | 'payment' | 'processing'
  title: string
  description: string
  timestamp: string
}
