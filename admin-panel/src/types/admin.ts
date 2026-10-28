export type BusinessStatusFilter = 'pending' | 'active' | 'suspended' | 'rejected' | 'deactivated' | 'all'

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
  fullAddress?: string
  fssaiNumber?: string
  gstNumber?: string
  upiId?: string
  bankAccountNumber?: string
  bankIfsc?: string
  bankPennyVerified?: boolean
  ownerWhatsApp?: string
  ownerAadhaarLast4?: string
  ownerPanNumber?: string
  rejectionReason?: string
  adminNotes?: string
  subscriptionPlanName?: string | null
  subscriptionStatus?: string | null
  subscriptionStartsAt?: string | null
  subscriptionEndsAt?: string | null
  subscriptionDaysRemaining?: number | null
  hasUsedTrial?: boolean
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

export interface AdminProductPhoto {
  id: string
  photoUrl: string
  angleType: number
  sortOrder: number
  mimeType?: string
  fileSizeBytes?: number
  createdAt: string
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
  description?: string
  pricePaise?: number
  category?: number
  vegStatus?: number
  isSpicy?: boolean
  isBestseller?: boolean
  isNew?: boolean
  photos?: AdminProductPhoto[]
  glbUrl?: string
  rejectionReason?: string
  createdAt?: string
  isHero?: boolean
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
  4: 'Deactivated',
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

export const PHOTO_ANGLE_LABELS: Record<number, string> = {
  1: 'Front (Eye Level)',
  2: 'Top (Bird Eye)',
  3: 'Left Angle (45°)',
  4: 'Right Angle (45°)',
  5: 'Other / Display',
}

export const VEG_STATUS_LABELS: Record<number, { label: string; color: string }> = {
  0: { label: 'Not Specified', color: 'gray' },
  1: { label: 'Pure Veg', color: '#16a34a' },
  2: { label: 'Non-Veg', color: '#dc2626' },
  3: { label: 'Egg', color: '#d97706' },
  4: { label: 'Vegan', color: '#059669' },
}

export const PRODUCT_CATEGORY_LABELS: Record<number, string> = {
  0: 'Starters',
  1: 'Main Course',
  2: 'Breads & Rice',
  3: 'Desserts',
  4: 'Beverages',
  5: 'Combos & Thalis',
  6: 'Snacks & Quick Bites',
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
    case 4:
      return 'deactivated'
    default:
      return 'pending'
  }
}

export function formatPaise(paise?: number | null): string {
  if (paise == null) return '—'
  return `₹${(paise / 100).toLocaleString('en-IN')}`
}
