import { useEffect, useState } from 'react'
import {
  X,
  ChefHat,
  Clock,
  CheckCircle2,
  XCircle,
  Plus,
  Receipt,
  RotateCw,
  ShoppingBag,
  Sparkles,
  BellRing,
  Trash2,
} from 'lucide-react'
import { tableOrderService, type LiveTableOrder } from '@/services/tableOrderService'

interface TableOrderStatusModalProps {
  isOpen: boolean
  onClose: () => void
  orders: LiveTableOrder[]
  restaurantName: string
  tableNumber: string
  slug?: string
  isRefreshing?: boolean
  onRefresh?: () => void
  onOrderMore: () => void
  onReorderItems?: (items: { id: string; name: string; quantity: number }[]) => void
  onBillRequested?: () => void
  onClearOrders?: () => void
}

export function TableOrderStatusModal({
  isOpen,
  onClose,
  orders,
  restaurantName,
  tableNumber,
  slug,
  isRefreshing,
  onRefresh,
  onOrderMore,
  onReorderItems,
  onBillRequested,
  onClearOrders,
}: TableOrderStatusModalProps) {
  const [isRequestingBill, setIsRequestingBill] = useState(false)
  const [billRequestSent, setBillRequestSent] = useState(false)
  const [billErrorMessage, setBillErrorMessage] = useState<string | null>(null)
  const [isRingingWaiter, setIsRingingWaiter] = useState(false)
  const [waiterRingSent, setWaiterRingSent] = useState(false)
  const [cancellingOrderId, setCancellingOrderId] = useState<string | null>(null)
  const [cancelErrorMessage, setCancelErrorMessage] = useState<string | null>(null)
  const [isClearing, setIsClearing] = useState(false)

  const handleClearOrders = async () => {
    if (isClearing) return
    setIsClearing(true)
    try {
      if (slug && tableNumber) {
        await tableOrderService.clearCancelledOrders(slug, tableNumber)
      }
      tableOrderService.clearStoredOrderIds(tableNumber)
      sessionStorage.setItem('ar_order_round', '1')
      sessionStorage.removeItem('ar_last_order_timestamp')
      sessionStorage.removeItem('ar_placed_order_ids')
      sessionStorage.removeItem('ar_declined_dismissed')

      onClearOrders?.()
      onClose()
    } catch (e) {
      console.warn('Could not clear cancelled orders:', e)
      tableOrderService.clearStoredOrderIds(tableNumber)
      sessionStorage.setItem('ar_order_round', '1')
      onClearOrders?.()
      onClose()
    } finally {
      setIsClearing(false)
    }
  }

  const handleCancelOrder = async (orderId: string, round?: number) => {
    const roundLabel = round ? `Round ${round}` : 'this order'
    if (!window.confirm(`Are you sure you want to cancel ${roundLabel}? This cannot be undone.`)) {
      return
    }
    setCancellingOrderId(orderId)
    setCancelErrorMessage(null)
    try {
      const res = await tableOrderService.cancelOrder(orderId, tableNumber)
      if (res.success) {
        if (onRefresh) {
          await onRefresh()
        }
      } else {
        setCancelErrorMessage(res.message || 'Could not cancel order. It may have already been accepted by the kitchen.')
      }
    } catch (e: any) {
      setCancelErrorMessage(e.message || 'Failed to cancel order.')
    } finally {
      setCancellingOrderId(null)
    }
  }

  // Filter active table orders (exclude already settled or paid orders)
  const activeOrders = orders.filter((o) => o.status !== 'PAID' && o.status !== 'SETTLED')

  // Categorize orders
  const nonCancelledOrders = activeOrders.filter((o) => o.status !== 'CANCELLED')
  const acceptedOrServedOrders = nonCancelledOrders.filter((o) => o.status === 'ACCEPTED' || o.status === 'COMPLETED')
  const pendingOrders = nonCancelledOrders.filter((o) => o.status === 'PENDING')

  const totalItemsCount = nonCancelledOrders.reduce(
    (sum, o) => sum + (o.items || []).reduce((itemSum, i) => itemSum + (i.quantity || 1), 0),
    0,
  )
  const runningBillTotal = nonCancelledOrders.reduce((sum, o) => sum + (o.totalAmount || 0), 0)

  // Status breakdown
  const hasOrders = activeOrders.length > 0
  const hasPending = pendingOrders.length > 0
  const hasAccepted = acceptedOrServedOrders.some((o) => o.status === 'ACCEPTED')
  const hasAcceptedOrServed = acceptedOrServedOrders.length > 0
  const allCancelled = hasOrders && activeOrders.every((o) => o.status === 'CANCELLED')
  const hasCancelledOrders = orders.some((o) => o.status === 'CANCELLED')
  const allPending = hasOrders && activeOrders.every((o) => o.status === 'PENDING')
  const allCompleted = hasAcceptedOrServed && !hasPending && acceptedOrServedOrders.every((o) => o.status === 'COMPLETED')

  const isBillAlreadyRequested = !allCancelled && (billRequestSent || acceptedOrServedOrders.some((o) => o.billRequested))

  // Can the bill actually be requested?
  // Only if:
  // 1. There is at least 1 ACCEPTED or COMPLETED order
  // 2. There are NO PENDING orders (kitchen must confirm all orders first)
  // 3. Not all orders are cancelled
  // 4. Bill is not already requested
  const canRequestBill = hasAcceptedOrServed && !hasPending && !allCancelled && !isBillAlreadyRequested

  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
      // Fast refresh every 2s while customer is actively viewing order/bill status
      const timer = setInterval(() => {
        onRefresh?.()
      }, 2000)
      return () => {
        document.body.style.overflow = ''
        clearInterval(timer)
      }
    } else {
      document.body.style.overflow = ''
    }
  }, [isOpen, onRefresh])

  // Reset bill request state if order is cancelled or table reset
  useEffect(() => {
    if (allCancelled || (hasOrders && !hasAcceptedOrServed)) {
      setBillRequestSent(false)
      setBillErrorMessage(null)
    }
  }, [allCancelled, hasAcceptedOrServed, hasOrders])

  if (!isOpen) return null

  // Sort orders chronologically or by round
  const sortedOrders = [...orders].sort((a, b) => {
    if (a.round !== b.round) return a.round - b.round
    return new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
  })

  const formatTime = (isoString?: string) => {
    if (!isoString) return ''
    try {
      const d = new Date(isoString)
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    } catch {
      return ''
    }
  }

  const getStatusBadge = (status: string) => {
    const st = (status || '').toUpperCase()
    switch (st) {
      case 'ACCEPTED':
        return (
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 text-xs font-bold animate-pulse">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping inline-block" />
            <ChefHat size={14} className="text-emerald-400" />
            <span>🍳 Preparing in Kitchen</span>
          </div>
        )
      case 'PENDING':
        return (
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-amber-500/15 border border-amber-500/30 text-amber-400 text-xs font-bold">
            <Clock size={14} className="text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
            <span>⏳ Sent to Kitchen</span>
          </div>
        )
      case 'CANCELLED':
        return (
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-rose-500/15 border border-rose-500/30 text-rose-400 text-xs font-bold">
            <XCircle size={14} className="text-rose-400" />
            <span>❌ Discarded / Unavailable</span>
          </div>
        )
      case 'COMPLETED':
        return (
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 text-xs font-bold">
            <CheckCircle2 size={14} className="text-emerald-400" />
            <span>✅ Served to Table</span>
          </div>
        )
      default:
        return (
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-gray-500/15 border border-gray-500/30 text-gray-300 text-xs font-bold">
            <span>{status}</span>
          </div>
        )
    }
  }

  const handleRequestBill = async () => {
    if (isRequestingBill || isBillAlreadyRequested) return
    if (!hasAcceptedOrServed) {
      setBillErrorMessage('Your order is still waiting for kitchen confirmation. Bill can only be requested once order is accepted.')
      return
    }
    if (hasPending) {
      setBillErrorMessage('Please wait for the kitchen to confirm all pending rounds before requesting your final bill.')
      return
    }
    if (allCancelled) {
      setBillErrorMessage('Cannot request bill because your order was declined by the restaurant.')
      return
    }

    setIsRequestingBill(true)
    setBillErrorMessage(null)
    try {
      if (slug) {
        const result = await tableOrderService.requestBill(slug, tableNumber)
        if (result.success) {
          setBillRequestSent(true)
          setBillErrorMessage(null)
          onBillRequested?.()
          onRefresh?.()
        } else {
          setBillErrorMessage(result.message)
        }
      }
    } catch (e: any) {
      console.warn('Failed to request bill:', e)
      setBillErrorMessage('Unable to request bill. Please try again or notify your server.')
    } finally {
      setIsRequestingBill(false)
    }
  }

  const handleRingWaiter = async () => {
    if (!slug) return
    setIsRingingWaiter(true)
    try {
      const ok = await tableOrderService.callWaiter(slug, tableNumber || 'Dine-in', 'Need water or help')
      if (ok) {
        setWaiterRingSent(true)
        setTimeout(() => setWaiterRingSent(false), 5000)
      }
    } finally {
      setIsRingingWaiter(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/80 backdrop-blur-md transition-all">
      <div
        className="w-full sm:max-w-lg bg-[#181920] border border-[#2B2C38] rounded-t-3xl sm:rounded-3xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-in slide-in-from-bottom duration-300"
        role="dialog"
        aria-modal="true"
      >
        {/* Header */}
        <div className="relative px-5 pt-5 pb-4 border-b border-[#262733] bg-[#1B1C25]/80">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <span className="px-2.5 py-1 rounded-lg bg-[#FF5353]/15 text-[#FF5353] border border-[#FF5353]/30 text-xs font-black uppercase tracking-wider">
                {tableNumber ? (tableNumber.toLowerCase().startsWith('table') ? tableNumber : `Table ${tableNumber}`) : 'Dine-in'}
              </span>
              <div>
                <h3 className="text-base font-black text-white flex items-center gap-1.5">
                  <span>Your Table Orders</span>
                  <Sparkles size={14} className="text-[#FF5353]" />
                </h3>
                <p className="text-[11px] text-gray-400">{restaurantName}</p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {hasCancelledOrders && (
                <button
                  type="button"
                  onClick={handleClearOrders}
                  disabled={isClearing}
                  title="Clear cancelled order to place a new order"
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-rose-500/15 hover:bg-rose-500/25 border border-rose-500/30 text-rose-300 text-xs font-bold transition cursor-pointer shadow-sm disabled:opacity-50"
                >
                  <Trash2 size={13} className="text-rose-400" />
                  <span>Clear Order</span>
                </button>
              )}
              {onRefresh && (
                <button
                  type="button"
                  onClick={onRefresh}
                  disabled={isRefreshing}
                  title="Refresh order status"
                  className="p-2 rounded-full bg-[#23242E] hover:bg-[#2C2D3A] text-gray-300 hover:text-white transition disabled:opacity-50 cursor-pointer"
                >
                  <RotateCw size={15} className={isRefreshing ? 'animate-spin text-[#FF5353]' : ''} />
                </button>
              )}
              <button
                type="button"
                onClick={onClose}
                className="p-2 rounded-full bg-[#23242E] hover:bg-[#2C2D3A] text-gray-400 hover:text-white transition cursor-pointer"
              >
                <X size={17} />
              </button>
            </div>
          </div>

          {/* Running KPI Summary Box */}
          <div className="mt-3.5 grid grid-cols-3 gap-2 p-2.5 rounded-2xl bg-[#121319] border border-[#2B2C38]">
            <div className="text-center">
              <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wider">Total Dishes</p>
              <p className="text-base font-black text-white mt-0.5">{totalItemsCount} <span className="text-xs font-normal text-gray-400">items</span></p>
            </div>
            <div className="text-center border-x border-[#262733]">
              <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wider">Rounds</p>
              <p className="text-base font-black text-[#FF5353] mt-0.5">{orders.length} <span className="text-xs font-normal text-gray-400">{orders.length === 1 ? 'round' : 'rounds'}</span></p>
            </div>
            <div className="text-center">
              <p className="text-[10px] text-gray-400 font-semibold uppercase tracking-wider">Running Bill</p>
              <p className="text-base font-black text-emerald-400 mt-0.5">₹{runningBillTotal.toLocaleString('en-IN')}</p>
            </div>
          </div>

          {/* Dynamic Kitchen Status Banner */}
          <div className="mt-3 space-y-2">
            {/* If all orders were cancelled/declined */}
            {allCancelled && (
              <div className="px-3.5 py-2.5 rounded-xl bg-rose-500/15 border border-rose-500/30 flex items-start gap-2.5">
                <XCircle size={18} className="text-rose-400 shrink-0 mt-0.5" />
                <div>
                  <p className="text-xs font-bold text-rose-300">
                    Order Declined by Restaurant
                  </p>
                  <p className="text-[11px] text-rose-300/80 mt-0.5">
                    The kitchen was unable to accept this order. No bill is generated. You may re-order from the menu anytime.
                  </p>
                </div>
              </div>
            )}

            {/* If order is waiting for kitchen confirmation */}
            {!allCancelled && allPending && (
              <div className="px-3.5 py-2.5 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-start gap-2.5">
                <Clock size={18} className="text-amber-400 shrink-0 mt-0.5 animate-spin" style={{ animationDuration: '6s' }} />
                <div>
                  <p className="text-xs font-bold text-amber-300">
                    Order Ticket Sent to Kitchen (Pending Confirmation)
                  </p>
                  <p className="text-[11px] text-amber-300/80 mt-0.5">
                    Waiting for kitchen to accept. You can cancel your order now before it is accepted.
                  </p>
                </div>
              </div>
            )}

            {/* If earlier rounds were accepted, but a new round is pending */}
            {!allCancelled && hasAcceptedOrServed && hasPending && (
              <div className="px-3.5 py-2.5 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-start gap-2.5">
                <Clock size={18} className="text-amber-400 shrink-0 mt-0.5 animate-spin" style={{ animationDuration: '6s' }} />
                <div>
                  <p className="text-xs font-bold text-amber-300">
                    Round {pendingOrders[0]?.round || 2} Pending Confirmation
                  </p>
                  <p className="text-[11px] text-amber-300/80 mt-0.5">
                    Earlier items are being prepared. You can cancel this pending round before kitchen accepts it.
                  </p>
                </div>
              </div>
            )}

            {/* Active preparation */}
            {!allCancelled && hasAccepted && !hasPending && (
              <div className="px-3.5 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center gap-2">
                <ChefHat size={16} className="text-emerald-400 shrink-0" />
                <p className="text-xs font-semibold text-emerald-300">
                  Kitchen accepted your order! Dishes are being prepared and cannot be cancelled.
                </p>
              </div>
            )}

            {/* All served */}
            {!allCancelled && allCompleted && (
              <div className="px-3.5 py-2 rounded-xl bg-emerald-500/15 border border-emerald-500/40 flex items-center gap-2">
                <CheckCircle2 size={16} className="text-emerald-400 shrink-0" />
                <p className="text-xs font-semibold text-emerald-300">
                  🎉 All dishes have been served to your table! Enjoy your meal.
                </p>
              </div>
            )}

            {/* Cancellation Error Alert */}
            {cancelErrorMessage && (
              <div className="px-3.5 py-2 rounded-xl bg-rose-500/15 border border-rose-500/30 flex items-center gap-2 text-rose-300 text-xs font-semibold">
                <XCircle size={16} className="text-rose-400 shrink-0" />
                <span>{cancelErrorMessage}</span>
              </div>
            )}

            {/* Bill Requested alert */}
            {isBillAlreadyRequested && (
              <div className="px-3.5 py-2.5 rounded-xl bg-emerald-500/15 border border-emerald-500/30 flex items-start gap-2.5">
                <Receipt size={18} className="text-emerald-400 shrink-0 mt-0.5" />
                <div>
                  <p className="text-xs font-bold text-emerald-300">
                    🧾 Final Bill Requested
                  </p>
                  <p className="text-[11px] text-emerald-300/80 mt-0.5">
                    Your server has received the notification in the restaurant app and will bring your bill to your table shortly.
                  </p>
                </div>
              </div>
            )}

            {/* Error Message if bill request was rejected */}
            {billErrorMessage && (
              <div className="px-3.5 py-2 rounded-xl bg-rose-500/15 border border-rose-500/30 flex items-center gap-2 text-rose-300 text-xs font-semibold">
                <XCircle size={16} className="text-rose-400 shrink-0" />
                <span>{billErrorMessage}</span>
              </div>
            )}
          </div>
        </div>

        {/* Orders & Rounds List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {sortedOrders.length === 0 ? (
            <div className="py-12 text-center">
              <div className="w-14 h-14 mx-auto rounded-2xl bg-[#23242E] border border-[#2B2C38] flex items-center justify-center text-gray-400 mb-3">
                <ShoppingBag size={24} />
              </div>
              <p className="text-sm font-bold text-white">No active orders found</p>
              <p className="text-xs text-gray-400 mt-1 max-w-xs mx-auto">
                Items you order for Table {tableNumber || 'Dine-in'} will show live status and preparation tracking right here.
              </p>
              <button
                type="button"
                onClick={onOrderMore}
                className="mt-4 px-5 py-2.5 rounded-full bg-[#FF5353] hover:bg-[#ff4040] text-white text-xs font-bold inline-flex items-center gap-1.5 transition cursor-pointer"
              >
                <Plus size={14} />
                <span>Explore Menu & Order</span>
              </button>
            </div>
          ) : (
            sortedOrders.map((order, idx) => {
              const roundNumber = order.round || idx + 1
              const isAccepted = order.status === 'ACCEPTED'
              const isCancelled = order.status === 'CANCELLED'
              const roundItemsCount = (order.items || []).reduce((s, i) => s + (i.quantity || 1), 0)

              return (
                <div
                  key={order.id || idx}
                  className={`rounded-2xl border p-4 transition-all ${
                    isAccepted
                      ? 'bg-[#1A1F1E] border-emerald-500/30 shadow-lg shadow-emerald-950/20'
                      : isCancelled
                      ? 'bg-[#20181A] border-rose-500/20 opacity-80'
                      : 'bg-[#1E1F27] border-[#2C2D3A]'
                  }`}
                >
                  {/* Round Header & Status */}
                  <div className="flex items-center justify-between gap-2 pb-3 border-b border-white/5">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-sm font-black text-white">
                          Round {roundNumber}
                        </span>
                        {roundNumber === 1 ? (
                          <span className="text-[10px] px-2 py-0.5 rounded-md bg-[#2B2C38] text-gray-300 font-semibold">
                            Initial Order
                          </span>
                        ) : (
                          <span className="text-[10px] px-2 py-0.5 rounded-md bg-[#FF5353]/20 text-[#FF7043] font-semibold">
                            +{roundItemsCount} Add-on items
                          </span>
                        )}
                      </div>
                      <span className="text-[10px] text-gray-400 mt-0.5 block">
                        Placed at {formatTime(order.createdAt)}
                      </span>
                    </div>

                    <div>{getStatusBadge(order.status)}</div>
                  </div>

                  {/* Items in this Round */}
                  <div className="divide-y divide-white/5 mt-2">
                    {(order.items || []).map((item, itemIdx) => (
                      <div key={item.id || itemIdx} className="py-2 flex items-center justify-between gap-3 text-xs">
                        <div className="flex items-center gap-2.5">
                          <span className="w-6 h-6 rounded-md bg-[#252632] text-white font-bold flex items-center justify-center text-[11px] shrink-0">
                            {item.quantity}×
                          </span>
                          <span className={`font-semibold ${isCancelled ? 'line-through text-gray-400' : 'text-gray-200'}`}>
                            {item.name}
                          </span>
                        </div>
                        <span className="font-bold text-gray-300 shrink-0">
                          ₹{((item.unitPrice || 0) * (item.quantity || 1)).toLocaleString('en-IN')}
                        </span>
                      </div>
                    ))}
                  </div>

                  {/* Special Cooking Note if any */}
                  {order.instructions && (
                    <div className="mt-2 p-2 rounded-lg bg-black/30 border border-white/5 text-[11px] text-amber-300/90 italic">
                      📝 <span className="font-medium">Note:</span> {order.instructions}
                    </div>
                  )}

                  {/* Round Subtotal */}
                  <div className="mt-3 pt-2 border-t border-white/5 flex items-center justify-between text-xs">
                    <span className="text-gray-400 font-medium">Round {roundNumber} Subtotal</span>
                    <span className={`font-black ${isCancelled ? 'line-through text-gray-500' : 'text-white'}`}>
                      ₹{(order.totalAmount || 0).toLocaleString('en-IN')}
                    </span>
                  </div>

                  {/* Customer Cancel Option when PENDING */}
                  {order.status === 'PENDING' && (
                    <div className="mt-2.5 pt-2 border-t border-white/5 flex items-center justify-between gap-2">
                      <span className="text-[11px] text-amber-400/90 flex items-center gap-1">
                        <Clock size={12} className="animate-spin" style={{ animationDuration: '4s' }} />
                        <span>Can cancel before kitchen accepts</span>
                      </span>
                      <button
                        type="button"
                        onClick={() => handleCancelOrder(order.id, roundNumber)}
                        disabled={cancellingOrderId === order.id}
                        className="px-2.5 py-1.5 rounded-lg bg-rose-500/15 hover:bg-rose-500/25 text-rose-300 border border-rose-500/30 text-[11px] font-bold inline-flex items-center gap-1 transition cursor-pointer disabled:opacity-50"
                      >
                        <XCircle size={12} />
                        <span>{cancellingOrderId === order.id ? 'Cancelling...' : 'Cancel Order'}</span>
                      </button>
                    </div>
                  )}

                  {/* Locked after kitchen acceptance */}
                  {order.status === 'ACCEPTED' && (
                    <div className="mt-2.5 pt-2 border-t border-white/5 flex items-center gap-1.5 text-[11px] text-emerald-400/90">
                      <CheckCircle2 size={12} className="shrink-0" />
                      <span>Order accepted by kitchen • Food is being prepared and cannot be cancelled</span>
                    </div>
                  )}

                  {/* Locked after completed / served */}
                  {order.status === 'COMPLETED' && (
                    <div className="mt-2.5 pt-2 border-t border-white/5 flex items-center gap-1.5 text-[11px] text-teal-400/90">
                      <CheckCircle2 size={12} className="shrink-0" />
                      <span>Dishes served • Cannot be cancelled</span>
                    </div>
                  )}

                  {/* Re-order items button for discarded / cancelled rounds */}
                  {isCancelled && onReorderItems && order.items && order.items.length > 0 && (
                    <div className="mt-2.5 pt-2 border-t border-white/5 flex justify-end">
                      <button
                        type="button"
                        onClick={() =>
                          onReorderItems(
                            order.items.map((i) => ({
                              id: i.id,
                              name: i.name,
                              quantity: i.quantity || 1,
                            })),
                          )
                        }
                        className="px-3 py-1.5 rounded-lg bg-rose-500/15 hover:bg-rose-500/25 text-rose-300 border border-rose-500/30 text-[11px] font-bold inline-flex items-center gap-1.5 transition cursor-pointer"
                      >
                        <RotateCw size={12} />
                        <span>Re-order Items</span>
                      </button>
                    </div>
                  )}
                </div>
              )
            })
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-4 border-t border-[#262733] bg-[#16171E] space-y-2.5">
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onOrderMore}
              className="flex-1 py-3 px-4 rounded-xl bg-gradient-to-r from-[#FF5353] to-[#FF7043] text-white font-bold text-xs sm:text-sm flex items-center justify-center gap-1.5 shadow-lg shadow-[#FF5353]/25 hover:opacity-95 transition cursor-pointer"
            >
              <Plus size={16} />
              <span>+ Order More Dishes (Round {orders.length + 1})</span>
            </button>
          </div>

          {/* Conditional Bill Button depending on validation state */}
          {allCancelled ? (
            <button
              type="button"
              disabled
              className="w-full py-2.5 px-4 rounded-xl font-semibold text-xs flex items-center justify-center gap-1.5 bg-rose-950/20 border border-rose-900/30 text-rose-400/70 cursor-not-allowed"
            >
              <XCircle size={14} className="text-rose-400" />
              <span>Order Declined (No Bill to Request)</span>
            </button>
          ) : allPending ? (
            <div className="space-y-1">
              <button
                type="button"
                disabled
                className="w-full py-2.5 px-4 rounded-xl font-semibold text-xs flex items-center justify-center gap-1.5 bg-[#1F202B] border border-[#2B2C38] text-amber-400/70 cursor-not-allowed"
              >
                <Clock size={14} className="text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
                <span>⏳ Waiting for Kitchen to Accept Order</span>
              </button>
              <p className="text-[10px] text-center text-gray-500">
                You can cancel above before kitchen accepts. Bill can be requested once accepted.
              </p>
            </div>
          ) : hasAcceptedOrServed && hasPending ? (
            <div className="space-y-1">
              <button
                type="button"
                disabled
                className="w-full py-2.5 px-4 rounded-xl font-semibold text-xs flex items-center justify-center gap-1.5 bg-[#1F202B] border border-[#2B2C38] text-amber-400/70 cursor-not-allowed"
              >
                <Clock size={14} className="text-amber-400 animate-spin" style={{ animationDuration: '4s' }} />
                <span>⏳ Waiting for Round {pendingOrders[0]?.round || 2} Confirmation</span>
              </button>
              <p className="text-[10px] text-center text-gray-500">
                You can cancel Round {pendingOrders[0]?.round || 2} above before kitchen accepts.
              </p>
            </div>
          ) : isBillAlreadyRequested ? (
            <button
              type="button"
              disabled
              className="w-full py-2.5 px-4 rounded-xl font-semibold text-xs flex items-center justify-center gap-1.5 bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 cursor-default"
            >
              <Receipt size={14} className="text-emerald-400" />
              <span>✅ Bill Requested (Server Notified)</span>
            </button>
          ) : (
            <button
              type="button"
              onClick={handleRequestBill}
              disabled={isRequestingBill || !canRequestBill}
              className="w-full py-2.5 px-4 rounded-xl font-semibold text-xs flex items-center justify-center gap-1.5 transition border cursor-pointer bg-[#23242E] hover:bg-[#2C2D3A] text-gray-200 hover:text-white border-[#2B2C38] active:scale-[0.99]"
            >
              <Receipt size={14} className="text-emerald-400" />
              <span>
                {isRequestingBill
                  ? 'Notifying restaurant...'
                  : `Request Final Bill (Total: ₹${runningBillTotal.toLocaleString('en-IN')})`}
              </span>
            </button>
          )}

          {/* Always Available in Every Status: Call Waiter / Ring Assistance */}
          <div className="pt-2 border-t border-white/5 text-center">
            <button
              type="button"
              onClick={handleRingWaiter}
              disabled={isRingingWaiter}
              className={`w-full py-2.5 px-3 rounded-xl text-xs font-bold flex items-center justify-center gap-2 transition cursor-pointer ${
                waiterRingSent
                  ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 shadow-sm'
                  : 'bg-white/5 hover:bg-white/10 text-gray-300 hover:text-white border border-white/10'
              }`}
            >
              <BellRing size={14} className={waiterRingSent ? 'text-emerald-400' : 'text-amber-400'} />
              <span>
                {waiterRingSent
                  ? '✓ Waiter Notified! Water / assistance on the way'
                  : isRingingWaiter
                  ? 'Ringing waiter...'
                  : 'Need water or help? Ring Waiter'}
              </span>
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
