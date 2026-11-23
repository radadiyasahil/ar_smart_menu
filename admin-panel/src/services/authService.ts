import type { ApiEnvelope } from '@/types/api'

import { apiClient } from './apiClient'

const TOKEN_KEY = 'admin_token'
const TOKEN_SAVED_AT_KEY = 'admin_token_saved_at'
const SESSION_EXPIRY_MS = 4 * 60 * 60 * 1000 // 4 Hours

export function getAdminToken(): string | null {
  const token = localStorage.getItem(TOKEN_KEY)
  const savedAtStr = localStorage.getItem(TOKEN_SAVED_AT_KEY)
  if (!token) return null

  if (savedAtStr) {
    const age = Date.now() - parseInt(savedAtStr, 10)
    if (age > SESSION_EXPIRY_MS) {
      clearAdminAuth()
      return null
    }
  }
  return token
}

export function clearAdminAuth(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(TOKEN_SAVED_AT_KEY)
}

/** Dev login — mobile only, no OTP (matches Flutter + backend Development). */
export async function loginAsAdmin(mobile?: string): Promise<string> {
  const adminMobile = mobile ?? import.meta.env.VITE_ADMIN_MOBILE ?? '9000000001'

  const res = await apiClient.post<ApiEnvelope<{ token: string }>>('/auth/dev-login', {
    mobile: adminMobile,
  })

  const token = res.data.data?.token
  if (!res.data.success || !token) {
    throw new Error(res.data.error ?? 'Admin login failed')
  }

  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(TOKEN_SAVED_AT_KEY, Date.now().toString())
  return token
}

export async function ensureAdminAuth(): Promise<void> {
  const token = getAdminToken()
  if (!token) {
    if (window.location.pathname !== '/login') {
      window.location.href = '/login'
    }
    throw new Error('Not authenticated. Please log in.')
  }
}
