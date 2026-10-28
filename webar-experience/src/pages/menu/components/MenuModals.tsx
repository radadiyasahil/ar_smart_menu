import { useState } from 'react'
import {
  X,
  Trash2,
  Plus,
  Minus,
  MessageCircle,
  BellRing,
  Edit3,
  MapPin,
  Clock,
  Wifi,
  Phone,
  Copy,
  Check,
  ExternalLink,
  ChefHat,
} from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'
import type { CartItem } from '@/types/cart'
import { tableOrderService, type LiveTableOrder } from '@/services/tableOrderService'

function ModalShell({

  isOpen,

  onClose,

  title,

  subtitle,

  children,

}: {

  isOpen: boolean

  onClose: () => void

  title: string

  subtitle?: string

  children: React.ReactNode

}) {

  if (!isOpen) return null

  return (

    <div

      className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"

      onClick={(e) => e.target === e.currentTarget && onClose()}

    >

      <div className="w-full max-w-md bg-[#18181B] border border-[#27272A] rounded-2xl shadow-2xl overflow-hidden">

        <div className="flex items-center justify-between p-4 border-b border-[#27272A]">

          <div>

            <h3 className="text-base font-bold text-white">{title}</h3>

            {subtitle && <p className="text-xs text-gray-400">{subtitle}</p>}

          </div>

          <button

            type="button"

            onClick={onClose}

            className="w-8 h-8 rounded-full bg-[#27272A] text-gray-400 hover:text-white flex items-center justify-center cursor-pointer"

          >

            <X size={16} />

          </button>

        </div>

        <div className="p-4">{children}</div>

      </div>

    </div>

  )

}



function BottomSheetShell({

  isOpen,

  onClose,

  title,

  action,

  children,

  footer,

}: {

  isOpen: boolean

  onClose: () => void

  title: React.ReactNode

  action?: React.ReactNode

  children: React.ReactNode

  footer?: React.ReactNode

}) {

  if (!isOpen) return null

  return (

    <div

      className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4"

      onClick={(e) => e.target === e.currentTarget && onClose()}

    >

      <div className="w-full max-w-lg bg-[#18181B] border-t sm:border border-[#27272A] rounded-t-2xl sm:rounded-2xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">

        <div className="flex items-center justify-between p-4 border-b border-[#27272A]">

          <div className="flex items-center gap-2">{title}</div>

          <div className="flex items-center gap-2">

            {action}

            <button

              type="button"

              onClick={onClose}

              className="w-8 h-8 rounded-full bg-[#27272A] text-gray-400 hover:text-white flex items-center justify-center cursor-pointer"

            >

              <X size={16} />

            </button>

          </div>

        </div>

        <div className="flex-1 overflow-y-auto p-4 space-y-4">{children}</div>

        {footer && <div className="p-4 bg-[#1F1F23] border-t border-[#2E2E34]">{footer}</div>}

      </div>

    </div>

  )

}



