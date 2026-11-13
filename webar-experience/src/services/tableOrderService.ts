import { apiClient, type ApiEnvelope } from './apiClient'
import type { SharedCartItem, SharedCartResponse } from '@/types/cart'

export interface LiveTableOrderItem {
  id: string
  name: string
  quantity: number
  unitPrice: number
  modifiers?: string[]
  notes?: string
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
  billRequested?: boolean
  billRequestedAt?: string | null
  createdAt: string
  acceptedAt?: string | null
  completedAt?: string | null
}

export interface PlaceTableOrderPayload {
  tableNumber: string
  round: number
  instructions?: string
  customerPhone?: string
  sessionToken?: string
  previousOrderId?: string
  previousOrderIds?: string[]
  items: {
    id: string
    name: string
    quantity: number
    unitPrice: number
    modifiers?: string[]
    notes?: string
  }[]
}

export interface RequestBillResult {
  success: boolean
  message: string
  data?: LiveTableOrder | null
}

export interface FetchTableOrdersResult {
  orders: LiveTableOrder[]
  isOccupiedByOther: boolean
  occupiedMessage?: string
  sharedCart?: SharedCartResponse | null
}

const getStorageKey = (tableNumber?: string) =>
  tableNumber && tableNumber.trim()
    ? `ar_placed_order_ids_${tableNumber.trim().toLowerCase().replace(/\s+/g, '_')}`
    : 'ar_placed_order_ids'

const getSessionTokenKey = (tableNumber?: string) =>
  tableNumber && tableNumber.trim()
    ? `ar_diner_session_token_${tableNumber.trim().toLowerCase().replace(/\s+/g, '_')}`
    : 'ar_diner_session_token'

