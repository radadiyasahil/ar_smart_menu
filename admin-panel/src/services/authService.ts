import type { ApiEnvelope } from '@/types/api'

import { apiClient } from './apiClient'

const TOKEN_KEY = 'admin_token'

let loginPromise: Promise<string> | null = null

export function getAdminToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function clearAdminAuth(): void {
  localStorage.removeItem(TOKEN_KEY)
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
  return token
}

export async function ensureAdminAuth(): Promise<void> {
  if (getAdminToken()) return

  if (!loginPromise) {
    loginPromise = loginAsAdmin().finally(() => {
      loginPromise = null
    })
  }

  await loginPromise
}