export function RestaurantInfoModal({

  isOpen,

  businessName,

  city,

  address,

  whatsAppNumber,

  onClose,

}: {

  isOpen: boolean

  businessName: string

  city: string

  address?: string

  whatsAppNumber?: string

  onClose: () => void

}) {

  const [copied, setCopied] = useState(false)

  const phone = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')

  const intlPhone = phone.length === 10 ? `91${phone}` : phone

  const wifiPass = 'welcome@horeca'



  const copyWifi = () => {

    navigator.clipboard.writeText(wifiPass)

    setCopied(true)

    setTimeout(() => setCopied(false), 2000)

  }



  return (

    <ModalShell isOpen={isOpen} onClose={onClose} title="Restaurant Details" subtitle={businessName}>

      <div className="space-y-3">

        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex gap-3">

          <div className="p-2 bg-[#EB4F16]/15 text-[#FF6A3D] rounded-lg h-fit"><MapPin size={16} /></div>

          <div>

            <span className="text-[11px] font-semibold text-gray-400 uppercase">Address</span>

            <p className="text-sm text-white mt-0.5">{address || `${city}, India`}</p>

            <a

              href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${businessName}, ${address || city}`)}`}

              target="_blank"

              rel="noreferrer"

              className="inline-flex items-center gap-1 text-xs text-[#FF6A3D] font-semibold mt-1"

            >

              <span>Open in Maps</span>

              <ExternalLink size={11} />

            </a>

          </div>

        </div>



        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center gap-3">

          <div className="p-2 bg-[#20BF6B]/15 text-[#20BF6B] rounded-lg"><Clock size={16} /></div>

          <div>

            <span className="text-[11px] font-semibold text-gray-400 uppercase">Hours</span>

            <p className="text-sm font-semibold text-white mt-0.5">🟢 Open: 11:00 AM – 11:30 PM</p>

          </div>

        </div>



        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center justify-between">

          <div className="flex items-center gap-3">

            <div className="p-2 bg-blue-500/15 text-blue-400 rounded-lg"><Wifi size={16} /></div>

            <div>

              <span className="text-[11px] font-semibold text-gray-400 uppercase">Guest Wi-Fi</span>

              <p className="text-xs font-semibold text-white mt-0.5">Pass: <code className="bg-[#27272A] px-1.5 py-0.5 rounded text-gray-200">{wifiPass}</code></p>

            </div>

          </div>

          <button

            type="button"

            onClick={copyWifi}

            className={`px-3 py-1.5 rounded-full text-xs font-semibold cursor-pointer flex items-center gap-1 transition ${

              copied ? 'bg-[#20BF6B] text-white' : 'bg-[#27272A] text-gray-200 hover:text-white'

            }`}

          >

            {copied ? <Check size={12} /> : <Copy size={12} />}

            <span>{copied ? 'Copied' : 'Copy'}</span>

          </button>

        </div>



        <div className="grid grid-cols-2 gap-2 pt-1">

          <a href={`tel:${phone}`} className="flex items-center justify-center gap-1.5 py-2.5 bg-[#27272A] hover:bg-[#323236] text-white rounded-xl text-xs font-semibold">

            <Phone size={13} /><span>Call</span>

          </a>

          <a

            href={`https://wa.me/${intlPhone}?text=${encodeURIComponent(`Hi ${businessName}, I'm a customer.`)}`}

            target="_blank"

            rel="noreferrer"

            className="flex items-center justify-center gap-1.5 py-2.5 bg-[#20BF6B] hover:bg-[#1bb060] text-white rounded-xl text-xs font-semibold"

          >

            <MessageCircle size={13} /><span>WhatsApp</span>

          </a>

        </div>

      </div>

    </ModalShell>

  )

}



export function TableSelectorModal({

  isOpen,

  currentTable,

  onClose,

  onSelectTable,

}: {

  isOpen: boolean

  currentTable: string

  onClose: () => void

  onSelectTable: (table: string) => void

}) {

  const [selected, setSelected] = useState(currentTable || '')

  const [custom, setCustom] = useState('')



  const handleConfirm = () => {

    const table = (custom.trim() || selected).trim()

    if (table) {

      onSelectTable(table)

      onClose()

    }

  }



  return (

    <ModalShell isOpen={isOpen} onClose={onClose} title="Select Your Table">

      <div className="space-y-4">

        <p className="text-xs text-gray-400">Pick your table so orders are delivered directly to you.</p>

        <div className="grid grid-cols-4 gap-2">

          {Array.from({ length: 12 }, (_, i) => String(i + 1)).map((t) => (

            <button

              key={t}

              type="button"

              onClick={() => { setSelected(t); setCustom('') }}

              className={`py-2 rounded-xl text-sm font-semibold cursor-pointer transition ${

                selected === t && !custom ? 'bg-[#EB4F16] text-white' : 'bg-[#27272A] text-gray-300 hover:text-white'

              }`}

            >

              T-{t}

            </button>

          ))}

        </div>

        <input

          type="text"

          placeholder="Or type custom (e.g. Rooftop 4, Bar 2)"

          value={custom}

          onChange={(e) => { setCustom(e.target.value); setSelected('') }}

          className="w-full bg-[#1F1F23] border border-[#2E2E34] rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-[#EB4F16]"

        />

        <button

          type="button"

          onClick={handleConfirm}

          disabled={!selected && !custom.trim()}

          className="w-full py-2.5 bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] text-white font-bold rounded-full text-sm cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"

        >

          Confirm Table {(custom || selected) ? `#${custom || selected}` : ''}

        </button>

      </div>

    </ModalShell>

  )

}



