import type {
  ActivityItem,
  DashboardStats,
  RevenueDataPoint,
} from '@/types/dashboard'
import type { BusinessRow } from '@/types/business'

/** Simulated network delay for realistic loading states. */
const delay = (ms = 600) => new Promise((resolve) => setTimeout(resolve, ms))

const mockStats: DashboardStats = {
  totalBusinesses: 1248,
  totalArViews: 892450,
  totalRevenue: 428500,
  pendingApprovals: 23,
  pendingProductReviews: 5,
  processingQueue: 15,
}

// Generate last 30 days of revenue data
const mockRevenue: RevenueDataPoint[] = Array.from({ length: 30 }, (_, i) => {
  const date = new Date()
  date.setDate(date.getDate() - (29 - i))
  const day = date.toISOString().slice(0, 10)
  const base = 8000 + Math.sin(i / 3) * 2000
  return {
    date: day,
    revenue: Math.round(base + Math.random() * 4000),
    subscriptions: Math.round(base * 0.7 + Math.random() * 1500),
    bookings: Math.round(base * 0.3 + Math.random() * 800),
  }
})

const mockActivity: ActivityItem[] = [
  {
    id: '1',
    type: 'business',
    title: 'New business registered',
    description: 'Spice Garden Restaurant joined Starter plan',
    timestamp: '2026-06-05T10:30:00',
  },
  {
    id: '2',
    type: 'kyc',
    title: 'KYC pending review',
    description: 'Urban Bites Café submitted Aadhaar documents',
    timestamp: '2026-06-05T09:15:00',
  },
  {
    id: '3',
    type: 'payment',
    title: 'Subscription payment received',
    description: '₹2,999 from Fashion Hub Store — Pro plan',
    timestamp: '2026-06-05T08:45:00',
  },
  {
    id: '4',
    type: 'processing',
    title: '3D model approved',
    description: 'Wooden Dining Table GLB passed quality check',
    timestamp: '2026-06-04T18:20:00',
  },
  {
    id: '5',
    type: 'business',
    title: 'Business suspended',
    description: 'Quick Bites Dhaba — policy violation',
    timestamp: '2026-06-04T16:00:00',
  },
]

export const mockBusinesses: BusinessRow[] = [
  {
    id: 'b1',
    businessName: 'Spice Garden',
    ownerName: 'Rajesh Kumar',
    category: 'Restaurant',
    city: 'Mumbai',
    plan: 'Starter',
    status: 'pending',
    joinedDate: '2026-06-05',
  },
  {
    id: 'b2',
    businessName: 'Urban Bites',
    ownerName: 'Priya Sharma',
    category: 'Café',
    city: 'Delhi',
    plan: 'Pro',
    status: 'active',
    joinedDate: '2026-06-04',
  },
  {
    id: 'b3',
    businessName: 'Fashion Hub',
    ownerName: 'Amit Patel',
    category: 'Clothing',
    city: 'Ahmedabad',
    plan: 'Pro',
    status: 'active',
    joinedDate: '2026-06-03',
  },
  {
    id: 'b4',
    businessName: 'WoodCraft Studio',
    ownerName: 'Suresh Reddy',
    category: 'Furniture',
    city: 'Hyderabad',
    plan: 'Enterprise',
    status: 'active',
    joinedDate: '2026-06-02',
  },
  {
    id: 'b5',
    businessName: 'Quick Bites Dhaba',
    ownerName: 'Vikram Singh',
    category: 'Restaurant',
    city: 'Jaipur',
    plan: 'Starter',
    status: 'suspended',
    joinedDate: '2026-05-28',
  },
  {
    id: 'b6',
    businessName: 'Sweet Crust Bakery',
    ownerName: 'Neha Gupta',
    category: 'Bakery',
    city: 'Pune',
    plan: 'Starter',
    status: 'pending',
    joinedDate: '2026-06-01',
  },
  {
    id: 'b7',
    businessName: 'Metro Fashion',
    ownerName: 'Karan Mehta',
    category: 'Clothing',
    city: 'Bangalore',
    plan: 'Pro',
    status: 'active',
    joinedDate: '2026-05-25',
  },
  {
    id: 'b8',
    businessName: 'Green Leaf Café',
    ownerName: 'Anita Desai',
    category: 'Café',
    city: 'Chennai',
    plan: 'Starter',
    status: 'rejected',
    joinedDate: '2026-05-20',
  },
]

/** Mock dashboard service — replace with real API calls later. */
export const dashboardService = {
  async getStats(): Promise<DashboardStats> {
    await delay()
    return mockStats
  },

  async getRevenueChart(): Promise<RevenueDataPoint[]> {
    await delay()
    return mockRevenue
  },

  async getRecentActivity(): Promise<ActivityItem[]> {
    await delay(400)
    return mockActivity
  },

  async getRecentBusinesses(): Promise<BusinessRow[]> {
    await delay(500)
    return mockBusinesses
  },
}
