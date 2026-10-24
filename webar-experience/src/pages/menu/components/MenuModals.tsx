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
} from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'
import type { CartItem } from '@/types/cart'

/* -------------------------------------------------------------------------- */
/* Generic Modal & Bottom Sheet Shells (Reduces duplication)                  */
/* -------------------------------------------------------------------------- */

function ModalShell({
  isOpen,
  onClose,
  title,
  subtitle,
  children,
  maxWidth = 'max-w-md',
}: {
  isOpen: boolean
  onClose: () => void
  title: string
  subtitle?: string
  children: React.ReactNode
  maxWidth?: string
}) {
  if (!isOpen) return null
  return (
    <div
      className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className={`w-full ${maxWidth} bg-[#18181B] border border-[#27272A] rounded-2xl shadow-2xl overflow-hidden`}>
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

/* -------------------------------------------------------------------------- */
/* Restaurant Info & Wi-Fi Modal                                              */
/* -------------------------------------------------------------------------- */

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
        {/* Address */}
        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex gap-3">
          <div className="p-2 bg-[#EB4F16]/15 text-[#FF6A3D] rounded-lg h-fit">
            <MapPin size={16} />
          </div>
          <div>
            <span className="text-[11px] font-semibold text-gray-400 uppercase">Address</span>
            <p className="text-sm text-white mt-0.5">{address || `${city}, India`}</p>
            <a
              href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${businessName}, ${address || city}`)}`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1 text-xs text-[#FF6A3D] font-semibold mt-1"
            >
              <span>Open in Google Maps</span>
              <ExternalLink size={11} />
            </a>
          </div>
        </div>

        {/* Timings */}
        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center gap-3">
          <div className="p-2 bg-[#20BF6B]/15 text-[#20BF6B] rounded-lg">
            <Clock size={16} />
          </div>
          <div>
            <span className="text-[11px] font-semibold text-gray-400 uppercase">Hours</span>
            <p className="text-sm font-semibold text-white mt-0.5">🟢 Open: 11:00 AM – 11:30 PM</p>
          </div>
        </div>

        {/* Wi-Fi */}
        <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-blue-500/15 text-blue-400 rounded-lg">
              <Wifi size={16} />
            </div>
            <div>
              <span className="text-[11px] font-semibold text-gray-400 uppercase">Guest Wi-Fi</span>
              <p className="text-xs font-semibold text-white mt-0.5">
                Pass: <code className="bg-[#27272A] px-1.5 py-0.5 rounded text-gray-200">{wifiPass}</code>
              </p>
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

        {/* Contacts */}
        <div className="grid grid-cols-2 gap-2 pt-1">
          <a
            href={`tel:${phone}`}
            className="flex items-center justify-center gap-1.5 py-2.5 bg-[#27272A] hover:bg-[#323236] text-white rounded-xl text-xs font-semibold"
          >
            <Phone size={13} />
            <span>Call</span>
          </a>
          <a
            href={`https://wa.me/${intlPhone}?text=${encodeURIComponent(`Hi ${businessName}, I'm a customer.`)}`}
            target="_blank"
            rel="noreferrer"
            className="flex items-center justify-center gap-1.5 py-2.5 bg-[#20BF6B] hover:bg-[#1bb060] text-white rounded-xl text-xs font-semibold"
          >
            <MessageCircle size={13} />
            <span>WhatsApp</span>
          </a>
        </div>
      </div>
    </ModalShell>
  )
}

/* -------------------------------------------------------------------------- */
/* Table Selector Modal                                                       */
/* -------------------------------------------------------------------------- */

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
        <p className="text-xs text-gray-400">
          Pick your seated table so the kitchen and waiters deliver orders directly to you.
        </p>

        {/* Quick Grid */}
        <div className="grid grid-cols-4 gap-2">
          {Array.from({ length: 12 }, (_, i) => String(i + 1)).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => {
                setSelected(t)
                setCustom('')
              }}
              className={`py-2 rounded-xl text-sm font-semibold cursor-pointer transition ${
                selected === t && !custom
                  ? 'bg-[#EB4F16] text-white'
                  : 'bg-[#27272A] text-gray-300 hover:text-white'
              }`}
            >
              T-{t}
            </button>
          ))}
        </div>

        {/* Custom Input */}
        <div>
          <input
            type="text"
            placeholder="Or type custom (e.g. Rooftop 4, Bar 2)"
            value={custom}
            onChange={(e) => {
              setCustom(e.target.value)
              setSelected('')
            }}
            className="w-full bg-[#1F1F23] border border-[#2E2E34] rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-[#EB4F16]"
          />
        </div>

        <button
          type="button"
          onClick={handleConfirm}
          disabled={!selected && !custom.trim()}
          className="w-full py-2.5 bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] text-white font-bold rounded-full text-sm cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed shadow-lg shadow-[#EB4F16]/20"
        >
          Confirm Table {(custom || selected) ? `#${custom || selected}` : ''}
        </button>
      </div>
    </ModalShell>
  )
}

