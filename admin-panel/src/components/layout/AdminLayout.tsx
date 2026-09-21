import { useState } from 'react'
import { Outlet, useLocation } from 'react-router-dom'

import { Sidebar } from '@/components/layout/Sidebar'
import { TopNavbar } from '@/components/layout/TopNavbar'

const pageTitles: Record<string, string> = {
  '/': 'Dashboard',
  '/businesses': 'Business Management',
  '/kyc': 'KYC Review',
  '/plans': 'Plans & Pricing',
  '/products': 'Product Review — Approve & Publish',
  '/photographers': 'Photographers',
  '/processing': '3D Processing Queue',
  '/payments': 'Payments & Revenue',
  '/integrations': 'API Integrations',
}

/** Main admin layout with sidebar + top navbar. */
export function AdminLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const location = useLocation()
  const title = pageTitles[location.pathname] ?? 'Admin Panel'

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />

      <div className="flex min-w-0 flex-1 flex-col">
        <TopNavbar
          title={title}
          onMenuClick={() => setSidebarOpen(true)}
        />

        <main className="flex-1 p-4 lg:p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
