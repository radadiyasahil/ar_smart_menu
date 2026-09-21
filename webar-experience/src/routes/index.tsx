import { createBrowserRouter, Navigate } from 'react-router-dom'

import { ViewerLayout } from '@/components/layout/ViewerLayout'
import { UnsupportedPage } from '@/pages/fallback/UnsupportedPage'
import { HomePage } from '@/pages/landing/HomePage'
import { ArViewerPage } from '@/pages/viewer/ArViewerPage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: (
      <ViewerLayout>
        <HomePage />
      </ViewerLayout>
    ),
  },
  {
    path: '/dish/:slug',
    element: (
      <ViewerLayout>
        <ArViewerPage />
      </ViewerLayout>
    ),
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
  },
])
