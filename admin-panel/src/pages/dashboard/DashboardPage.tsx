import {
  Activity,
  Box,
  Building2,
  ClipboardCheck,
  Clock,
  Eye,
  IndianRupee,
} from 'lucide-react'
import { Link } from 'react-router-dom'

import { RevenueChart } from '@/components/charts/RevenueChart'
import { StatCard } from '@/components/charts/StatCard'
import { DataTable, StatusBadge, type Column } from '@/components/tables/DataTable'
import { Badge } from '@/components/ui/badge'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useDashboard } from '@/hooks/useDashboard'
import type { ActivityItem } from '@/types/dashboard'
import type { BusinessRow } from '@/types/business'

const activityIcons: Record<ActivityItem['type'], string> = {
  business: '🏪',
  kyc: '🛡️',
  payment: '💳',
  processing: '📦',
}

const businessColumns: Column<BusinessRow>[] = [
  {
    key: 'businessName',
    header: 'Business',
    sortable: true,
    render: (row) => (
      <div>
        <p className="font-medium text-foreground">{row.businessName}</p>
        <p className="text-xs text-muted-foreground">{row.ownerName}</p>
      </div>
    ),
  },
  {
    key: 'category',
    header: 'Category',
    sortable: true,
    render: (row) => row.category,
  },
  {
    key: 'city',
    header: 'City',
    sortable: true,
    render: (row) => row.city,
  },
  {
    key: 'plan',
    header: 'Plan',
    render: (row) => <Badge variant="default">{row.plan}</Badge>,
  },
  {
    key: 'status',
    header: 'Status',
    sortable: true,
    render: (row) => <StatusBadge status={row.status} />,
  },
  {
    key: 'joinedDate',
    header: 'Joined',
    sortable: true,
    render: (row) => row.joinedDate,
  },
  {
    key: 'actions',
    header: 'Actions',
    render: (row) =>
      row.status === 'pending' ? (
        <Link
          to="/businesses?status=pending"
          className="inline-flex h-8 items-center rounded-lg bg-primary px-3 text-xs font-medium text-primary-foreground hover:bg-primary/90"
        >
          Review
        </Link>
      ) : (
        <Link
          to="/businesses"
          className="inline-flex h-8 items-center rounded-lg px-3 text-xs font-medium hover:bg-muted"
        >
          View
        </Link>
      ),
  },
]

