import { useEffect } from 'react'
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
} from 'lucide-react'
import type { LiveTableOrder } from '@/services/tableOrderService'

interface TableOrderStatusModalProps {
  isOpen: boolean
  onClose: () => void
  orders: LiveTableOrder[]
  restaurantName: string
  tableNumber: string
  whatsAppNumber?: string
  isRefreshing?: boolean
  onRefresh?: () => void
  onOrderMore: () => void
}

export function TableOrderStatusModal({
  isOpen,
  onClose,
  orders,
  restaurantName,
  tableNumber,
  whatsAppNumber,
  isRefreshing,
  onRefresh,
  onOrderMore,
}: TableOrderStatusModalProps) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [isOpen])

  if (!isOpen) return null

  // Compute total items and running total across all non-cancelled rounds
  const nonCancelledOrders = orders.filter((o) => o.status !== 'CANCELLED')
  const totalItemsCount = nonCancelledOrders.reduce(
    (sum, o) => sum + (o.items || []).reduce((itemSum, i) => itemSum + (i.quantity || 1), 0),
    0,
  )
  const runningBillTotal = nonCancelledOrders.reduce((sum, o) => sum + (o.totalAmount || 0), 0)

  // Status breakdown
  const hasPending = orders.some((o) => o.status === 'PENDING')
  const hasAccepted = orders.some((o) => o.status === 'ACCEPTED')
  const hasCancelled = orders.some((o) => o.status === 'CANCELLED')
  const allCompleted = orders.length > 0 && orders.every((o) => o.status === 'COMPLETED')

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
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-blue-500/15 border border-blue-500/30 text-blue-400 text-xs font-bold">
            <CheckCircle2 size={14} className="text-blue-400" />
            <span>✅ Served</span>
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

  const handleRequestBill = () => {
    const raw = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')
    const target = raw.length === 10 ? `91${raw}` : raw
    const tbl = tableNumber ? (tableNumber.toLowerCase().startsWith('table') ? tableNumber : `Table ${tableNumber}`) : 'Dine-in'

    const lines = [
      `🧾 *FINAL BILL REQUEST — ${restaurantName}*`,
      `📍 *${tbl}*`,
      `📦 *Total Items Ordered:* ${totalItemsCount} items across ${orders.length} rounds`,
      `💰 *Estimated Total:* ₹${runningBillTotal.toLocaleString('en-IN')}`,
      '────────────────────────',
      'Please print and bring our final bill to the table. Thank you for the wonderful meal!',
    ]

    window.open(
      `https://api.whatsapp.com/send?phone=${target}&text=${encodeURIComponent(lines.join('\n'))}`,
      '_blank',
    )
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
          <div className="mt-3">
            {hasAccepted && (
              <div className="px-3 py-2 rounded-xl bg-emerald-500/10 border border-emerald-500/30 flex items-center gap-2">
                <ChefHat size={16} className="text-emerald-400 shrink-0" />
                <p className="text-xs font-semibold text-emerald-300">
                  Kitchen accepted your order! Dishes are actively being prepared.
                </p>
              </div>
            )}
            {!hasAccepted && hasPending && (
              <div className="px-3 py-2 rounded-xl bg-amber-500/10 border border-amber-500/30 flex items-center gap-2">
                <Clock size={16} className="text-amber-400 shrink-0 animate-spin" style={{ animationDuration: '6s' }} />
                <p className="text-xs font-semibold text-amber-300">
                  Order ticket received by kitchen. Waiting for owner to confirm.
                </p>
              </div>
            )}
            {!hasAccepted && !hasPending && allCompleted && (
              <div className="px-3 py-2 rounded-xl bg-blue-500/10 border border-blue-500/30 flex items-center gap-2">
                <CheckCircle2 size={16} className="text-blue-400 shrink-0" />
                <p className="text-xs font-semibold text-blue-300">
                  All items have been served to your table! Enjoy your meal.
                </p>
              </div>
            )}
            {!hasAccepted && !hasPending && hasCancelled && orders.length === 1 && (
              <div className="px-3 py-2 rounded-xl bg-rose-500/10 border border-rose-500/30 flex items-center gap-2">
                <XCircle size={16} className="text-rose-400 shrink-0" />
                <p className="text-xs font-semibold text-rose-300">
                  This order was discarded by the restaurant. You can re-order anytime.
                </p>
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

          <button
            type="button"
            onClick={handleRequestBill}
            className="w-full py-2.5 px-4 rounded-xl bg-[#23242E] hover:bg-[#2C2D3A] text-gray-300 hover:text-white font-semibold text-xs flex items-center justify-center gap-1.5 transition border border-[#2B2C38] cursor-pointer"
          >
            <Receipt size={14} className="text-emerald-400" />
            <span>Request Final Bill (Total: ₹{runningBillTotal.toLocaleString('en-IN')})</span>
          </button>
        </div>
      </div>
    </div>
  )
}
