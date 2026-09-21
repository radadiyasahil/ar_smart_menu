import { CreditCard } from 'lucide-react'
import { useEffect, useState } from 'react'

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { adminService } from '@/services/adminService'
import { formatPaise, type SubscriptionPlan } from '@/types/admin'

export function PlansPage() {
  const [plans, setPlans] = useState<SubscriptionPlan[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    adminService
      .listPlans()
      .then(setPlans)
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false))
  }, [])

  if (loading) {
    return (
      <div className="grid gap-4 md:grid-cols-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton key={i} className="h-48 w-full" />
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <div className="rounded-lg border border-danger/30 bg-danger/5 p-4 text-danger">{error}</div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="flex items-center gap-2 text-xl font-semibold">
          <CreditCard className="h-5 w-5 text-primary" />
          Subscription plans
        </h2>
        <p className="text-sm text-muted-foreground">Plans from SQL Server (seeded on API startup)</p>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        {plans.map((plan) => (
          <Card key={plan.id}>
            <CardHeader>
              <CardTitle>{plan.name}</CardTitle>
              <p className="text-sm text-muted-foreground">{plan.slug}</p>
            </CardHeader>
            <CardContent className="space-y-2 text-sm">
              <p>
                <span className="font-semibold">{formatPaise(plan.monthlyPricePaise)}</span>
                /month
              </p>
              <p>
                <span className="font-semibold">{formatPaise(plan.yearlyPricePaise)}</span>
                /year
              </p>
              <p>Up to {plan.maxProducts} products</p>
              <p>{plan.includesShoot ? `${plan.shootsPerYear} shoots/year` : 'No shoots included'}</p>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
