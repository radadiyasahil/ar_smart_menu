import {
  Building2,
  Box,
  ClipboardCheck,
  LayoutDashboard,
  Package,
  ShieldCheck,
} from 'lucide-react'
import { NavLink } from 'react-router-dom'

import { cn } from '@/utils/cn'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/businesses', label: 'Businesses', icon: Building2 },
  { to: '/kyc', label: 'KYC Review', icon: ShieldCheck },
  { to: '/plans', label: 'Plans', icon: Package },
  { to: '/products', label: 'Product Review', icon: ClipboardCheck },
  { to: '/processing', label: '3D Processing', icon: Box },
]

interface SidebarProps {
  isOpen: boolean
  onClose: () => void
}

/** Left sidebar navigation for the admin panel. */
export function Sidebar({ isOpen, onClose }: SidebarProps) {
  return (
    <>
      {/* Mobile overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/40 lg:hidden"
          onClick={onClose}
          aria-hidden
        />
      )}

      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex w-64 flex-col border-r border-border bg-card transition-transform duration-200 lg:static lg:translate-x-0',
          isOpen ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        {/* Brand */}
        <div className="flex h-16 items-center gap-3 border-b border-border px-6">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-primary">
            <span className="text-sm font-bold text-white">AR</span>
          </div>
          <div>
            <p className="text-sm font-bold text-foreground">AR Smart Menu</p>
            <p className="text-xs text-muted-foreground">Admin Panel</p>
          </div>
        </div>

        {/* Navigation links */}
        <nav className="flex-1 space-y-1 overflow-y-auto p-4">
          {navItems.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={onClose}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-accent text-primary'
                    : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                )
              }
            >
              <Icon className="h-4 w-4 shrink-0" />
              {label}
            </NavLink>
          ))}
        </nav>

        {/* Footer */}
        <div className="border-t border-border p-4">
          <div className="rounded-lg bg-muted p-3">
            <p className="text-xs font-medium text-foreground">Owner products</p>
            <p className="text-xs text-muted-foreground">
              Approve & publish under Product Review
            </p>
          </div>
        </div>
      </aside>
    </>
  )
}
