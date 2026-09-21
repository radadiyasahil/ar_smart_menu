export type BusinessStatusFilter = 'pending' | 'active' | 'suspended' | 'rejected' | 'all'

export type KycStatusFilter = 'pending' | 'submitted' | 'verified' | 'rejected'

export interface AdminBusiness {
  id: string
  businessName: string
  businessType: number
  city: string
  status: number
  ownerMobile: string
  ownerName?: string
  ownerKycStatus: number
  productCount: number
  createdAt: string
}

export interface AdminDashboardStats {
  totalBusinesses: number
  activeBusinesses: number
  pendingApprovals: number
  pendingProductReviews: number
  totalScans: number
  totalArViews: number
  totalProducts: number
}

export interface AdminProductReviewItem {
  productId: string
  productName: string
  businessId: string
  businessName: string
  productStatus: number
  photoCount: number
  processingJobId?: string | null
  jobStatus?: number | null
  updatedAt: string
}

export interface ProcessingJob {
  id: string
  bookingId: string
  productId?: string
  businessName: string
  productName?: string
  status: number
  source: number
  version: number
  retryCount: number
  failureReason?: string
  createdAt: string
}

export interface SubscriptionPlan {
  id: string
  name: string
  slug: string
  monthlyPricePaise: number
  yearlyPricePaise: number
  maxProducts: number
  includesShoot: boolean
  shootsPerYear: number
  displayOrder: number
}

export const BUSINESS_TYPE_LABELS = [
  'Restaurant',
  'Café',
  'Bakery',
  'Clothing',
  'Furniture',
] as const

export const BUSINESS_STATUS_LABELS: Record<number, string> = {
  0: 'Pending',
  1: 'Active',
  2: 'Suspended',
  3: 'Rejected',
}

export const KYC_STATUS_LABELS: Record<number, string> = {
  0: 'Pending',
  1: 'Submitted',
  2: 'Verified',
  3: 'Rejected',
}

export const PROCESSING_STATUS_LABELS: Record<number, string> = {
  0: 'Queued',
  1: 'Processing',
  2: 'Optimizing',
  3: 'Review',
  4: 'Approved',
  5: 'Rejected',
  6: 'Failed',
}

export const PRODUCT_STATUS_LABELS: Record<number, string> = {
  0: 'Draft',
  1: 'Submitted',
  2: 'Processing',
  3: 'Review',
  4: 'Live',
  5: 'Paused',
  6: 'Rejected',
}

export function businessStatusKey(status: number): string {
  switch (status) {
    case 0:
      return 'pending'
    case 1:
      return 'active'
    case 2:
      return 'suspended'
    case 3:
      return 'rejected'
    default:
      return 'pending'
  }
}

export function formatPaise(paise: number): string {
  return `₹${(paise / 100).toLocaleString('en-IN')}`
}
