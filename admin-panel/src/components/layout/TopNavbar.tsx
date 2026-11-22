import { LogOut, Menu, Search } from 'lucide-react'

import { NotificationDropdown } from './NotificationDropdown'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { clearAdminAuth } from '@/services/authService'

interface TopNavbarProps {
  onMenuClick: () => void
  title?: string
}

/** Top navigation bar with search, notifications, mobile logout, and quick actions. */
export function TopNavbar({ onMenuClick, title = 'Dashboard' }: TopNavbarProps) {
  const handleLogout = () => {
    if (window.confirm('Are you sure you want to log out from the Admin Panel?')) {
      clearAdminAuth()
      window.location.href = '/login'
    }
  }

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-2 sm:gap-4 border-b border-border bg-card/90 px-3 sm:px-6 backdrop-blur-md">
      {/* Mobile Hamburger Menu */}
      <Button
        variant="ghost"
        size="icon"
        className="lg:hidden h-9 w-9 text-foreground shrink-0 hover:bg-muted"
        onClick={onMenuClick}
        aria-label="Open navigation menu"
      >
        <Menu className="h-5 w-5" />
      </Button>

      {/* Page Title */}
      <div className="min-w-0 flex-1">
        <h1 className="truncate text-base sm:text-lg font-bold tracking-tight text-foreground">
          {title}
        </h1>
      </div>

      {/* Desktop Quick Search */}
      <div className="hidden max-w-sm flex-1 md:block">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search businesses, KYC, dishes..."
            className="pl-9 h-9 text-xs bg-background/60"
          />
        </div>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-1.5 sm:gap-3">
        {/* Notifications */}
        <NotificationDropdown />

        {/* Mobile Logout Button (Visible only on mobile screens < 640px) */}
        <Button
          variant="ghost"
          size="icon"
          className="sm:hidden h-9 w-9 text-muted-foreground hover:bg-danger/10 hover:text-danger transition-colors shrink-0"
          onClick={handleLogout}
          title="Sign Out"
          aria-label="Sign Out"
        >
          <LogOut className="h-4 w-4" />
        </Button>

        {/* Desktop Logout Button (Visible on screens >= 640px) */}
        <Button
          variant="ghost"
          size="sm"
          className="hidden sm:inline-flex h-9 text-xs font-semibold text-muted-foreground hover:bg-danger/10 hover:text-danger transition-colors"
          onClick={handleLogout}
          title="Sign Out of Admin"
        >
          <LogOut className="mr-1.5 h-4 w-4" />
          Logout
        </Button>

        {/* Super Admin Avatar Badge */}
        <div
          className="flex h-8 w-8 sm:h-9 sm:w-9 items-center justify-center rounded-full bg-primary text-xs sm:text-sm font-bold text-white shadow-xs shrink-0 select-none cursor-default"
          title="Super Admin Account"
        >
          A
        </div>
      </div>
    </header>
  )
}