export const tableOrderService = {
  getOrCreateSessionToken(tableNumber?: string): string {
    try {
      const key = getSessionTokenKey(tableNumber)
      let token = sessionStorage.getItem(key) || localStorage.getItem(key)
      if (!token) {
        token = 'diner_' + Math.random().toString(36).substring(2, 10) + '_' + Date.now().toString(36)
        sessionStorage.setItem(key, token)
        localStorage.setItem(key, token)
      }
      return token
    } catch {
      return 'diner_' + Date.now().toString(36)
    }
  },

  getSessionToken(tableNumber?: string): string | null {
    try {
      const key = getSessionTokenKey(tableNumber)
      return sessionStorage.getItem(key) || localStorage.getItem(key)
    } catch {
      return null
    }
  },

  clearSessionToken(tableNumber?: string) {
    try {
      if (tableNumber) {
        sessionStorage.removeItem(getSessionTokenKey(tableNumber))
        localStorage.removeItem(getSessionTokenKey(tableNumber))
      }
      sessionStorage.removeItem('ar_diner_session_token')
      localStorage.removeItem('ar_diner_session_token')
    } catch (_) {}
  },

  getStoredOrderIds(tableNumber?: string): string[] {
    try {
      const key = getStorageKey(tableNumber)
      const rawSession = sessionStorage.getItem(key)
      const rawLocal = localStorage.getItem(key)
      const sessionIds: string[] = rawSession ? JSON.parse(rawSession) : []
      const localIds: string[] = rawLocal ? JSON.parse(rawLocal) : []
      return Array.from(new Set([...sessionIds, ...localIds]))
    } catch {
      return []
    }
  },

  storeOrderId(orderId: string, tableNumber?: string) {
    try {
      const key = getStorageKey(tableNumber)
      const ids = this.getStoredOrderIds(tableNumber)
      if (!ids.includes(orderId)) {
        ids.push(orderId)
        const str = JSON.stringify(ids)
        sessionStorage.setItem(key, str)
        localStorage.setItem(key, str)
      }
      // Ensure session token is also persisted
      this.getOrCreateSessionToken(tableNumber)
    } catch (e) {
      console.warn('Could not store order id:', e)
    }
  },

  clearStoredOrderIds(tableNumber?: string) {
    try {
      if (tableNumber) {
        sessionStorage.removeItem(getStorageKey(tableNumber))
        localStorage.removeItem(getStorageKey(tableNumber))
      }
      sessionStorage.removeItem('ar_placed_order_ids')
      localStorage.removeItem('ar_placed_order_ids')
      this.clearSessionToken(tableNumber)
    } catch (_) {}
  },

  async clearCancelledOrders(slug: string, tableNumber: string): Promise<boolean> {
    try {
      const storedIds = this.getStoredOrderIds(tableNumber)
      const queryParam = storedIds.length > 0 ? `?orderIds=${encodeURIComponent(storedIds.join(','))}` : ''
      await apiClient.post(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber || 'dine-in')}/clear-cancelled${queryParam}`,
      )
      this.clearStoredOrderIds(tableNumber)
      return true
    } catch (e) {
      console.warn('Could not clear cancelled orders on server:', e)
      this.clearStoredOrderIds(tableNumber)
      return false
    }
  },

  async fetchTableOrders(slug: string, tableNumber: string): Promise<FetchTableOrdersResult> {
    if (!slug || !tableNumber) return { orders: [], isOccupiedByOther: false }
    try {
      const storedIds = this.getStoredOrderIds(tableNumber)
      const token = this.getSessionToken(tableNumber)
      const params = new URLSearchParams()
      if (storedIds.length > 0) {
        params.set('orderIds', storedIds.join(','))
      }
      if (token) {
        params.set('sessionToken', token)
      }
      const queryParam = params.toString() ? `?${params.toString()}` : ''
      const [res, sharedCart] = await Promise.all([
        apiClient.get<ApiEnvelope<LiveTableOrder[]>>(
          `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}${queryParam}`,
        ),
        this.getSharedCart(slug, tableNumber),
      ])
      if (res.data?.success && Array.isArray(res.data.data)) {
        for (const o of res.data.data) {
          if (o.id) {
            this.storeOrderId(o.id, tableNumber)
          }
        }
        return {
          orders: res.data.data,
          isOccupiedByOther: false,
          sharedCart,
        }
      }
      if (res.data?.code === 'TABLE_OCCUPIED' || res.data?.error?.includes('occupied') || res.data?.message?.includes('occupied')) {
        return {
          orders: [],
          isOccupiedByOther: true,
          occupiedMessage: res.data.message || `Table ${tableNumber} is currently occupied by another customer.`,
          sharedCart,
        }
      }
      return { orders: [], isOccupiedByOther: false, sharedCart }
    } catch (err: any) {
      if (err?.response?.data?.code === 'TABLE_OCCUPIED' || err?.response?.data?.message?.includes('occupied')) {
        return {
          orders: [],
          isOccupiedByOther: true,
          occupiedMessage: err.response.data.message || `Table ${tableNumber} is currently occupied by another customer.`,
        }
      }
      console.warn('Failed to fetch table orders:', err)
      return { orders: [], isOccupiedByOther: false }
    }
  },

  async placeOrder(slug: string, payload: PlaceTableOrderPayload): Promise<LiveTableOrder | null> {
    try {
      const token = this.getOrCreateSessionToken(payload.tableNumber)
      const storedIds = this.getStoredOrderIds(payload.tableNumber)
      const fullPayload: PlaceTableOrderPayload = {
        ...payload,
        sessionToken: payload.sessionToken || token,
        previousOrderIds: payload.previousOrderIds || (storedIds.length > 0 ? storedIds : undefined),
        previousOrderId: payload.previousOrderId || (storedIds.length > 0 ? storedIds[storedIds.length - 1] : undefined),
      }
      const res = await apiClient.post<ApiEnvelope<LiveTableOrder>>(
        `/public/orders/${encodeURIComponent(slug)}`,
        fullPayload,
      )
      if (res.data?.success && res.data.data) {
        if (res.data.data.id) {
          this.storeOrderId(res.data.data.id, payload.tableNumber)
        }
        return res.data.data
      }
      const errText = res.data?.message || res.data?.error || 'Failed to place order'
      throw new Error(errText)
    } catch (err: any) {
      const msg = err?.response?.data?.message || err?.response?.data?.error || err.message || 'Failed to place order'
      console.warn('Failed to place order:', msg)
      throw new Error(msg)
    }
  },

  async cancelOrder(orderId: string, _tableNumber?: string): Promise<{ success: boolean; message: string }> {
    try {
      const res = await apiClient.post<ApiEnvelope<any>>(`/orders/${encodeURIComponent(orderId)}/cancel`)
      if (res.data?.success) {
        return { success: true, message: res.data.message || 'Order cancelled successfully.' }
      }
      return { success: false, message: res.data?.message || res.data?.error || 'Could not cancel order.' }
    } catch (err: any) {
      const msg = err?.response?.data?.message || err?.response?.data?.error || err.message || 'Failed to cancel order.'
      return { success: false, message: msg }
    }
  },

  async callWaiter(slug: string, tableNumber: string, note?: string): Promise<boolean> {
    if (!slug || !tableNumber) return false
    try {
      const res = await apiClient.post<ApiEnvelope<any>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}/call-waiter`,
        { note: note || 'Need water or help' },
      )
      return res.data?.success ?? true
    } catch (e) {
      console.warn('Failed to call waiter:', e)
      return false
    }
  },

  async requestBill(slug: string, tableNumber: string, customerPhone?: string): Promise<RequestBillResult> {
    try {
      const res = await apiClient.post<ApiEnvelope<LiveTableOrder>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}/request-bill`,
        { tableNumber, customerPhone: customerPhone || '' },
      )
      if (res.data?.success && res.data.data) {
        return {
          success: true,
          message: res.data.message || 'Bill requested successfully. Your server has been notified.',
          data: res.data.data,
        }
      }
      return {
        success: false,
        message: res.data?.error || res.data?.message || 'Unable to request bill at this time.',
      }
    } catch (err: any) {
      console.warn('Failed to request bill:', err)
      const serverMsg =
        err?.response?.data?.error ||
        err?.response?.data?.message ||
        err?.response?.data?.title ||
        err?.message ||
        'Unable to request bill. Please try again.'
      return {
        success: false,
        message: serverMsg,
      }
    }
  },

  async notifyUpiPayment(slug: string, tableNumber: string, amount: number, upiApp: string = 'UPI'): Promise<boolean> {
    try {
      await apiClient.post(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber || 'dine-in')}/notify-upi`,
        { amount, upiApp },
      )
      return true
    } catch {
      // Graceful fallback to callWaiter notification
      return await this.callWaiter(slug, tableNumber, `💰 Paid ₹${amount} via UPI`)
    }
  },

  // --- Phase 2.4: Multiplayer Collaborative Cart Helpers ---
  getDinerClientId(): string {
    let id = sessionStorage.getItem('ar_diner_client_id')
    if (!id) {
      id = 'diner_' + Math.random().toString(36).substring(2, 10)
      sessionStorage.setItem('ar_diner_client_id', id)
    }
    return id
  },

  getDinerNickname(): string {
    return sessionStorage.getItem('ar_diner_nickname') || 'Guest'
  },

  setDinerNickname(name: string): void {
    if (name && name.trim()) {
      sessionStorage.setItem('ar_diner_nickname', name.trim())
    }
  },

  async getSharedCart(slug: string, tableNumber: string): Promise<SharedCartResponse | null> {
    if (!slug || !tableNumber) return null
    try {
      const res = await apiClient.get<ApiEnvelope<SharedCartResponse>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}/shared-cart`,
      )
      return res.data?.success && res.data.data ? res.data.data : null
    } catch (e) {
      console.warn('Could not fetch shared cart:', e)
      return null
    }
  },

  async updateSharedCart(
    slug: string,
    tableNumber: string,
    items: SharedCartItem[],
    clientId: string,
    clientName: string,
  ): Promise<SharedCartResponse | null> {
    if (!slug || !tableNumber) return null
    try {
      const res = await apiClient.post<ApiEnvelope<SharedCartResponse>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}/shared-cart`,
        { clientId, clientName, items },
      )
      return res.data?.success && res.data.data ? res.data.data : null
    } catch (e) {
      console.warn('Could not update shared cart:', e)
      return null
    }
  },

  async clearSharedCart(slug: string, tableNumber: string): Promise<boolean> {
    if (!slug || !tableNumber) return false
    try {
      const res = await apiClient.delete<ApiEnvelope<boolean>>(
        `/public/orders/${encodeURIComponent(slug)}/table/${encodeURIComponent(tableNumber)}/shared-cart`,
      )
      return !!res.data?.success
    } catch (e) {
      console.warn('Could not clear shared cart:', e)
      return false
    }
  },
}
