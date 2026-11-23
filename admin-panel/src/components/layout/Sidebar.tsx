import {
  Box,
  Building2,
  ClipboardCheck,
  CreditCard,
  LayoutDashboard,
  LogOut,
  Package,
  ShieldCheck,
  X,
} from 'lucide-react'
import { NavLink } from 'react-router-dom'

import { Button } from '@/components/ui/button'
import { clearAdminAuth } from '@/services/authService'
import { cn } from '@/utils/cn'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/businesses', label: 'Businesses', icon: Building2 },
  { to: '/kyc', label: 'KYC Review', icon: ShieldCheck },
  { to: '/plans', label: 'Plans & Pricing', icon: Package },
  { to: '/transactions', label: 'Invoices & Billing', icon: CreditCard },
  { to: '/products', label: 'Product Review', icon: ClipboardCheck },
  { to: '/processing', label: '3D Processing', icon: Box },
]

interface SidebarProps {
  isOpen: boolean
  onClose: () => void
}

/** Left sidebar navigation for the admin panel with mobile drawer support & footer logout. */
export function Sidebar({ isOpen, onClose }: SidebarProps) {
  const handleLogout = () => {
    if (window.confirm('Are you sure you want to log out from the Admin Panel?')) {
      clearAdminAuth()
      window.location.href = '/login'
    }
  }

  return (
    <>
      {/* Mobile Backdrop Overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 backdrop-blur-xs transition-opacity lg:hidden"
          onClick={onClose}
          aria-hidden="true"
        />
      )}

      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-50 flex w-72 flex-col border-r border-border bg-card shadow-xl transition-transform duration-200 ease-in-out lg:static lg:w-64 lg:translate-x-0 lg:shadow-none',
          isOpen ? 'translate-x-0' : '-translate-x-full',
        )}
      >
        {/* Brand Header */}
        <div className="flex h-16 items-center justify-between border-b border-border px-5">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-primary text-white shadow-xs font-bold text-sm tracking-wider">
              AR
            </div>
            <div>
              <p className="text-sm font-bold tracking-tight text-foreground flex items-center gap-1.5">
                AR Smart Menu
                <span className="rounded-md bg-primary/10 px-1.5 py-0.2 text-[10px] font-bold text-primary uppercase">
                  Admin
                </span>
              </p>
              <p className="text-[11px] text-muted-foreground font-medium">Platform Management</p>
            </div>
          </div>

          {/* Close button for mobile drawer */}
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-muted-foreground hover:text-foreground lg:hidden"
            onClick={onClose}
            aria-label="Close navigation"
          >
            <X className="h-5 w-5" />
          </Button>
        </div>

        {/* Navigation links */}
        <nav className="flex-1 space-y-1.5 overflow-y-auto p-3.5">
          <p className="px-3 pb-1 text-[11px] font-bold uppercase tracking-wider text-muted-foreground/70">
            Main Navigation
          </p>
          {navItems.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={onClose}
              className={({ isActive }) =>
                cn(
                  'group flex items-center gap-3 rounded-lg px-3.5 py-2.5 text-sm font-medium transition-all duration-150',
                  isActive
                    ? 'bg-primary text-white shadow-xs font-semibold'
                    : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                )
              }
            >
              <Icon className="h-4 w-4 shrink-0 transition-transform group-hover:scale-105" />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>

        {/* Sidebar Footer with Admin Identity & Prominent Logout */}
        <div className="border-t border-border p-3.5 space-y-3 bg-muted/20">
          {/* Admin User Card */}
          <div className="flex items-center gap-3 rounded-xl border border-border/60 bg-card p-2.5 shadow-2xs">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-primary/15 text-xs font-bold text-primary shrink-0">
              A
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-bold text-foreground">Super Administrator</p>
              <p className="truncate text-[11px] text-muted-foreground font-mono">admin@arsmartmenu.com</p>
            </div>
          </div>

          {/* Logout Button (Always visible on mobile & desktop in sidebar) */}
          <Button
            variant="ghost"
            size="sm"
            onClick={handleLogout}
            className="w-full justify-start text-xs font-semibold text-muted-foreground hover:bg-danger/10 hover:text-danger border border-transparent hover:border-danger/20 transition-colors"
          >
            <LogOut className="mr-2 h-4 w-4 shrink-0" />
            Sign Out of Admin
          </Button>
        </div>
      </aside>
    </>
  )
}
