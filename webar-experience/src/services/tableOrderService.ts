import { apiClient, type ApiEnvelope } from './apiClient'

export interface LiveTableOrderItem {
  id: string
  name: string
  quantity: number
  unitPrice: number
}

export type OrderRoundStatus = 'PENDING' | 'ACCEPTED' | 'CANCELLED' | 'COMPLETED' | string

export interface LiveTableOrder {
  id: string
  businessId: string
  tableNumber: string
  round: number
  status: OrderRoundStatus
  instructions?: string
  customerPhone?: string
  items: LiveTableOrderItem[]
  totalAmount: number
  createdAt: string
  acceptedAt?: string | null
}

export interface PlaceTableOrderPayload {
  tableNumber: string
  round: number
  instructions?: string
  customerPhone?: string
  items: {
    id: string
    name: string
    quantity: number
    unitPrice: number
  }[]
}

const STORAGE_KEY_ORDER_IDS = 'ar_placed_order_ids'

export const tableOrderService = {
  getStoredOrderIds(): string[] {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY_ORDER_IDS)
      return raw ? JSON.parse(raw) : []
    } catch {
      return []
    }
  },

  storeOrderId(orderId: string) {
    try {
      const ids = this.getStoredOrderIds()
      if (!ids.includes(orderId)) {
        ids.push(orderId)
        sessionStorage.setItem(STORAGE_KEY_ORDER_IDS, JSON.stringify(ids))
      }
    } catch (e) {
      console.warn('Could not store order id:', e)
    }
  },

  async fetchTableOrders(slug: string, tableNumber: string): Promise<LiveTableOrder[]> {
    if (!slug || !tableNumber) return []
    try {
      const storedIds = this.getStoredOrderIds()
      const queryParam = storedIds.length > 0 ? `?orderIds=${storedIds.join(',')}` : ''
      const res = await apiClient.get<ApiEnvelope<LiveTableOrder[]>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}${queryParam}`,
      )
      if (res.data?.success && Array.isArray(res.data.data)) {
        return res.data.data
      }
      return []
    } catch (err) {
      console.warn('Failed to fetch table orders:', err)
      return []
    }
  },

  async placeOrder(slug: string, payload: PlaceTableOrderPayload): Promise<LiveTableOrder | null> {
    try {
      const res = await apiClient.post<ApiEnvelope<LiveTableOrder>>(
        `/public/orders/${encodeURIComponent(slug)}`,
        payload,
      )
      if (res.data?.success && res.data.data) {
        if (res.data.data.id) {
          this.storeOrderId(res.data.data.id)
        }
        return res.data.data
      }
      return null
    } catch (err) {
      console.warn('Failed to place order:', err)
      return null
    }
  },
}
