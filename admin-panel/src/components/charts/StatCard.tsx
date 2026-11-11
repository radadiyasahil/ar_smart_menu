import type { LucideIcon } from 'lucide-react'

import { Card, CardContent } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { cn } from '@/utils/cn'

interface StatCardProps {
  title: string
  value: string
  change?: string
  changeType?: 'positive' | 'negative' | 'neutral'
  icon: LucideIcon
  iconColor?: string
  isLoading?: boolean
}

/** Reusable analytics stat card for dashboard metrics. */
export function StatCard({
  title,
  value,
  change,
  changeType = 'neutral',
  icon: Icon,
  iconColor = 'bg-accent text-primary',
  isLoading,
}: StatCardProps) {
  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-6">
          <Skeleton className="mb-4 h-10 w-10 rounded-lg" />
          <Skeleton className="mb-2 h-7 w-24" />
          <Skeleton className="h-4 w-32" />
        </CardContent>
      </Card>
    )
  }

  const changeColors = {
    positive: 'text-success',
    negative: 'text-danger',
    neutral: 'text-muted-foreground',
  }

  return (
    <Card className="transition-shadow hover:shadow-md">
      <CardContent className="p-6">
        <div className="flex items-start justify-between">
          <div
            className={cn(
              'flex h-10 w-10 items-center justify-center rounded-lg',
              iconColor,
            )}
          >
            <Icon className="h-5 w-5" />
          </div>
          {change && (
            <span className={cn('text-xs font-medium', changeColors[changeType])}>
              {change}
            </span>
          )}
        </div>
        <p className="mt-4 text-2xl font-bold text-foreground">{value}</p>
        <p className="mt-1 text-sm text-muted-foreground">{title}</p>
      </CardContent>
    </Card>
  )
}
