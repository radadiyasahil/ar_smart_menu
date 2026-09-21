import { Bell, LogOut, Menu, Search } from 'lucide-react'

import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { clearAdminAuth } from '@/services/authService'

interface TopNavbarProps {
  onMenuClick: () => void
  title?: string
}

/** Top navigation bar with search and quick actions. */
export function TopNavbar({ onMenuClick, title = 'Dashboard' }: TopNavbarProps) {
  return (
    <header className="sticky top-0 z-30 flex h-16 items-center gap-4 border-b border-border bg-card/80 px-4 backdrop-blur-sm lg:px-6">
      <Button
        variant="ghost"
        size="icon"
        className="lg:hidden"
        onClick={onMenuClick}
        aria-label="Open menu"
      >
        <Menu className="h-5 w-5" />
      </Button>

      <div className="min-w-0 flex-1">
        <h1 className="truncate text-lg font-semibold text-foreground">
          {title}
        </h1>
      </div>

      <div className="hidden max-w-sm flex-1 md:block">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search businesses, KYC, payments..."
            className="pl-9"
          />
        </div>
      </div>

      <Button variant="ghost" size="icon" className="relative" aria-label="Notifications">
        <Bell className="h-5 w-5" />
        <span className="absolute right-2 top-2 h-2 w-2 rounded-full bg-primary" />
      </Button>

      <Button
        variant="ghost"
        size="sm"
        className="hidden sm:inline-flex"
        onClick={() => {
          clearAdminAuth()
          window.location.href = '/login'
        }}
      >
        <LogOut className="mr-2 h-4 w-4" />
        Logout
      </Button>

      <div
        className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-sm font-semibold text-white"
        title="Admin"
      >
        A
      </div>
    </header>
  )
}
