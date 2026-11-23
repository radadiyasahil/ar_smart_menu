import { Outlet } from 'react-router-dom'

import { LoginPage } from '@/pages/auth/LoginPage'
import { getAdminToken } from '@/services/authService'

/** Ensures admin JWT exists before rendering admin routes. If missing or expired, prompts for login. */
export function AdminAuthGate() {
  const token = getAdminToken()

  if (!token) {
    return <LoginPage />
  }

  return <Outlet />
}
