import { createBrowserRouter, Navigate } from 'react-router-dom'

import { ViewerLayout } from '@/components/layout/ViewerLayout'
import { UnsupportedPage } from '@/pages/fallback/UnsupportedPage'
import { HomePage } from '@/pages/landing/HomePage'
import { ArViewerPage } from '@/pages/viewer/ArViewerPage'
import { MenuPage } from '@/pages/menu/MenuPage'
import { RouteErrorBoundary } from '@/components/ui/RouteErrorBoundary'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Navigate to="/home" replace />,
    errorElement: <RouteErrorBoundary />,
  },
  {
    path: '/home',
    element: (
      <ViewerLayout>
        <HomePage />
      </ViewerLayout>
    ),
    errorElement: <RouteErrorBoundary />,
  },
  {
    path: '/menu/:slug',
    element: (
      <ViewerLayout>
        <MenuPage />
      </ViewerLayout>
    ),
    errorElement: <RouteErrorBoundary />,
  },
  {
    path: '/dish/:slug',
    element: (
      <ViewerLayout>
        <ArViewerPage />
      </ViewerLayout>
    ),
    errorElement: <RouteErrorBoundary />,
  },
  {
    path: '/dish',
    element: <Navigate to="/" replace />,
  },
  {
    path: '/unsupported',
    element: (
      <ViewerLayout>
        <UnsupportedPage />
      </ViewerLayout>
    ),
    errorElement: <RouteErrorBoundary />,
  },
])
