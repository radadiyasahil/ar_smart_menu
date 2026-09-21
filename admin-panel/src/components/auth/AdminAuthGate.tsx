import { useEffect, useState } from 'react'
import { Outlet } from 'react-router-dom'

import { LoginPage } from '@/pages/auth/LoginPage'
import { ensureAdminAuth, getAdminToken } from '@/services/authService'

/** Ensures admin JWT before rendering admin routes. */
export function AdminAuthGate() {
  const [ready, setReady] = useState(!!getAdminToken())
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (getAdminToken()) {
      setReady(true)
      return
    }

    ensureAdminAuth()
      .then(() => setReady(true))
      .catch((e: Error) => setError(e.message))
  }, [])

  if (error) {
    return <LoginPage initialError={error} />
  }

  if (!ready) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <p className="text-muted-foreground">Connecting to admin API...</p>
      </div>
    )
  }

  return <Outlet />
}
