import { LogIn } from 'lucide-react'
import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { clearAdminAuth, loginAsAdmin } from '@/services/authService'

interface LoginPageProps {
  initialError?: string
}

/** Admin dev login — uses POST /api/auth/dev-login (admin mobile). */
export function LoginPage({ initialError }: LoginPageProps) {
  const navigate = useNavigate()
  const [mobile, setMobile] = useState(
    import.meta.env.VITE_ADMIN_MOBILE ?? '9000000001',
  )
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(initialError ?? '')

  const handleLogin = async () => {
    if (mobile.length !== 10) {
      setError('Enter a valid 10-digit mobile number')
      return
    }

    setLoading(true)
    setError('')
    clearAdminAuth()

    try {
      await loginAsAdmin(mobile)
      navigate('/', { replace: true })
      window.location.reload()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Login failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <LogIn className="h-5 w-5 text-primary" />
            AR Smart Menu Admin
          </CardTitle>
          <p className="text-sm text-muted-foreground">
            Development login — no OTP. Use admin mobile{' '}
            <code className="rounded bg-muted px-1">9000000001</code>
          </p>
        </CardHeader>
        <CardContent className="space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium">Admin mobile</label>
            <Input
              value={mobile}
              onChange={(e) => setMobile(e.target.value.replace(/\D/g, '').slice(0, 10))}
              placeholder="9000000001"
              inputMode="numeric"
            />
          </div>

          {error && (
            <div className="rounded-lg border border-danger/30 bg-danger/5 p-3 text-sm text-danger">
              {error}
            </div>
          )}

          <Button className="w-full" onClick={handleLogin} disabled={loading}>
            {loading ? 'Signing in...' : 'Sign in to Admin Panel'}
          </Button>

          <p className="text-xs text-muted-foreground">
            Backend must be running at{' '}
            {import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5232/api'}
          </p>
        </CardContent>
      </Card>
    </div>
  )
}