/* -------------------------------------------------------------------------- */
/* Cart & WhatsApp Checkout Drawer                                            */
/* -------------------------------------------------------------------------- */

export function CartDrawer({
  isOpen,
  items,
  tableNumber,
  restaurantName,
  whatsAppNumber,
  onClose,
  onQuantityChange,
  onClearCart,
  onChangeTable,
}: {
  isOpen: boolean
  items: CartItem[]
  tableNumber: string
  restaurantName: string
  whatsAppNumber?: string
  onClose: () => void
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number) => void
  onClearCart: () => void
  onChangeTable: () => void
}) {
  const [instructions, setInstructions] = useState('')
  const [waiterSent, setWaiterSent] = useState(false)

  const subtotalPaise = items.reduce(
    (sum, item) => sum + (item.dish.pricePaise || 0) * item.quantity,
    0,
  )
  const subtotal = Math.round(subtotalPaise / 100)
  const gst = Math.round(subtotal * 0.05)
  const grandTotal = subtotal + gst

  const sendWhatsAppOrder = () => {
    const rawPhone = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')
    const phone = rawPhone.length === 10 ? `91${rawPhone}` : rawPhone
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })

    const lines = [
      `🛎️ *ORDER — ${restaurantName}*`,
      `📍 *${tableNumber ? `Table ${tableNumber}` : 'Dine-in'}* (⏰ ${time})`,
      '━━━━━━━━━━━━━━━━━━━━',
      ...items.map((i) => `▫️ ${i.quantity}x ${i.dish.name} (₹${Math.round(((i.dish.pricePaise || 0) * i.quantity) / 100)})`),
      '━━━━━━━━━━━━━━━━━━━━',
      `Subtotal: ₹${subtotal.toLocaleString('en-IN')}`,
      `GST (5%): ₹${gst.toLocaleString('en-IN')}`,
      `💰 *Total: ₹${grandTotal.toLocaleString('en-IN')}*`,
      instructions.trim() ? `📝 *Note:* ${instructions.trim()}` : '',
      '━━━━━━━━━━━━━━━━━━━━',
      '✨ Sent via WebAR Smart Menu',
    ].filter(Boolean)

    window.open(`https://wa.me/${phone}?text=${encodeURIComponent(lines.join('\n'))}`, '_blank')
  }

  const callWaiter = () => {
    const rawPhone = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')
    const phone = rawPhone.length === 10 ? `91${rawPhone}` : rawPhone
    const text = `👋 *Assistance Needed*\n📍 Table: ${tableNumber || '1'}\n🏨 ${restaurantName}`
    window.open(`https://wa.me/${phone}?text=${encodeURIComponent(text)}`, '_blank')
    setWaiterSent(true)
    setTimeout(() => setWaiterSent(false), 3000)
  }

  return (
    <BottomSheetShell
      isOpen={isOpen}
      onClose={onClose}
      title={
        <div className="flex items-center gap-2">
          <h2 className="text-base font-bold text-white">Your Table Order</h2>
          <button
            type="button"
            onClick={onChangeTable}
            className="flex items-center gap-1 text-[11px] font-bold text-[#FF6A3D] bg-[#EB4F16]/15 border border-[#EB4F16]/30 px-2 py-0.5 rounded-full cursor-pointer"
          >
            <span>{tableNumber ? `Table ${tableNumber}` : 'Set Table'}</span>
            <Edit3 size={10} />
          </button>
        </div>
      }
      action={
        items.length > 0 && (
          <button
            type="button"
            onClick={onClearCart}
            className="text-xs text-red-400 hover:text-red-300 font-semibold px-2 py-1 cursor-pointer"
          >
            Clear
          </button>
        )
      }
      footer={
        items.length > 0 && (
          <div className="space-y-2">
            <button
              type="button"
              onClick={sendWhatsAppOrder}
              className="w-full py-3 bg-gradient-to-r from-[#20BF6B] to-[#10B981] hover:from-[#1eb163] hover:to-[#0ea573] text-white font-bold rounded-full text-sm cursor-pointer flex items-center justify-center gap-2 shadow-lg shadow-[#20BF6B]/25"
            >
              <MessageCircle size={16} />
              <span>Send Order to Kitchen via WhatsApp (₹{grandTotal.toLocaleString('en-IN')})</span>
            </button>
            <p className="text-[11px] text-gray-500 text-center">
              Opens WhatsApp with your table order slip pre-filled.
            </p>
          </div>
        )
      }
    >
      {items.length === 0 ? (
        <div className="text-center py-10 text-gray-400">
          <div className="text-4xl mb-2">🍽️</div>
          <p className="text-sm font-semibold text-white">Your order is empty</p>
          <p className="text-xs text-gray-500 mt-1">Browse dishes and tap ADD to build your order.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {items.map(({ dish, quantity }) => {
            const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
            const unitPrice = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0
            return (
              <div
                key={dish.id}
                className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center justify-between gap-3"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-1.5 mb-0.5">
                    <span
                      className={`w-3 h-3 border rounded-[2px] inline-flex items-center justify-center ${
                        isVeg ? 'border-[#20BF6B]' : 'border-[#EF4444]'
                      }`}
                    >
                      <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#EF4444]'}`} />
                    </span>
                    <span className="text-sm font-semibold text-white truncate">{dish.name}</span>
                  </div>
                  <span className="text-xs text-gray-400">₹{unitPrice} each</span>
                </div>

                <div className="flex items-center gap-3">
                  <div className="flex items-center bg-[#27272A] border border-[#3F3F46] rounded-full px-2 py-0.5 gap-2">
                    <button
                      type="button"
                      onClick={() => onQuantityChange(dish, quantity - 1)}
                      className="text-white hover:text-red-400 cursor-pointer"
                    >
                      {quantity === 1 ? <Trash2 size={12} className="text-red-400" /> : <Minus size={12} />}
                    </button>
                    <span className="text-xs font-bold text-white min-w-[12px] text-center">{quantity}</span>
                    <button
                      type="button"
                      onClick={() => onQuantityChange(dish, quantity + 1)}
                      className="text-white hover:text-[#EB4F16] cursor-pointer"
                    >
                      <Plus size={12} />
                    </button>
                  </div>
                  <span className="text-sm font-bold text-white min-w-[45px] text-right">
                    ₹{unitPrice * quantity}
                  </span>
                </div>
              </div>
            )
          })}

          {/* Notes */}
          <div>
            <textarea
              rows={2}
              value={instructions}
              onChange={(e) => setInstructions(e.target.value)}
              placeholder="Special instructions (e.g. less spicy, extra lemons)..."
              className="w-full bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-2.5 text-xs text-white outline-none resize-none focus:border-[#EB4F16]"
            />
          </div>

          {/* Bill summary */}
          <div className="bg-[#141416] border border-[#27272A] rounded-xl p-3 text-xs space-y-1.5 text-gray-400">
            <div className="flex justify-between">
              <span>Subtotal</span>
              <span>₹{subtotal.toLocaleString('en-IN')}</span>
            </div>
            <div className="flex justify-between">
              <span>GST (5%)</span>
              <span>₹{gst.toLocaleString('en-IN')}</span>
            </div>
            <div className="flex justify-between text-sm font-bold text-white border-t border-[#27272A] pt-1.5">
              <span>Total Payable</span>
              <span className="text-[#EB4F16]">₹{grandTotal.toLocaleString('en-IN')}</span>
            </div>
          </div>

          <div className="text-center pt-1">
            <button
              type="button"
              onClick={callWaiter}
              className="inline-flex items-center gap-1.5 text-xs text-gray-400 hover:text-white cursor-pointer"
            >
              <BellRing size={12} />
              <span>{waiterSent ? '✓ Request sent to waiter!' : 'Need water or help? Ring Waiter'}</span>
            </button>
          </div>
        </div>
      )}
    </BottomSheetShell>
  )
}
