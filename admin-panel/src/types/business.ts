export type BusinessStatus = 'active' | 'pending' | 'suspended' | 'rejected'

export interface BusinessRow {
  id: string
  businessName: string
  ownerName: string
  category: string
  city: string
  plan: string
  status: BusinessStatus
  joinedDate: string
}