export function CartDrawer({
  isOpen,
  items,
  tableNumber,
  restaurantName,
  whatsAppNumber,
  menuSlug,
  onClose,
  onQuantityChange,
  onClearCart,
  onChangeTable,
  onOrderPlaced,
  onOpenOrderStatus,
  activeOrdersCount = 0,
}: {
  isOpen: boolean
  items: CartItem[]
  tableNumber: string
  restaurantName: string
  whatsAppNumber?: string
  menuSlug?: string
  onClose: () => void
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number) => void
  onClearCart: () => void
  onChangeTable: () => void
  onOrderPlaced?: (order: LiveTableOrder) => void
  onOpenOrderStatus?: () => void
  activeOrdersCount?: number
}) {
  const [instructions, setInstructions] = useState('')
  const [waiterSent, setWaiterSent] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const getOrderRound = (): number => {
    try {
      const last = sessionStorage.getItem('ar_last_order_timestamp')
      if (last && Date.now() - parseInt(last, 10) > 90 * 60 * 1000) {
        sessionStorage.setItem('ar_order_round', '1')
        return 1
      }
      return Math.max(1, parseInt(sessionStorage.getItem('ar_order_round') || '1', 10))
    } catch {
      return 1
    }
  }

  const [currentRound, setCurrentRound] = useState<number>(getOrderRound)

  const resetSession = () => {
    sessionStorage.setItem('ar_order_round', '1')
    sessionStorage.removeItem('ar_last_order_timestamp')
    sessionStorage.removeItem('ar_placed_order_ids')
    setCurrentRound(1)
    onClearCart()
  }

  const getWhatsAppTarget = () => {
    const raw = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')
    return raw.length === 10 ? `91${raw}` : raw
  }

  const openWhatsApp = (text: string) => {
    window.open(`https://api.whatsapp.com/send?phone=${getWhatsAppTarget()}&text=${encodeURIComponent(text)}`, '_blank')
  }

  const getTableLabel = () =>
    tableNumber ? (tableNumber.toLowerCase().startsWith('table') ? tableNumber : `Table ${tableNumber}`) : 'Dine-in'

  const handleSendOrderDirectly = async () => {
    if (isSubmitting || items.length === 0) return
    setIsSubmitting(true)

    const round = getOrderRound()
    const orderItems = items.map((i) => ({
      id: i.dish.id,
      name: i.dish.name,
      quantity: i.quantity,
      unitPrice: i.dish.pricePaise ? Math.round(i.dish.pricePaise / 100) : 0,
    }))

    let placedOrder: LiveTableOrder | null = null
    if (menuSlug) {
      placedOrder = await tableOrderService.placeOrder(menuSlug, {
        tableNumber: tableNumber || 'Dine-in',
        round,
        instructions: instructions.trim(),
        customerPhone: '',
        items: orderItems,
      })
    }

    const nextRound = round + 1
    sessionStorage.setItem('ar_order_round', String(nextRound))
    sessionStorage.setItem('ar_last_order_timestamp', String(Date.now()))
    setCurrentRound(nextRound)
    setInstructions('')
    setIsSubmitting(false)
    onClearCart()
    onClose()

    if (placedOrder && onOrderPlaced) {
      onOrderPlaced(placedOrder)
    } else if (onOpenOrderStatus) {
      onOpenOrderStatus()
    }
  }

  const sendWhatsAppOrder = () => {
    const round = getOrderRound()
    const title = round > 1 ? `\ud83c\udf7d\ufe0f *ADDITIONAL ORDER (Round ${round}) \u2014 ${restaurantName}*` : `\ud83c\udf7d\ufe0f *ORDER (Round 1) \u2014 ${restaurantName}*`
    const lines = [
      title,
      `\ud83d\udccd *${getTableLabel()}*${round > 1 ? ' *(Add-on items)*' : ''}`,
      '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500',
      '*Items to prepare:*',
      ...items.map((i) => `\u2022 ${i.quantity}x ${i.dish.name}`),
      ...(instructions.trim() ? ['\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500', `\ud83d\udcdd *Note:* ${instructions.trim()}`] : []),
      '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500',
      '\u23f3 *Your order will be ready in a few minutes!*',
      `\u2728 *Thank you for dining with ${restaurantName}!*`,
    ]

    openWhatsApp(lines.join('\n'))
  }

  const requestBill = () => {
    openWhatsApp(`\ud83e\uddfe *BILL REQUEST \u2014 ${restaurantName}*\n\ud83d\udccd *${getTableLabel()}*\n"We have finished our meal. Please bring the bill. Thank you!"`)
  }

  const callWaiter = () => {
    openWhatsApp(`\ud83d\udc4b *Assistance Needed*\n\ud83d\udccd ${getTableLabel()}\n\ud83c\udfe8 ${restaurantName}`)
    setWaiterSent(true)
    setTimeout(() => setWaiterSent(false), 3000)
  }

  return (
    <BottomSheetShell
      isOpen={isOpen}
      onClose={onClose}
      title={
        <div className="flex items-center gap-2 flex-wrap">
          <h2 className="text-base font-bold text-white">Your Table Order</h2>
          <button
            type="button"
            onClick={onChangeTable}
            className="flex items-center gap-1 text-[11px] font-bold text-[#FF6A3D] bg-[#EB4F16]/15 border border-[#EB4F16]/30 px-2 py-0.5 rounded-full cursor-pointer"
          >
            <span>{tableNumber ? `Table ${tableNumber}` : 'Set Table'}</span>
            <Edit3 size={10} />
          </button>
          {currentRound > 1 && (
            <span className="text-[10px] font-bold text-amber-400 bg-amber-400/10 border border-amber-400/30 px-2 py-0.5 rounded-full">
              Round {currentRound}
            </span>
          )}
        </div>
      }
      action={items.length > 0 && <button type="button" onClick={onClearCart} className="text-xs text-red-400 hover:text-red-300 font-semibold px-2 py-1 cursor-pointer">Clear</button>}
      footer={
        items.length > 0 && (
          <div className="space-y-2">
            <button
              type="button"
              disabled={isSubmitting}
              onClick={handleSendOrderDirectly}
              className="w-full py-3.5 bg-gradient-to-r from-[#FF5353] to-[#FF7043] hover:from-[#ff4040] hover:to-[#ff6233] text-white font-black rounded-full text-sm cursor-pointer flex items-center justify-center gap-2 shadow-xl shadow-[#FF5353]/30 disabled:opacity-50 transition"
            >
              {isSubmitting ? (
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
              ) : (
                <ChefHat size={18} />
              )}
              <span>
                {isSubmitting
                  ? 'Sending to Kitchen...'
                  : currentRound > 1
                  ? `Send Round ${currentRound} Directly to Kitchen`
                  : 'Send Order Directly to Kitchen'}
              </span>
            </button>
            <div className="flex items-center justify-center gap-3 pt-1">
              <button
                type="button"
                onClick={sendWhatsAppOrder}
                className="text-[11px] text-gray-400 hover:text-white flex items-center gap-1 cursor-pointer transition"
              >
                <MessageCircle size={12} className="text-[#20BF6B]" />
                <span>Also open WhatsApp slip (optional)</span>
              </button>
            </div>
          </div>
        )
      }
    >
      {items.length === 0 ? (
        <div className="text-center py-8 text-gray-400">
          <div className="text-4xl mb-2">\ud83c\udf7d\ufe0f</div>
          <p className="text-sm font-semibold text-white">
            {activeOrdersCount > 0
              ? `${activeOrdersCount} Active Order${activeOrdersCount > 1 ? 's' : ''} in Kitchen!`
              : currentRound > 1
              ? `Round ${currentRound - 1} Order Sent!`
              : 'Your order is empty'}
          </p>
          <p className="text-xs text-gray-400 mt-1 max-w-xs mx-auto">
            {activeOrdersCount > 0 || currentRound > 1
              ? 'Your dishes are sent to the kitchen. You can track preparation status live or add more dishes anytime.'
              : 'Browse dishes and tap ADD to build your order.'}
          </p>
          {(activeOrdersCount > 0 || currentRound > 1) && (
            <div className="mt-4 flex flex-col sm:flex-row items-center justify-center gap-2">
              {onOpenOrderStatus && (
                <button
                  type="button"
                  onClick={() => {
                    onClose()
                    onOpenOrderStatus()
                  }}
                  className="px-4 py-2 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-white rounded-full text-xs font-bold cursor-pointer flex items-center gap-1.5 shadow"
                >
                  <ChefHat size={14} />
                  <span>Track Kitchen Status</span>
                </button>
              )}
              <button
                type="button"
                onClick={requestBill}
                className="px-4 py-2 bg-[#27272A] hover:bg-[#323238] border border-gray-700 text-white rounded-full text-xs font-semibold cursor-pointer"
              >
                \ud83e\uddfe Request Final Bill
              </button>
              <button
                type="button"
                onClick={resetSession}
                className="px-3 py-2 text-gray-400 hover:text-white text-xs cursor-pointer"
              >
                New Visit
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-3">
          {items.map(({ dish, quantity }) => {

            const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2

            const unitPrice = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0

            return (

              <div key={dish.id} className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center justify-between gap-3">

                <div className="flex-1 min-w-0">

                  <div className="flex items-center gap-1.5 mb-0.5">

                    <span className={`w-3 h-3 border rounded-[2px] inline-flex items-center justify-center ${isVeg ? 'border-[#20BF6B]' : 'border-[#EF4444]'}`}>

                      <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#EF4444]'}`} />

                    </span>

                    <span className="text-sm font-semibold text-white truncate">{dish.name}</span>

                  </div>

                  <span className="text-xs text-gray-400">₹{unitPrice} each</span>

                </div>

                <div className="flex items-center gap-3">

                  <div className="flex items-center bg-[#27272A] border border-[#3F3F46] rounded-full px-2 py-0.5 gap-2">

                    <button type="button" onClick={() => onQuantityChange(dish, quantity - 1)} className="text-white hover:text-red-400 cursor-pointer">

                      {quantity === 1 ? <Trash2 size={12} className="text-red-400" /> : <Minus size={12} />}

                    </button>

                    <span className="text-xs font-bold text-white min-w-[12px] text-center">{quantity}</span>

                    <button type="button" onClick={() => onQuantityChange(dish, quantity + 1)} className="text-white hover:text-[#EB4F16] cursor-pointer">

                      <Plus size={12} />

                    </button>

                  </div>

                  <span className="text-sm font-bold text-white min-w-[45px] text-right">₹{unitPrice * quantity}</span>

                </div>

              </div>

            )

          })}



          <textarea

            rows={2}

            value={instructions}

            onChange={(e) => setInstructions(e.target.value)}

            placeholder="Special instructions (e.g. less spicy, extra lemons)..."

            className="w-full bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-2.5 text-xs text-white outline-none resize-none focus:border-[#EB4F16]"

          />

          <div className="text-center pt-1">

            <button type="button" onClick={callWaiter} className="inline-flex items-center gap-1.5 text-xs text-gray-400 hover:text-white cursor-pointer">

              <BellRing size={12} />

              <span>{waiterSent ? '✓ Request sent to waiter!' : 'Need water or help? Ring Waiter'}</span>

            </button>

          </div>

        </div>

      )}

    </BottomSheetShell>

  )

}

