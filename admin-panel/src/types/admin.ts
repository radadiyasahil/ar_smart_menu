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
  customDishLimit?: number | null
  effectiveDishLimit?: number
  arViewEnabled?: boolean
  arPerViewChargePaise?: number
  arViewCredits?: number
  arViewsUsed?: number
  liveProductCount?: number
  arProductCount?: number
  totalOrdersCount?: number
  completedOrdersCount?: number
  completedSalesPaise?: number
  totalScans?: number
  totalViews?: number
  averageRating?: number | null
  totalReviews?: number
}

export interface AdminOperationsSummary {
  totalRestaurants: number
  totalDishesListed: number
  totalLiveDishes: number
  totalArDishes: number
  totalOrdersPlaced: number
  totalOrdersCompleted: number
  totalCompletedSalesPaise: number
  totalScans: number
  totalViews: number
  averageRating?: number | null
  totalReviews?: number
}

export interface AdminUpdateBusinessPayload {
  businessName?: string
  businessType?: number
  city?: string
  fullAddress?: string
  fssaiNumber?: string
  gstNumber?: string
  upiId?: string
  bankAccountNumber?: string
  bankIfsc?: string
  adminNotes?: string
  ownerFullName?: string
  ownerWhatsApp?: string
  ownerKycStatus?: number
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
  apiIntegration?: boolean
  analyticsExport?: boolean
  whatsappSupport?: boolean
  displayOrder: number
  description?: string
  durationDays: number
  basePricePaise: number
  gstPaise: number
  totalPricePaise: number
  originalPricePaise?: number | null
  discountPercent: number
  badge?: string | null
  facilities?: string[] | string | null
  isActive: boolean
  subscriberCount?: number
  gstRatePercent?: number
}

export interface GstRateSetting {
  gstRatePercent: number
  cgstRatePercent: number
  sgstRatePercent: number
  igstRatePercent: number
  lastUpdated?: string | null
  description?: string | null
}

export interface CreateSubscriptionPlanPayload {
  name: string
  slug: string
  basePricePaise: number
  originalPricePaise?: number | null
  discountPercent?: number
  durationDays?: number
  maxProducts?: number
  description?: string
  badge?: string
  facilities?: string[]
  includesShoot?: boolean
  shootsPerYear?: number
  apiIntegration?: boolean
  analyticsExport?: boolean
  whatsappSupport?: boolean
  displayOrder?: number
  isActive?: boolean
}

export interface UpdateSubscriptionPlanPayload {
  name: string
  basePricePaise: number
  originalPricePaise?: number | null
  discountPercent?: number
  durationDays?: number
  maxProducts?: number
  description?: string
  badge?: string
  facilities?: string[]
  includesShoot?: boolean
  shootsPerYear?: number
  apiIntegration?: boolean
  analyticsExport?: boolean
  whatsappSupport?: boolean
  displayOrder?: number
  isActive?: boolean
  slug?: string
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

export interface AdminNotification {
  id: string
  title: string
  message: string
  type: 'business_approval' | 'product_review'
  businessId: string
  businessName: string
  productId?: string | null
  productName?: string | null
  photoUrl?: string | null
  createdAt: string
  actionUrl: string
}

export interface AdminNotificationsResponse {
  notifications: AdminNotification[]
  totalPendingCount: number
  pendingBusinessesCount: number
  pendingProductsCount: number
}

export interface SubscriptionHistoryItem {
  id: string
  businessId: string
  businessName?: string
  ownerName?: string
  ownerMobile?: string
  planId?: string | null
  planName: string
  planSlug?: string
  durationDays?: number
  basePricePaise?: number
  gstPaise?: number
  totalPricePaise?: number
  baseAmountPaise?: number | null
  totalAmountPaise?: number | null
  basePriceRupees: number
  gstRupees: number
  totalPriceRupees: number
  paymentMethod?: string | null
  transactionRef?: string | null
  paymentRef?: string | null
  paymentStatus?: string
  invoiceNumber?: string | null
  invoiceDate?: string | null
  hasInvoice?: boolean
  status: any
  billingCycle?: string
  startsAt: string
  endsAt: string
  createdAt?: string
  cancelledAt?: string | null
  isActive?: boolean
  customerGstNumber?: string | null
  customerAddress?: string | null
  customerCity?: string | null
}

export interface SubscriptionInvoice {
  subscriptionId: string
  invoiceNumber: string
  invoiceDate: string
  placeOfSupply: string
  sacCode: string
  serviceDescription?: string
  supplierLegalName: string
  supplierTradeName?: string
  supplierGstin: string
  supplierPan: string
  supplierAddress: string
  supplierCity?: string
  supplierState: string
  supplierStateCode?: string
  supplierEmail: string
  supplierPhone?: string
  businessId: string
  recipientBusinessName: string
  recipientOwnerName?: string
  recipientMobile?: string
  recipientAddress: string
  recipientCity?: string
  recipientState: string
  recipientStateCode?: string
  recipientGstin?: string | null
  planName: string
  planSlug?: string
  durationDays?: number
  startsAt: string
  endsAt: string
  baseAmountPaise: number
  gstPaise: number
  totalAmountPaise: number
  baseAmountRupees: number
  gstRupees: number
  totalAmountRupees: number
  cgstRate: number
  cgstRupees: number
  sgstRate: number
  sgstRupees: number
  igstRate: number
  igstRupees: number
  amountInWords: string
  paymentMethod: string
  transactionRef?: string | null
  paymentStatus: string
  paidAt: string
  isReverseCharge: boolean
  termsAndConditions?: string
}

export interface SupportContactSetting {
  whatsAppNumber: string
  email: string
  phoneNumber?: string
  helpMessage?: string
  lastUpdated?: string
}

export interface UpdateSupportContactPayload {
  whatsAppNumber: string
  email: string
  phoneNumber?: string
  helpMessage?: string
}


