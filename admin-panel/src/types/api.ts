export interface ApiEnvelope<T> {
  success: boolean
  data?: T
  error?: string
  message?: string
  code?: string
}

export interface PagedResult<T> {
  items: T[]
  total: number
  page: number
  limit: number
}
