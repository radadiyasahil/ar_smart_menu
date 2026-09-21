import axios from 'axios'

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5232/api',
  timeout: 15000,
})

export interface ApiEnvelope<T> {
  success: boolean
  data?: T
  error?: string
}
