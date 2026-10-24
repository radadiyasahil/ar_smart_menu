import axios from 'axios'

function resolveBaseUrl(): string {
  const envUrl = import.meta.env.VITE_API_BASE_URL
  if (typeof window !== 'undefined' && window.location?.hostname) {
    const hostname = window.location.hostname
    const isLocalhost = hostname === 'localhost' || hostname === '127.0.0.1'
    // If accessing from a mobile device or network IP, route API requests to the current host
    if (!isLocalhost && (!envUrl || envUrl.includes('localhost') || envUrl.includes('127.0.0.1'))) {
      return `http://${hostname}:5232/api`
    }
  }
  return envUrl || 'http://localhost:5232/api'
}

export const apiClient = axios.create({
  baseURL: resolveBaseUrl(),
  timeout: 15000,
})

export interface ApiEnvelope<T> {
  success: boolean
  data?: T
  error?: string
}
