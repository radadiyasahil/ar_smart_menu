export type AnalyticsEventType =
  | 'ar_open'
  | 'model_load'
  | 'model_interaction'
  | 'rotation'
  | 'scale_change'
  | 'product_switch'
  | 'add_to_order'
  | 'share'
  | 'camera_denied'
  | 'ar_failed'

export interface AnalyticsEvent {
  type: AnalyticsEventType
  productId?: string
  metadata?: Record<string, string | number | boolean>
  timestamp: string
}
