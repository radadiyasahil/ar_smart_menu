import { createBrowserRouter } from 'react-router-dom'

import { AdminAuthGate } from '@/components/auth/AdminAuthGate'
import { AdminLayout } from '@/components/layout/AdminLayout'
import { BusinessDetailPage } from '@/pages/businesses/BusinessDetailPage'
import { BusinessesPage } from '@/pages/businesses/BusinessesPage'
import { DashboardPage } from '@/pages/dashboard/DashboardPage'
import { KycReviewPage } from '@/pages/kyc/KycReviewPage'
import { PlansPage } from '@/pages/plans/PlansPage'
import { SubscriptionHistoryPage } from '@/pages/subscriptions/SubscriptionHistoryPage'
import { ProductsPage } from '@/pages/products/ProductsPage'
import { ProcessingPage } from '@/pages/processing/ProcessingPage'
import { LoginPage } from '@/pages/auth/LoginPage'

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    path: '/',
    element: <AdminAuthGate />,
    children: [
      {
        element: <AdminLayout />,
        children: [
          { index: true, element: <DashboardPage /> },
          { path: 'businesses', element: <BusinessesPage /> },
          { path: 'businesses/:id', element: <BusinessDetailPage /> },
          { path: 'kyc', element: <KycReviewPage /> },
          { path: 'plans', element: <PlansPage /> },
          { path: 'transactions', element: <SubscriptionHistoryPage /> },
          { path: 'subscriptions', element: <SubscriptionHistoryPage /> },
          { path: 'products', element: <ProductsPage /> },
          { path: 'processing', element: <ProcessingPage /> },
        ],
      },
    ],
  },
])
