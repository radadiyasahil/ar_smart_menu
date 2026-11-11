import { createBrowserRouter, Navigate } from 'react-router-dom'

import { ViewerLayout } from '@/components/layout/ViewerLayout'
import { UnsupportedPage } from '@/pages/fallback/UnsupportedPage'
import { HomePage } from '@/pages/landing/HomePage'
import { ArViewerPage } from '@/pages/viewer/ArViewerPage'
import { MenuPage } from '@/pages/menu/MenuPage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Navigate to="/home" replace />,
  },
  {
    path: '/home',
    element: (
      <ViewerLayout>
        <HomePage />
      </ViewerLayout>
    ),
  },
  {
    path: '/menu/:slug',
    element: (
      <ViewerLayout>
        <MenuPage />
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
