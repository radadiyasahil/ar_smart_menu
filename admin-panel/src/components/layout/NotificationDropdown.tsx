import {
  Bell,
  Building2,
  CheckCheck,
  ChevronRight,
  Sparkles,
  Smartphone,
  Utensils,
  X,
} from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'

import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useAdminNotifications } from '@/hooks/useAdminNotifications'
import type { AdminNotification } from '@/types/admin'

function formatTimeAgo(isoString: string): string {
  try {
    const diffMs = Date.now() - new Date(isoString).getTime()
    const diffSec = Math.floor(diffMs / 1000)
    if (diffSec < 60) return 'Just now'
    const diffMin = Math.floor(diffSec / 60)
    if (diffMin < 60) return `${diffMin}m ago`
    const diffHour = Math.floor(diffMin / 60)
    if (diffHour < 24) return `${diffHour}h ago`
    const diffDay = Math.floor(diffHour / 24)
    return `${diffDay}d ago`
  } catch {
    return 'Recently'
  }
}

export function NotificationDropdown() {
  const [isOpen, setIsOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<'all' | 'products' | 'businesses'>('all')
  const dropdownRef = useRef<HTMLDivElement>(null)
  const navigate = useNavigate()

  const {
    notifications,
    unreadCount,
    pendingBusinessesCount,
    pendingProductsCount,
    readIds,
    permission,
    isSupported,
    requestPermission,
    markAsRead,
    markAllAsRead,
  } = useAdminNotifications()

  // Close dropdown on click outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setIsOpen(false)
      }
    }
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [isOpen])

  const filteredNotifications = notifications.filter((item) => {
    if (activeTab === 'products') return item.type === 'product_review'
    if (activeTab === 'businesses') return item.type === 'business_approval'
    return true
  })

  const handleNotificationClick = (item: AdminNotification) => {
    markAsRead(item.id)
    setIsOpen(false)
    navigate(item.actionUrl)
  }

  return (
    <div className="relative" ref={dropdownRef}>
      {/* Trigger Bell Button */}
      <Button
        variant="ghost"
        size="icon"
        className={`relative transition-colors ${
          isOpen ? 'bg-accent text-accent-foreground' : ''
        }`}
        onClick={() => setIsOpen((prev) => !prev)}
        aria-label="Pending Review Notifications"
      >
        <Bell className="h-5 w-5" />
        {unreadCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex h-5 min-w-[20px] items-center justify-center rounded-full bg-primary px-1 text-[10px] font-bold text-white shadow-md animate-pulse">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </Button>

      {/* Floating Popover / Dropdown Drawer */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-[340px] sm:w-[420px] rounded-2xl border border-border bg-card/95 backdrop-blur-md shadow-2xl z-50 overflow-hidden animate-in fade-in-0 zoom-in-95">
          {/* Header */}
          <div className="p-3.5 border-b border-border bg-muted/40 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="font-bold text-sm tracking-tight text-foreground">
                Approval Requests
              </span>
              {unreadCount > 0 ? (
                <Badge variant="warning" className="text-[10px] font-bold px-1.5 py-0.5">
                  {unreadCount} New
                </Badge>
              ) : (
                <Badge variant="muted" className="text-[10px] font-medium px-1.5 py-0.5">
                  Up to date
                </Badge>
              )}
            </div>

            <div className="flex items-center gap-1">
              {unreadCount > 0 && (
                <Button
                  variant="ghost"
                  size="sm"
                  className="h-7 text-xs px-2 text-muted-foreground hover:text-foreground"
                  onClick={markAllAsRead}
                  title="Mark all as read"
                >
                  <CheckCheck className="h-3.5 w-3.5 mr-1" />
                  Mark all read
                </Button>
              )}
              <Button
                variant="ghost"
                size="icon"
                className="h-7 w-7 text-muted-foreground hover:text-foreground"
                onClick={() => setIsOpen(false)}
              >
                <X className="h-4 w-4" />
              </Button>
            </div>
          </div>

          {/* Phone / Mobile Push Permission Banner */}
          {isSupported && permission !== 'granted' && (
            <div className="px-3.5 py-2.5 bg-primary/10 border-b border-primary/20 flex items-center justify-between gap-2">
              <div className="flex items-center gap-2 min-w-0">
                <Smartphone className="h-4 w-4 text-primary shrink-0" />
                <p className="text-[11px] text-foreground font-medium truncate">
                  Get phone alerts when new dishes/businesses arrive
                </p>
              </div>
              <Button
                size="sm"
                className="h-7 text-xs px-2.5 bg-primary text-white shrink-0 font-semibold"
                onClick={requestPermission}
              >
                Enable
              </Button>
            </div>
          )}

          {/* Filter Tabs */}
          <div className="flex border-b border-border bg-card px-2 pt-1 gap-1">
            <button
              className={`text-xs font-semibold px-3 py-1.5 rounded-t-lg transition-colors border-b-2 ${
                activeTab === 'all'
                  ? 'border-primary text-primary bg-primary/5'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              }`}
              onClick={() => setActiveTab('all')}
            >
              All ({notifications.length})
            </button>
            <button
              className={`text-xs font-semibold px-3 py-1.5 rounded-t-lg transition-colors border-b-2 flex items-center gap-1 ${
                activeTab === 'products'
                  ? 'border-primary text-primary bg-primary/5'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              }`}
              onClick={() => setActiveTab('products')}
            >
              Dishes ({pendingProductsCount})
            </button>
            <button
              className={`text-xs font-semibold px-3 py-1.5 rounded-t-lg transition-colors border-b-2 flex items-center gap-1 ${
                activeTab === 'businesses'
                  ? 'border-primary text-primary bg-primary/5'
                  : 'border-transparent text-muted-foreground hover:text-foreground'
              }`}
              onClick={() => setActiveTab('businesses')}
            >
              Businesses ({pendingBusinessesCount})
            </button>
          </div>

          {/* Notification List */}
          <div className="max-h-[380px] overflow-y-auto divide-y divide-border/60">
            {filteredNotifications.length === 0 ? (
              <div className="py-10 px-4 text-center">
                <Sparkles className="h-8 w-8 text-muted-foreground/40 mx-auto mb-2" />
                <p className="text-sm font-semibold text-foreground">No Pending Approvals</p>
                <p className="text-xs text-muted-foreground mt-0.5">
                  All businesses and dish review requests have been handled.
                </p>
              </div>
            ) : (
              filteredNotifications.map((item) => {
                const isRead = readIds.has(item.id)
                const isProduct = item.type === 'product_review'

                return (
                  <div
                    key={item.id}
                    onClick={() => handleNotificationClick(item)}
                    className={`p-3 transition-colors cursor-pointer flex items-start gap-3 hover:bg-accent/60 ${
                      !isRead ? 'bg-primary/[0.04]' : ''
                    }`}
                  >
                    {/* Item Avatar / Icon */}
                    <div className="relative shrink-0">
                      {item.photoUrl ? (
                        <img
                          src={item.photoUrl}
                          alt={item.productName || item.businessName}
                          className="h-10 w-10 rounded-xl object-cover border border-border shadow-xs"
                          onError={(e) => {
                            ;(e.target as HTMLElement).style.display = 'none'
                          }}
                        />
                      ) : (
                        <div
                          className={`h-10 w-10 rounded-xl flex items-center justify-center ${
                            isProduct ? 'bg-orange-500/15 text-orange-500' : 'bg-blue-500/15 text-blue-500'
                          }`}
                        >
                          {isProduct ? (
                            <Utensils className="h-5 w-5" />
                          ) : (
                            <Building2 className="h-5 w-5" />
                          )}
                        </div>
                      )}
                      {!isRead && (
                        <span className="absolute -top-0.5 -right-0.5 h-2.5 w-2.5 rounded-full bg-primary ring-2 ring-card" />
                      )}
                    </div>

                    {/* Content Details */}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-1 mb-0.5">
                        <span className="font-semibold text-xs text-foreground truncate">
                          {isProduct ? item.productName || item.title : item.businessName || item.title}
                        </span>
                        <span className="text-[10px] text-muted-foreground whitespace-nowrap">
                          {formatTimeAgo(item.createdAt)}
                        </span>
                      </div>

                      <div className="flex items-center gap-1.5 mb-1 flex-wrap">
                        {/* Business Name Pill */}
                        <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md bg-secondary text-secondary-foreground text-[10px] font-semibold truncate max-w-[190px]">
                          <Building2 className="h-2.5 w-2.5 shrink-0" />
                          {item.businessName}
                        </span>

                        <Badge
                          variant={isProduct ? 'warning' : 'info'}
                          className="text-[9px] px-1 py-0 leading-tight font-medium"
                        >
                          {isProduct ? '3D AR Review' : 'Business Approval'}
                        </Badge>
                      </div>

                      <p className="text-[11px] text-muted-foreground line-clamp-1">
                        {item.message}
                      </p>
                    </div>

                    {/* Right Arrow / Review Button */}
                    <div className="self-center pl-1 text-muted-foreground">
                      <ChevronRight className="h-4 w-4" />
                    </div>
                  </div>
                )
              })
            )}
          </div>

          {/* Footer */}
          <div className="p-2 border-t border-border bg-muted/20 flex items-center justify-between text-[11px] px-3">
            <span className="text-muted-foreground font-medium">
              Click any request to review immediately
            </span>
            <Button
              variant="ghost"
              size="sm"
              className="h-auto p-0 text-xs text-primary font-bold hover:bg-transparent hover:underline"
              onClick={() => {
                setIsOpen(false)
                navigate('/products?filter=pending')
              }}
            >
              Open Queue
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