/** Main admin dashboard with stats, chart, activity feed, and recent businesses table. */
export function DashboardPage() {
  const { stats, revenue, activity, recentBusinesses, isLoading, error } =
    useDashboard()

  const formatCurrency = (amount: number) =>
    `₹${amount.toLocaleString('en-IN')}`

  const formatNumber = (num: number) => num.toLocaleString('en-IN')

  if (error) {
    return (
      <div className="rounded-xl border border-danger/20 bg-danger/5 p-6 text-danger">
        {error}
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Analytics stat cards */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <StatCard
          title="Total Businesses"
          value={stats ? formatNumber(stats.totalBusinesses) : '—'}
          change="+8.2%"
          changeType="positive"
          icon={Building2}
          isLoading={isLoading}
        />
        <StatCard
          title="Total AR Views"
          value={stats ? formatNumber(stats.totalArViews) : '—'}
          change="+14.5%"
          changeType="positive"
          icon={Eye}
          iconColor="bg-info/10 text-info"
          isLoading={isLoading}
        />
        <StatCard
          title="Total Revenue"
          value={stats ? formatCurrency(stats.totalRevenue) : '—'}
          change="+6.1%"
          changeType="positive"
          icon={IndianRupee}
          isLoading={isLoading}
        />
        <StatCard
          title="Pending Approvals"
          value={stats ? String(stats.pendingApprovals) : '—'}
          change="Needs action"
          changeType="neutral"
          icon={Clock}
          iconColor="bg-warning/10 text-warning"
          isLoading={isLoading}
        />
        <StatCard
          title="Processing Queue"
          value={stats ? String(stats.processingQueue) : '—'}
          change="3 failed"
          changeType="negative"
          icon={Box}
          iconColor="bg-danger/10 text-danger"
          isLoading={isLoading}
        />
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          to="/businesses?status=pending"
          className="flex items-center gap-4 rounded-xl border border-border bg-card p-4 transition-shadow hover:shadow-md"
        >
          <div className="flex h-11 w-11 items-center justify-center rounded-lg bg-warning/10 text-warning">
            <Building2 className="h-5 w-5" />
          </div>
          <div>
            <p className="font-semibold text-foreground">Approve businesses</p>
            <p className="text-sm text-muted-foreground">
              New restaurant sign-ups waiting for admin approval
            </p>
          </div>
        </Link>
        <Link
          to="/products"
          className="flex items-center gap-4 rounded-xl border border-primary/30 bg-primary/5 p-4 transition-shadow hover:shadow-md"
        >
          <div className="flex h-11 w-11 items-center justify-center rounded-lg bg-primary/10 text-primary">
            <ClipboardCheck className="h-5 w-5" />
          </div>
          <div>
            <p className="font-semibold text-foreground">Approve & publish products</p>
            <p className="text-sm text-muted-foreground">
              Owner 4-photo uploads → Approve 3D → Publish live + QR
            </p>
            {stats && stats.pendingProductReviews > 0 && (
              <p className="mt-1 text-xs font-medium text-primary">
                {stats.pendingProductReviews} pending review
              </p>
            )}
          </div>
        </Link>
      </div>

      {/* Revenue chart + activity feed */}
      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <RevenueChart data={revenue} isLoading={isLoading} />
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-4 w-4 text-primary" />
              Recent Activity
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {isLoading
              ? Array.from({ length: 5 }).map((_, i) => (
                  <div key={i} className="flex gap-3">
                    <div className="h-8 w-8 animate-pulse rounded-full bg-muted" />
                    <div className="flex-1 space-y-2">
                      <div className="h-3 w-3/4 animate-pulse rounded bg-muted" />
                      <div className="h-3 w-1/2 animate-pulse rounded bg-muted" />
                    </div>
                  </div>
                ))
              : activity.map((item) => (
                  <div key={item.id} className="flex gap-3">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm">
                      {activityIcons[item.type]}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="text-sm font-medium text-foreground">
                        {item.title}
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {item.description}
                      </p>
                      <p className="mt-0.5 text-xs text-muted-foreground">
                        {new Date(item.timestamp).toLocaleString('en-IN', {
                          dateStyle: 'medium',
                          timeStyle: 'short',
                        })}
                      </p>
                    </div>
                  </div>
                ))}
          </CardContent>
        </Card>
      </div>

      {stats && stats.pendingApprovals > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-warning/30 bg-warning/5 p-4">
          <p className="text-sm">
            <span className="font-semibold">{stats.pendingApprovals}</span> business
            {stats.pendingApprovals === 1 ? '' : 'es'} waiting for approval
          </p>
          <Link
            to="/businesses?status=pending"
            className="inline-flex h-8 items-center rounded-lg bg-primary px-3 text-xs font-medium text-primary-foreground hover:bg-primary/90"
          >
            Review pending
          </Link>
        </div>
      )}

      {stats && stats.pendingProductReviews > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-info/30 bg-info/5 p-4">
          <p className="text-sm">
            <span className="font-semibold">{stats.pendingProductReviews}</span> product
            {stats.pendingProductReviews === 1 ? '' : 's'} waiting for AR review
          </p>
          <Link
            to="/products"
            className="inline-flex h-8 items-center rounded-lg bg-primary px-3 text-xs font-medium text-primary-foreground hover:bg-primary/90"
          >
            Approve products
          </Link>
        </div>
      )}

      {/* Recent businesses table */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>Recent Businesses</CardTitle>
          <Link
            to="/businesses"
            className="inline-flex h-8 items-center rounded-lg border border-border bg-card px-3 text-xs font-medium hover:bg-muted"
          >
            Manage all
          </Link>
        </CardHeader>
        <CardContent>
          <DataTable
            data={recentBusinesses}
            columns={businessColumns}
            searchKeys={['businessName', 'ownerName', 'city', 'category']}
            searchPlaceholder="Search businesses..."
            pageSize={5}
            isLoading={isLoading}
          />
        </CardContent>
      </Card>
    </div>
  )
}
