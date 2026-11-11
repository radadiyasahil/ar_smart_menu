import { useCallback, useEffect, useRef, useState } from 'react'

import { adminService } from '@/services/adminService'
import type { AdminNotification, AdminNotificationsResponse } from '@/types/admin'
import { playNotificationChime } from '@/utils/audioChime'

const READ_IDS_KEY = 'admin_read_notification_ids'
const SEEN_IDS_KEY = 'admin_seen_notification_ids'

function getStoredIds(key: string): Set<string> {
  try {
    const raw = localStorage.getItem(key)
    return raw ? new Set(JSON.parse(raw)) : new Set()
  } catch {
    return new Set()
  }
}

function saveStoredIds(key: string, ids: Set<string>): void {
  try {
    localStorage.setItem(key, JSON.stringify(Array.from(ids)))
  } catch {
    // Ignore storage errors
  }
}

export function useAdminNotifications() {
  const [data, setData] = useState<AdminNotificationsResponse>({
    notifications: [],
    totalPendingCount: 0,
    pendingBusinessesCount: 0,
    pendingProductsCount: 0,
  })
  const [readIds, setReadIds] = useState<Set<string>>(() => getStoredIds(READ_IDS_KEY))
  const [permission, setPermission] = useState<NotificationPermission>(() => {
    if (typeof window !== 'undefined' && 'Notification' in window) {
      return Notification.permission
    }
    return 'default'
  })

  const prevSeenIdsRef = useRef<Set<string>>(getStoredIds(SEEN_IDS_KEY))
  const isInitialLoadRef = useRef(true)

  // Register service worker for reliable mobile push/click routing
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker
        .register('/sw.js')
        .catch((err) => console.log('[SW registration failed, using direct fallback]', err))
    }
  }, [])

  const sendPhoneNotification = useCallback((item: AdminNotification) => {
    if (typeof window === 'undefined' || !('Notification' in window)) return
    if (Notification.permission !== 'granted') return

    const title =
      item.type === 'product_review'
        ? `🍽️ Review Dish: ${item.productName || item.title}`
        : `🏢 Business Approval: ${item.businessName || item.title}`

    const body = `${item.message} Tap to open & review.`

    // Try service worker notification first (better on mobile devices)
    if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
      navigator.serviceWorker.ready
        .then((reg) => {
          reg.showNotification(title, {
            body,
            icon: item.photoUrl || '/favicon.svg',
            badge: '/favicon.svg',
            tag: item.id,
            data: { url: item.actionUrl },
            vibrate: [200, 100, 200],
          } as NotificationOptions)
        })
        .catch(() => {
          fallbackNativeNotification(title, body, item)
        })
    } else {
      fallbackNativeNotification(title, body, item)
    }
  }, [])

  const fallbackNativeNotification = (title: string, body: string, item: AdminNotification) => {
    try {
      const n = new Notification(title, {
        body,
        icon: item.photoUrl || '/favicon.svg',
        tag: item.id,
        data: { url: item.actionUrl },
      })
      n.onclick = (e) => {
        e.preventDefault()
        window.focus()
        window.location.href = item.actionUrl
      }
    } catch {
      // Ignored if notifications blocked
    }
  }

  const poll = useCallback(async () => {
    try {
      const res = await adminService.getNotifications()
      setData(res)

      // Detect brand new notifications that haven't been seen in this browser yet
      const currentIds = new Set(res.notifications.map((n) => n.id))
      const newItems = res.notifications.filter((n) => !prevSeenIdsRef.current.has(n.id))

      if (!isInitialLoadRef.current && newItems.length > 0) {
        // Play audio chime
        playNotificationChime()

        // Fire phone/device notification for each new item
        newItems.forEach((item) => {
          sendPhoneNotification(item)
        })
      }

      // Update seen IDs
      isInitialLoadRef.current = false
      prevSeenIdsRef.current = currentIds
      saveStoredIds(SEEN_IDS_KEY, currentIds)
    } catch {
      // Silent catch on poll failure
    }
  }, [sendPhoneNotification])

  useEffect(() => {
    void poll()
    const timer = setInterval(() => {
      void poll()
    }, 12000) // Poll every 12 seconds
    return () => clearInterval(timer)
  }, [poll])

  const requestPermission = useCallback(async () => {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      alert('Push notifications are not supported on this browser.')
      return
    }

    try {
      const result = await Notification.requestPermission()
      setPermission(result)
      if (result === 'granted') {
        playNotificationChime()
        if (data.notifications.length > 0) {
          sendPhoneNotification(data.notifications[0])
        }
      }
    } catch (e) {
      console.error('Failed to request notification permission:', e)
    }
  }, [data.notifications, sendPhoneNotification])

  const markAsRead = useCallback((id: string) => {
    setReadIds((prev) => {
      const next = new Set(prev)
      next.add(id)
      saveStoredIds(READ_IDS_KEY, next)
      return next
    })
  }, [])

  const markAllAsRead = useCallback(() => {
    setReadIds((prev) => {
      const next = new Set(prev)
      data.notifications.forEach((n) => next.add(n.id))
      saveStoredIds(READ_IDS_KEY, next)
      return next
    })
  }, [data.notifications])

  const unreadCount = data.notifications.filter((n) => !readIds.has(n.id)).length

  return {
    notifications: data.notifications,
    unreadCount,
    totalPendingCount: data.totalPendingCount,
    pendingBusinessesCount: data.pendingBusinessesCount,
    pendingProductsCount: data.pendingProductsCount,
    readIds,
    permission,
    isSupported: typeof window !== 'undefined' && 'Notification' in window,
    requestPermission,
    markAsRead,
    markAllAsRead,
    refresh: poll,
  }
}
