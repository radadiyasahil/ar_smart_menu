import { useState, useEffect } from 'react'
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
  Lock,
  Users,
} from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'
import type { CartItem, DishCustomization } from '@/types/cart'
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
  wifiName,
  wifiPassword,
}: {
  isOpen: boolean
  businessName: string
  city: string
  address?: string
  whatsAppNumber?: string
  onClose: () => void
  wifiName?: string
  wifiPassword?: string
}) {
  const [copied, setCopied] = useState(false)
  const phone = (whatsAppNumber || '9876543210').replace(/[^0-9]/g, '')
  const intlPhone = phone.length === 10 ? `91${phone}` : phone
  const wifiPass = wifiPassword || ''

  const copyWifi = () => {
    if (!wifiPass) return
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



        {(wifiName || wifiPassword) && (
          <div className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-500/15 text-blue-400 rounded-lg"><Wifi size={16} /></div>
              <div>
                <span className="text-[11px] font-semibold text-gray-400 uppercase">
                  {wifiName ? `Wi-Fi: ${wifiName}` : 'Guest Wi-Fi'}
                </span>
                {wifiPassword ? (
                  <p className="text-xs font-semibold text-white mt-0.5">
                    Pass: <code className="bg-[#27272A] px-1.5 py-0.5 rounded text-gray-200">{wifiPassword}</code>
                  </p>
                ) : (
                  <p className="text-xs text-emerald-400 mt-0.5">Free Open Wi-Fi (No password)</p>
                )}
              </div>
            </div>
            {wifiPassword && (
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
            )}
          </div>
        )}



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
  availableTables,
  onClose,
  onSelectTable,
  isLocked = false,
  lockedMessage,
}: {
  isOpen: boolean
  currentTable: string
  availableTables?: string[]
  onClose: () => void
  onSelectTable: (table: string) => void
  isLocked?: boolean
  lockedMessage?: string
}) {
  const configuredTables = availableTables && availableTables.length > 0 ? availableTables : null
  const [selected, setSelected] = useState(currentTable || (configuredTables ? '' : 'Dine-in'))
  const [custom, setCustom] = useState('')

  useEffect(() => {
    if (currentTable) {
      setSelected(currentTable)
    } else if (!configuredTables) {
      setSelected('Dine-in')
    }
  }, [currentTable, configuredTables])

  const handleConfirm = () => {
    if (isLocked) {
      onClose()
      return
    }
    const table = (configuredTables ? selected : (custom.trim() || selected || 'Dine-in')).trim()
    if (table) {
      onSelectTable(table)
      onClose()
    }
  }

  const tableList = configuredTables ?? ['1', '2', '3', '4', '5', '6']

  return (
    <ModalShell isOpen={isOpen} onClose={onClose} title={isLocked ? 'Table Locked' : (configuredTables ? 'Select Your Table' : 'Dining / Table Selection')}>
      <div className="space-y-4">
        {isLocked ? (
          <div className="p-3.5 bg-amber-500/15 border border-amber-500/30 rounded-xl text-amber-200 text-xs flex items-center gap-2.5">
            <Lock size={18} className="text-amber-400 shrink-0" />
            <div className="space-y-0.5">
              <p className="font-bold text-amber-300">Active Dining Session in Progress</p>
              <p className="text-[11px] text-amber-200/90 leading-relaxed">
                {lockedMessage || `You have active orders placed at Table ${currentTable}. Your table cannot be changed during dining. Please ask restaurant staff if you need to be moved.`}
              </p>
            </div>
          </div>
        ) : (
          <p className="text-xs text-gray-400">
            {configuredTables
              ? 'Pick your table from the restaurant floor to place orders.'
              : 'Select how you are dining so the kitchen can prepare and deliver your order:'}
          </p>
        )}

        {!configuredTables && (
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              disabled={isLocked}
              onClick={() => { setSelected('Dine-in'); setCustom('') }}
              className={`py-3 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 ${
                isLocked ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
              } ${
                selected === 'Dine-in' && !custom
                  ? 'bg-[#EB4F16] text-white shadow-md shadow-[#EB4F16]/30 border border-[#FF6A3D]'
                  : 'bg-[#27272A] text-gray-300 hover:text-white hover:bg-[#323238]'
              }`}
            >
              <span>🍽️</span>
              <span>Dine-in (General)</span>
            </button>
            <button
              type="button"
              disabled={isLocked}
              onClick={() => { setSelected('Takeaway'); setCustom('') }}
              className={`py-3 px-3 rounded-xl text-xs font-bold transition flex items-center justify-center gap-2 ${
                isLocked ? 'opacity-40 cursor-not-allowed' : 'cursor-pointer'
              } ${
                selected === 'Takeaway' && !custom
                  ? 'bg-[#EB4F16] text-white shadow-md shadow-[#EB4F16]/30 border border-[#FF6A3D]'
                  : 'bg-[#27272A] text-gray-300 hover:text-white hover:bg-[#323238]'
              }`}
            >
              <span>🛍️</span>
              <span>Takeaway / Counter</span>
            </button>
          </div>
        )}

        <div>
          {!configuredTables && (
            <p className="text-[11px] font-semibold text-gray-400 mb-2">Or select / enter your table number:</p>
          )}
          <div className={`grid ${tableList.length <= 4 ? 'grid-cols-3' : 'grid-cols-3 sm:grid-cols-6'} gap-2`}>
            {tableList.map((t) => (
              <button
                key={t}
                type="button"
                disabled={isLocked && t !== currentTable}
                onClick={() => {
                  if (isLocked) return
                  setSelected(t)
                  setCustom('')
                }}
                className={`py-2 rounded-xl text-xs font-bold transition ${
                  isLocked && t !== currentTable
                    ? 'opacity-30 cursor-not-allowed bg-[#1F2028] text-gray-500'
                    : 'cursor-pointer'
                } ${
                  selected === t && !custom
                    ? 'bg-[#EB4F16] text-white shadow-md shadow-[#EB4F16]/30'
                    : 'bg-[#27272A] text-gray-300 hover:text-white hover:bg-[#323238]'
                }`}
              >
                Table {t}
              </button>
            ))}
          </div>
        </div>

        {!configuredTables && !isLocked && (
          <input
            type="text"
            placeholder="Or type custom table (e.g. Table 7, Rooftop 2)"
            value={custom}
            onChange={(e) => { setCustom(e.target.value); setSelected('') }}
            className="w-full bg-[#1F1F23] border border-[#2E2E34] rounded-xl px-3 py-2 text-sm text-white outline-none focus:border-[#EB4F16]"
          />
        )}

        <button
          type="button"
          onClick={handleConfirm}
          className={`w-full py-2.5 text-white font-bold rounded-full text-sm cursor-pointer shadow-lg transition ${
            isLocked
              ? 'bg-[#2A2B36] hover:bg-[#343544] border border-gray-700'
              : 'bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] shadow-[#EB4F16]/20'
          }`}
        >
          {isLocked
            ? `Table ${currentTable} is Active • Close`
            : `Confirm ${configuredTables ? `Table #${selected}` : (custom.trim() ? custom.trim() : (selected.startsWith('Table') || selected === 'Dine-in' || selected === 'Takeaway' ? selected : `Table ${selected}`))}`}
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
  nextRound,
  allCancelled = false,
  canRequestBill = false,
  isTableValid = true,
  isTableOccupied = false,
  occupiedMessage,
  isTableLocked = false,
  myClientId,
  dinerNickname,
  onNicknameChange,
  lastSharedBy,
  onCustomizeDish,
}: {
  isTableOccupied?: boolean
  occupiedMessage?: string
  isOpen: boolean
  items: CartItem[]
  tableNumber: string
  restaurantName: string
  whatsAppNumber?: string
  menuSlug?: string
  onClose: () => void
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number, customization?: DishCustomization, cartItemId?: string) => void
  onClearCart: () => void
  onChangeTable: () => void
  onOrderPlaced?: (order: LiveTableOrder) => void
  onOpenOrderStatus?: () => void
  activeOrdersCount?: number
  nextRound?: number
  allCancelled?: boolean
  canRequestBill?: boolean
  isTableValid?: boolean
  isTableLocked?: boolean
  myClientId?: string
  dinerNickname?: string
  onNicknameChange?: (name: string) => void
  lastSharedBy?: string
  onCustomizeDish?: (dish: PublicMenuDish) => void
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

  const effectiveRound = nextRound ?? getOrderRound()
  const [currentRound, setCurrentRound] = useState<number>(effectiveRound)

  useEffect(() => {
    if (nextRound && nextRound > 0) {
      setCurrentRound(nextRound)
    }
  }, [nextRound])

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
    tableNumber
      ? (tableNumber.toLowerCase().startsWith('table') || tableNumber.toLowerCase() === 'dine-in' || tableNumber.toLowerCase() === 'takeaway' || tableNumber.toLowerCase().includes('counter')
          ? tableNumber
          : `Table ${tableNumber}`)
      : 'Dine-in'

  const handleSendOrderDirectly = async () => {
    if (isSubmitting || items.length === 0) return
    if (!isTableValid) {
      alert(`Table "${tableNumber}" is not a valid table at this restaurant. Please change your table to continue.`)
      onChangeTable()
      return
    }
    setIsSubmitting(true)

    const round = nextRound ?? getOrderRound()
    const orderItems = items.map((i) => {
      const uPrice = i.unitPrice ?? (i.dish.pricePaise ? Math.round(i.dish.pricePaise / 100) : 0)
      const mods: string[] = []
      if (i.customization?.spiceLevel) {
        mods.push(`${i.customization.spiceLevel} Spicy`)
      }
      if (i.customization?.dietary && i.customization.dietary !== 'Regular') {
        mods.push(i.customization.dietary)
      }
      if (i.customization?.selectedAddons) {
        for (const a of i.customization.selectedAddons) {
          mods.push(`${a.name} (+₹${a.price})`)
        }
      }
      return {
        id: i.id || i.dish.id,
        name: i.dish.name,
        quantity: i.quantity,
        unitPrice: uPrice,
        modifiers: mods.length > 0 ? mods : undefined,
        notes: i.customization?.notes || undefined,
      }
    })

    if (isTableOccupied) {
      alert(occupiedMessage || `Table "${tableNumber}" is currently occupied by another customer. Please choose an available table.`)
      setIsSubmitting(false)
      onChangeTable()
      return
    }

    let placedOrder: LiveTableOrder | null = null
    try {
      if (menuSlug) {
        placedOrder = await tableOrderService.placeOrder(menuSlug, {
          tableNumber: tableNumber || 'Dine-in',
          round,
          instructions: instructions.trim(),
          customerPhone: '',
          items: orderItems,
        })
      }
    } catch (err: any) {
      alert(err.message || 'Could not place order. Please verify table number.')
      setIsSubmitting(false)
      if (err.message && err.message.toLowerCase().includes('occupied')) {
        onChangeTable()
      }
      return
    }

    const upcomingRound = round + 1
    sessionStorage.setItem('ar_order_round', String(upcomingRound))
    sessionStorage.setItem('ar_last_order_timestamp', String(Date.now()))
    setCurrentRound(upcomingRound)
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
      ...items.map((i) => {
        let line = `\u2022 ${i.quantity}x ${i.dish.name}`
        const extra: string[] = []
        if (i.customization?.spiceLevel) extra.push(`${i.customization.spiceLevel} Spicy`)
        if (i.customization?.dietary && i.customization.dietary !== 'Regular') extra.push(i.customization.dietary)
        if (i.customization?.selectedAddons?.length) {
          extra.push(...i.customization.selectedAddons.map((a) => a.name))
        }
        if (extra.length > 0) line += ` (${extra.join(', ')})`
        if (i.customization?.notes) line += ` [Note: ${i.customization.notes}]`
        return line
      }),
      ...(instructions.trim() ? ['\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500', `\ud83d\udcdd *Note:* ${instructions.trim()}`] : []),
      '\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500',
      '\u23f3 *Your order will be ready in a few minutes!*',
      `\u2728 *Thank you for dining with ${restaurantName}!*`,
    ]

    openWhatsApp(lines.join('\n'))
  }

  const callWaiter = async () => {
    setWaiterSent(true)
    if (menuSlug) {
      await tableOrderService.callWaiter(menuSlug, tableNumber || 'Dine-in', 'Need water or help')
    }
    setTimeout(() => setWaiterSent(false), 4000)
  }

  return (
    <BottomSheetShell
      isOpen={isOpen}
      onClose={onClose}
      title={
        <div className="flex items-center gap-2 flex-wrap">
          <h2 className="text-base font-bold text-white">Your Table Order</h2>
          {isTableLocked ? (
            <div
              className="flex items-center gap-1.5 text-[11px] font-bold text-gray-300 bg-white/10 border border-white/20 px-2.5 py-0.5 rounded-full select-none"
              title={`Table is locked to Table ${tableNumber} for this active dining session.`}
            >
              <Lock size={10} className="text-amber-400" />
              <span>{tableNumber ? `Table ${tableNumber}` : 'Dine-in'}</span>
            </div>
          ) : (
            <button
              type="button"
              onClick={onChangeTable}
              className="flex items-center gap-1 text-[11px] font-bold text-[#FF6A3D] bg-[#EB4F16]/15 border border-[#EB4F16]/30 px-2 py-0.5 rounded-full cursor-pointer"
            >
              <span>{tableNumber ? `Table ${tableNumber}` : 'Set Table'}</span>
              <Edit3 size={10} />
            </button>
          )}
          {tableNumber && (
            <div
              className="flex items-center gap-1 text-[10px] font-semibold text-emerald-400 bg-emerald-500/10 border border-emerald-500/25 px-2 py-0.5 rounded-full"
              title="Real-time synchronized across all diners at this table"
            >
              <Users size={10} />
              <span>Table Cart</span>
            </div>
          )}
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
            {!isTableValid && !isTableLocked && (
              <div className="p-2.5 rounded-xl bg-rose-500/15 border border-rose-500/30 text-rose-300 text-xs flex items-center justify-between">
                <span>⚠️ Table &ldquo;{tableNumber}&rdquo; is not a valid table.</span>
                <button
                  type="button"
                  onClick={onChangeTable}
                  className="font-bold underline text-rose-200 hover:text-white ml-2 cursor-pointer"
                >
                  Change Table
                </button>
              </div>
            )}
            {isTableOccupied && !isTableLocked ? (
              <button
                type="button"
                onClick={onChangeTable}
                className="w-full py-3.5 bg-amber-500 hover:bg-amber-400 text-black font-black rounded-full text-sm cursor-pointer flex items-center justify-center gap-2 shadow-xl transition"
              >
                <span>⚠️ Table "{tableNumber}" Occupied • Choose Another Table</span>
              </button>
            ) : (
              <button
                type="button"
                disabled={isSubmitting || !isTableValid}
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
            )}
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
      {isTableOccupied && !isTableLocked && (
        <div className="mb-3 p-3 bg-amber-500/15 border border-amber-500/40 rounded-xl text-amber-200 text-xs flex items-center justify-between gap-2 shadow">
          <span>⚠️ Table "{tableNumber}" is currently occupied by another customer.</span>
          <button
            type="button"
            onClick={onChangeTable}
            className="px-2.5 py-1 bg-amber-500 text-black font-bold rounded-lg text-[11px] shrink-0 hover:bg-amber-400 transition cursor-pointer"
          >
            Change Table
          </button>
        </div>
      )}

      {tableNumber && (
        <div className="mb-3 px-3 py-2 bg-gradient-to-r from-emerald-500/10 via-[#27272A] to-transparent border border-emerald-500/20 rounded-xl flex items-center justify-between text-xs text-gray-300">
          <div className="flex items-center gap-1.5">
            <Users size={13} className="text-emerald-400 shrink-0" />
            <span className="text-gray-400">Ordering as:</span>
            <button
              type="button"
              onClick={() => {
                const name = window.prompt('Enter your name for the table cart:', dinerNickname || 'Guest')
                if (name && name.trim()) onNicknameChange?.(name.trim())
              }}
              className="font-bold text-white hover:text-[#FF6A3D] underline cursor-pointer inline-flex items-center gap-1"
              title="Click to edit your display name"
            >
              <span>{dinerNickname || 'Guest'}</span>
              <Edit3 size={10} className="text-emerald-400" />
            </button>
          </div>
          {lastSharedBy && (
            <span className="text-[10px] text-gray-400 truncate max-w-[140px]">
              Last edit: {lastSharedBy}
            </span>
          )}
        </div>
      )}
      {items.length === 0 ? (
        <div className="text-center py-8 text-gray-400">
          <div className="text-4xl mb-2">🍽️</div>
          <p className="text-sm font-semibold text-white">
            {allCancelled
              ? 'Previous order was declined by restaurant'
              : activeOrdersCount > 0
              ? `${activeOrdersCount} Active Order${activeOrdersCount > 1 ? 's' : ''} in Kitchen!`
              : effectiveRound > 1
              ? `Round ${effectiveRound - 1} Order Sent!`
              : 'Your order is empty'}
          </p>
          <p className="text-xs text-gray-400 mt-1 max-w-xs mx-auto">
            {allCancelled
              ? `You can browse dishes and tap ADD to build and submit your order for Round ${effectiveRound}.`
              : activeOrdersCount > 0 || effectiveRound > 1
              ? 'Your dishes are sent to the kitchen. You can track preparation status live or add more dishes anytime.'
              : 'Browse dishes and tap ADD to build your order.'}
          </p>
          {allCancelled ? (
            <div className="mt-4 flex items-center justify-center gap-2">
              <button
                type="button"
                onClick={onClose}
                className="px-5 py-2.5 bg-gradient-to-r from-[#FF5353] to-[#FF7043] text-white rounded-full text-xs font-bold cursor-pointer shadow flex items-center gap-1.5"
              >
                <Plus size={14} />
                <span>+ Browse Dishes & Order Round {effectiveRound}</span>
              </button>
            </div>
          ) : (activeOrdersCount > 0 || effectiveRound > 1) ? (
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
              {canRequestBill && onOpenOrderStatus && (
                <button
                  type="button"
                  onClick={() => {
                    onClose()
                    onOpenOrderStatus()
                  }}
                  className="px-4 py-2 bg-[#27272A] hover:bg-[#323238] border border-gray-700 text-white rounded-full text-xs font-semibold cursor-pointer"
                >
                  🧾 Request Final Bill
                </button>
              )}
              {!isTableLocked && (
                <button
                  type="button"
                  onClick={resetSession}
                  className="px-3 py-2 text-gray-400 hover:text-white text-xs cursor-pointer"
                >
                  New Visit
                </button>
              )}
            </div>
          ) : null}
        </div>
      ) : (
        <div className="space-y-3">
          {items.map((item) => {
            const { dish, quantity, customization } = item
            const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
            const unitPrice = item.unitPrice ?? (dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0)
            const itemKey = item.id || dish.id

            return (
              <div key={itemKey} className="bg-[#1F1F23] border border-[#2E2E34] rounded-xl p-3 flex flex-col gap-2">
                <div className="flex items-center justify-between gap-3">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-1.5 mb-0.5 flex-wrap">
                      <span className={`w-3 h-3 border rounded-[2px] inline-flex items-center justify-center shrink-0 ${isVeg ? 'border-[#20BF6B]' : 'border-[#EF4444]'}`}>
                        <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#EF4444]'}`} />
                      </span>
                      <span className="text-sm font-semibold text-white truncate">{dish.name}</span>
                      {item.addedBy && (
                        <span className={`text-[9px] font-semibold px-1.5 py-0.2 rounded-full ${
                          item.clientId === myClientId
                            ? 'bg-blue-500/15 text-blue-300 border border-blue-500/30'
                            : 'bg-emerald-500/15 text-emerald-300 border border-emerald-500/30'
                        }`}>
                          {item.clientId === myClientId ? 'Added by You' : `Added by ${item.addedBy}`}
                        </span>
                      )}
                    </div>
                    <span className="text-xs text-gray-400">₹{unitPrice} each</span>
                  </div>

                  <div className="flex items-center gap-3">
                    <div className="flex items-center bg-[#27272A] border border-[#3F3F46] rounded-full px-2 py-0.5 gap-2">
                      <button
                        type="button"
                        onClick={() => onQuantityChange(dish, quantity - 1, customization, itemKey)}
                        className="text-white hover:text-red-400 cursor-pointer"
                        title="Decrease quantity"
                      >
                        {quantity === 1 ? <Trash2 size={12} className="text-red-400" /> : <Minus size={12} />}
                      </button>
                      <span className="text-xs font-bold text-white min-w-[12px] text-center">{quantity}</span>
                      <button
                        type="button"
                        onClick={() => onQuantityChange(dish, quantity + 1, customization, itemKey)}
                        className="text-white hover:text-[#EB4F16] cursor-pointer"
                        title="Increase quantity (preserves customizations)"
                      >
                        <Plus size={12} />
                      </button>
                    </div>
                    <span className="text-sm font-bold text-white min-w-[45px] text-right">₹{unitPrice * quantity}</span>
                  </div>
                </div>

                {/* Modifiers & Add-ons Badges */}
                {customization && (
                  <div className="pt-1.5 border-t border-white/5 flex flex-wrap items-center gap-1.5 text-[10px]">
                    {customization.spiceLevel && (
                      <span className="px-2 py-0.5 rounded-md bg-amber-500/10 border border-amber-500/25 text-amber-300 font-semibold">
                        🌶️ {customization.spiceLevel}
                      </span>
                    )}
                    {customization.dietary && customization.dietary !== 'Regular' && (
                      <span className="px-2 py-0.5 rounded-md bg-emerald-500/10 border border-emerald-500/25 text-emerald-300 font-semibold">
                        🌱 {customization.dietary}
                      </span>
                    )}
                    {customization.selectedAddons?.map((addon) => (
                      <span key={addon.id} className="px-2 py-0.5 rounded-md bg-white/5 border border-white/10 text-gray-300 font-semibold">
                        + {addon.name} (+₹{addon.price})
                      </span>
                    ))}
                    {customization.notes && (
                      <span className="px-2 py-0.5 rounded-md bg-blue-500/10 border border-blue-500/20 text-blue-300 italic">
                        📝 &ldquo;{customization.notes}&rdquo;
                      </span>
                    )}
                  </div>
                )}

                {/* Add different variation option */}
                {onCustomizeDish && (
                  <div className="pt-1 flex items-center justify-between border-t border-white/5">
                    <button
                      type="button"
                      onClick={() => {
                        onClose()
                        onCustomizeDish(dish)
                      }}
                      className="text-[10px] font-semibold text-[#FF7043] hover:text-[#ff8a65] flex items-center gap-1 cursor-pointer transition py-0.5"
                    >
                      <Plus size={11} />
                      <span>Add another variation with different customizations</span>
                    </button>
                  </div>
                )}
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
