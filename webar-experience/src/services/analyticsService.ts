import { productService } from './productService'
import { getDeviceInfo } from '@/utils/device'
import type { AnalyticsEvent, AnalyticsEventType } from '@/types/analytics'

const sessionId =
  typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `sess-${Date.now()}`

let activeSlug: string | null = null
let scanEventId: string | null = null
let viewStartTime: number | null = null

const interaction = {
  rotated: false,
  resized: false,
  shared: false,
  clickedOrder: false,
}

function getVisitorFingerprint(): string {
  const key = 'ar_fp'
  let fp = localStorage.getItem(key)
  if (!fp) {
    fp = `${Math.random().toString(36).slice(2)}${Date.now().toString(36)}`
    localStorage.setItem(key, fp)
  }
  return fp
}

function devicePayload() {
  const info = getDeviceInfo()
  return {
    sessionId,
    visitorFingerprint: getVisitorFingerprint(),
    deviceType: info.deviceType,
    platform: info.platform,
  }
}

async function flushViewEvent() {
  if (!activeSlug || viewStartTime == null) return
  const duration = Math.round((Date.now() - viewStartTime) / 1000)
  await productService.logView(activeSlug, {
    ...devicePayload(),
    viewDurationSeconds: duration,
    arLaunched: interaction.rotated || interaction.resized,
    scanEventId,
    rotated: interaction.rotated,
    resized: interaction.resized,
    shared: interaction.shared,
    clickedOrder: interaction.clickedOrder,
  })
}

if (typeof document !== 'undefined') {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') {
      void flushViewEvent()
    }
  })
}

export const analyticsService = {
  setSlug(slug: string) {
    activeSlug = slug
  },

  async logScan(slug: string) {
    activeSlug = slug
    scanEventId = await productService.logScan(slug, devicePayload())
    viewStartTime = Date.now()
  },

  track(type: AnalyticsEventType, productId?: string, metadata?: Record<string, string | number | boolean>) {
    const event: AnalyticsEvent = {
      type,
      productId,
      metadata,
      timestamp: new Date().toISOString(),
    }

    if (import.meta.env.DEV) {
      console.info('[Analytics]', event)
    }

    if (type === 'rotation') interaction.rotated = true
    if (type === 'scale_change') interaction.resized = true
    if (type === 'share') interaction.shared = true
    if (type === 'add_to_order') interaction.clickedOrder = true
  },

  flush() {
    void flushViewEvent()
  },
}

export { sessionId }
