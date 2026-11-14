import { useEffect, useState, useMemo, useRef } from 'react'
import { useParams, useSearchParams, Link } from 'react-router-dom'
import {
  Search,
  Sparkles,
  MapPin,
  Share2,
  Info,
  ShoppingBag,
  Check,
  ChevronRight,
  RotateCcw,
  ArrowLeft,
  PauseCircle,
  X,
  ChefHat,
  XCircle,
  AlertTriangle,
  AlertCircle,
  Lock,
  Users,
  Copy,
  SlidersHorizontal,
} from 'lucide-react'
import {
  productService,
  type PublicMenuResponse,
  type PublicMenuDish,
} from '@/services/productService'
import {
  type CartItem,
  type DishCustomization,
  type SharedCartItem,
  type SharedCartResponse,
  getCartItemKey,
  parseCustomizationFromModifiers,
} from '@/types/cart'
import { DishCard } from './components/DishCard'
import { DishCustomizationModal } from './components/DishCustomizationModal'
import { Interactive3dModal } from './components/Interactive3dModal'
import { CartDrawer, RestaurantInfoModal, TableSelectorModal } from './components/MenuModals'
import { TableOrderStatusModal } from './components/TableOrderStatusModal'
import { tableOrderService, type LiveTableOrder } from '@/services/tableOrderService'
import { soundAlerts } from '@/utils/soundAlerts'

export function MenuPage() {
  const { slug } = useParams<{ slug: string }>()
  const [searchParams, setSearchParams] = useSearchParams()

  const [menu, setMenu] = useState<PublicMenuResponse | null>(null)
  const [loading, setLoading] = useState(true)

  // Table number state
  const [table, setTable] = useState<string>(
    () => searchParams.get('table') || localStorage.getItem('ar_smart_menu_table') || '',
  )

  // Check whether restaurant has configured tables and if current table is valid
  const hasConfiguredTables = Boolean(menu?.availableTables && menu.availableTables.length > 0)

  const isTableValid = useMemo(() => {
    if (!menu || !hasConfiguredTables) return true
    if (!table || !table.trim()) return false
    const cleanTable = table.replace(/\D/g, '') || table.trim().toLowerCase()
    return (menu.availableTables || []).some(
      (t) =>
        t === cleanTable ||
        t.toLowerCase() === table.trim().toLowerCase() ||
        `table ${t}` === table.trim().toLowerCase() ||
        `t-${t}` === table.trim().toLowerCase()
    )
  }, [menu, hasConfiguredTables, table])

  // Filters
  const [selectedCategory, setSelectedCategory] = useState('All')
  const [searchQuery, setSearchQuery] = useState('')
  const [dietary, setDietary] = useState<'all' | 'veg' | 'non-veg'>('all')
  const [popularOnly, setPopularOnly] = useState(false)
  const [arOnly, setArOnly] = useState(false)
  const [isFilterModalOpen, setIsFilterModalOpen] = useState(false)

  // Cart & Modals
  const [cart, setCart] = useState<Record<string, CartItem>>({})
  const cartRef = useRef<Record<string, CartItem>>({})
  cartRef.current = cart
  const allDishesRef = useRef<PublicMenuDish[]>([])
  const lastLocalEditTimestamp = useRef<number>(0)
  const [active3dDish, setActive3dDish] = useState<PublicMenuDish | null>(null)
  const [customizingDish, setCustomizingDish] = useState<PublicMenuDish | null>(null)
  const [isCartOpen, setIsCartOpen] = useState(false)
  const [isInfoOpen, setIsInfoOpen] = useState(false)
  const [isTableOpen, setIsTableOpen] = useState(false)
  const [toast, setToast] = useState<{ message: string; isError?: boolean } | null>(null)
  const toastTimer = useRef<number | null>(null)

  const showToast = (msg: string, isError?: boolean) => {
    if (toastTimer.current) clearTimeout(toastTimer.current)
    const errorFlag =
      isError !== undefined
        ? isError
        : msg.includes('⚠️') ||
          msg.includes('❌') ||
          msg.toLowerCase().includes('fail') ||
          msg.toLowerCase().includes('error') ||
          msg.toLowerCase().includes('occupied')
    setToast({ message: msg, isError: errorFlag })
    toastTimer.current = window.setTimeout(() => setToast(null), 3000)
  }

  // Table occupancy state when another customer has occupied this table
  const [isTableOccupiedByOther, setIsTableOccupiedByOther] = useState(false)
  const [occupiedMessage, setOccupiedMessage] = useState('')

  // Live Table Order Status Tracking (Round 1, Round 2, Round 3...)
  const [activeOrders, setActiveOrders] = useState<LiveTableOrder[]>([])
  const activePartyPin = useMemo(() => {
    return activeOrders.find((o) => o.partyPin)?.partyPin || null
  }, [activeOrders])
  const [isOrderStatusOpen, setIsOrderStatusOpen] = useState(false)
  const [isRefreshingOrders, setIsRefreshingOrders] = useState(false)
  const [isDeclinedBannerDismissed, setIsDeclinedBannerDismissed] = useState<boolean>(() => {
    return sessionStorage.getItem('ar_declined_dismissed') === 'true'
  })
  const previousOrdersCount = useRef(0)
  const knownOrderStatuses = useRef<Map<string, string>>(new Map())
  const isFirstOrderPoll = useRef(true)

  // Phase 2.4: Multiplayer Collaborative Table Cart State
  const myClientId = useRef(tableOrderService.getDinerClientId()).current
  const [dinerNickname, setDinerNickname] = useState<string>(() => tableOrderService.getDinerNickname())
  const [lastSharedBy, setLastSharedBy] = useState<string | undefined>(undefined)
  const lastSyncCartVersion = useRef<string>('')
  const isFirstCartSync = useRef(true)

  const applySharedCart = (sc?: SharedCartResponse | null, isFromPoll = false) => {
    // If response is missing, null, or has invalid items, do NOT wipe local cart!
    if (!sc || !Array.isArray(sc.items)) {
      return
    }

    setLastSharedBy(sc.lastUpdatedBy)

    const currentDishes = allDishesRef.current
    const localCartSnapshot = cartRef.current

    const remoteCartMap: Record<string, CartItem> = {}
    for (const item of sc.items) {
      const rawDishId = item.dishId || (item.id && item.id.includes('__') ? item.id.split('__')[0] : item.id)
      let dish = currentDishes.find(
        (d) => d.id === rawDishId || d.name.toLowerCase() === item.name.toLowerCase(),
      )
      // Check if we already have this dish loaded in local cart snapshot
      if (!dish && item.id && localCartSnapshot[item.id]?.dish) {
        dish = localCartSnapshot[item.id].dish
      }
      if (!dish && localCartSnapshot[rawDishId]?.dish) {
        dish = localCartSnapshot[rawDishId].dish
      }
      // If dish metadata is not available yet, create a robust fallback dish
      if (!dish) {
        dish = {
          id: rawDishId,
          name: item.name,
          pricePaise: Math.round(item.unitPrice * 100),
          vegStatus: 0,
          isSpicy: false,
          isBestseller: false,
          isNew: false,
          soldOutToday: false,
          photoUrls: item.imageUrl ? [item.imageUrl] : [],
          thumbnailUrl: item.imageUrl,
          has3dModel: false,
          dishSlug: item.name.toLowerCase().replace(/\s+/g, '-'),
        }
      }

      // Preserve full customization object (including selectedAddons)
      let customization: DishCustomization | undefined =
        (item.id && localCartSnapshot[item.id]?.customization) ||
        parseCustomizationFromModifiers(item.modifiers, item.notes)

      const finalKey = item.id || getCartItemKey(dish.id, customization)

      remoteCartMap[finalKey] = {
        id: finalKey,
        dish,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        addedBy: item.addedBy || 'Companion',
        clientId: item.clientId,
        customization,
      }
    }

    setCart((currentLocalCart) => {
      // If this call came from polling and user recently modified cart locally (< 3s),
      // do NOT let a stale poll wipe out in-flight local additions!
      const isRecentlyEditedLocally = Date.now() - lastLocalEditTimestamp.current < 3000
      if (isFromPoll && isRecentlyEditedLocally) {
        for (const [key, localItem] of Object.entries(currentLocalCart)) {
          if (!remoteCartMap[key] && (localItem.clientId === myClientId || !localItem.clientId)) {
            remoteCartMap[key] = localItem
          }
        }
      }

      const currentKeys = Object.keys(currentLocalCart)
      const remoteKeys = Object.keys(remoteCartMap)
      const isDifferent =
        currentKeys.length !== remoteKeys.length ||
        remoteKeys.some(
          (k) =>
            !currentLocalCart[k] ||
            currentLocalCart[k].quantity !== remoteCartMap[k].quantity ||
            currentLocalCart[k].addedBy !== remoteCartMap[k].addedBy,
        ) ||
        currentKeys.some((k) => !remoteCartMap[k])

      if (isDifferent) {
        if (
          isFromPoll &&
          !isFirstCartSync.current &&
          sc.lastClientId &&
          sc.lastClientId !== myClientId
        ) {
          showToast(`👥 Table cart updated by ${sc.lastUpdatedBy || 'Companion'}`)
        }
        isFirstCartSync.current = false
        return remoteCartMap
      }

      isFirstCartSync.current = false
      return currentLocalCart
    })
  }

  const fetchOrders = async (silent = false) => {
    if (!slug) return
    if (!silent) setIsRefreshingOrders(true)
    try {
      const res = await tableOrderService.fetchTableOrders(slug, table || 'Dine-in')
      setIsTableOccupiedByOther(res.isOccupiedByOther)
      if (res.isOccupiedByOther) {
        setOccupiedMessage(res.occupiedMessage || `Table ${table} is currently occupied by another customer.`)
        setActiveOrders([])
        setIsOrderStatusOpen(false)
        return
      } else {
        setOccupiedMessage('')
      }
      const orders = res.orders

      // Phase 2.4: Synchronize multiplayer table cart across diners
      if (table) {
        if (res.sharedCart) {
          const sc = res.sharedCart
          const remoteVersion = `${sc.updatedAt}_${sc.items?.length || 0}_${sc.lastClientId}_${sc.totalAmount}`
          if (remoteVersion !== lastSyncCartVersion.current || isFirstCartSync.current) {
            lastSyncCartVersion.current = remoteVersion
            applySharedCart(sc, true)
          }
        }
      }

      if (orders.length === 0 && !res.isOccupiedByOther) {
        if (isNewPartyClaimed) {
          setIsNewPartyClaimed(false)
          showToast(`🎉 Table ${table} verified! Your fresh session is ready.`)
        }
        setIsDeclinedBannerDismissed(false)
        sessionStorage.removeItem('ar_declined_dismissed')
        tableOrderService.clearStoredOrderIds(table)
        // If table was closed & paid by owner (orders transitioned from >0 to 0)
        if (previousOrdersCount.current > 0) {
          sessionStorage.removeItem('ar_order_round')
          sessionStorage.removeItem('ar_last_order_timestamp')
          sessionStorage.removeItem('ar_placed_order_ids')
          setIsOrderStatusOpen(false)
          setIsCartOpen(false)
          showToast('✨ Bill settled & table closed! View is fresh for new orders.')
          soundAlerts.playBillSettled()
        }
        knownOrderStatuses.current.clear()
      } else {
        if (orders.some((o) => o.status !== 'CANCELLED')) {
          setIsDeclinedBannerDismissed(false)
          sessionStorage.removeItem('ar_declined_dismissed')
        }

        // Real-time audio alerts for customer status changes
        if (!isFirstOrderPoll.current) {
          for (const o of orders) {
            const prevStatus = knownOrderStatuses.current.get(o.id)
            if (prevStatus && prevStatus !== o.status) {
              if (o.status === 'ACCEPTED') {
                soundAlerts.playOrderAccepted()
                showToast(`🍳 Kitchen accepted Round ${o.round || 1}! Cooking now...`)
              } else if (o.status === 'COMPLETED') {
                soundAlerts.playOrderServed()
                showToast(`✨ Round ${o.round || 1} is served! Enjoy your meal.`)
              } else if (o.status === 'CANCELLED') {
                soundAlerts.playOrderCancelled()
                showToast(`❌ Round ${o.round || 1} was cancelled.`)
              }
            }
          }
        }

        for (const o of orders) {
          knownOrderStatuses.current.set(o.id, o.status)
        }
      }
      isFirstOrderPoll.current = false
      previousOrdersCount.current = orders.length
      setActiveOrders(orders)
    } catch (e) {
      console.warn('Failed to poll table orders:', e)
    } finally {
      if (!silent) setIsRefreshingOrders(false)
    }
  }

  const [isJoiningTable, setIsJoiningTable] = useState(false)
  const [isJoinPinModalOpen, setIsJoinPinModalOpen] = useState(false)
  const [enteredPin, setEnteredPin] = useState('')
  const [pinErrorMessage, setPinErrorMessage] = useState<string | null>(null)
  const [isClaimingParty, setIsClaimingParty] = useState(false)
  const [isNewPartyClaimed, setIsNewPartyClaimed] = useState(false)

  const handleClaimNewParty = async () => {
    if (!slug || !table || isClaimingParty) return
    setIsClaimingParty(true)
    try {
      const res = await tableOrderService.claimNewParty(slug, table)
      if (res.success) {
        setIsNewPartyClaimed(true)
        showToast(`🔔 Waiter alerted: New party seated at Table ${table}!`)
      } else {
        showToast(`⚠️ ${res.message}`)
      }
    } catch (e: any) {
      showToast(`⚠️ ${e.message || 'Could not alert staff'}`)
    } finally {
      setIsClaimingParty(false)
    }
  }

  const handleJoinTableParty = () => {
    setEnteredPin('')
    setPinErrorMessage(null)
    setIsJoinPinModalOpen(true)
  }

  const submitJoinWithPin = async (e?: React.FormEvent) => {
    if (e) e.preventDefault()
    if (!slug || !table || isJoiningTable) return
    const pin = enteredPin.trim()
    if (pin.length !== 3) {
      setPinErrorMessage('Please enter the 3-digit Table PIN.')
      return
    }

    setIsJoiningTable(true)
    setPinErrorMessage(null)
    try {
      const res = await tableOrderService.joinTableParty(slug, table, pin)
      if (res.success) {
        setIsJoinPinModalOpen(false)
        setIsTableOccupiedByOther(false)
        setEnteredPin('')
        setActiveOrders(res.orders)
        showToast(`🤝 Joined Table ${table}! You can now view and add orders together.`)
      } else {
        setPinErrorMessage(res.message || 'Invalid Table PIN. Please check with your friends.')
      }
    } catch (e: any) {
      setPinErrorMessage(e.message || 'Could not join table')
    } finally {
      setIsJoiningTable(false)
    }
  }

  // Auto-join table party if opened via invite link containing ?pin=...
  useEffect(() => {
    const pinFromUrl = searchParams.get('pin')?.trim()
    if (!pinFromUrl || pinFromUrl.length !== 3 || !slug || !table) return
    if (!isTableOccupiedByOther || isJoiningTable) return

    setIsJoiningTable(true)
    tableOrderService
      .joinTableParty(slug, table, pinFromUrl)
      .then((res) => {
        if (res.success) {
          setIsJoinPinModalOpen(false)
          setIsTableOccupiedByOther(false)
          setActiveOrders(res.orders)
          showToast(`🤝 Joined Table ${table} party with PIN ${pinFromUrl}!`)
        }
      })
      .catch((err) => {
        console.warn('Auto join with PIN failed:', err)
      })
      .finally(() => {
        setIsJoiningTable(false)
      })
  }, [searchParams, slug, table, isTableOccupiedByOther, isJoiningTable])

  // Poll table orders every 2 seconds for real-time kitchen status updates
  const fetchOrdersRef = useRef(fetchOrders)
  fetchOrdersRef.current = fetchOrders

  useEffect(() => {
    if (!slug) return
    fetchOrdersRef.current(true)
    const interval = setInterval(() => {
      fetchOrdersRef.current(true)
    }, 2000)
    return () => clearInterval(interval)
  }, [slug, table])

  // Abandon unplaced draft cart when user closes or removes the tab before ordering
  useEffect(() => {
    const handleTabUnload = () => {
      // If customer has NOT placed any orders with the kitchen yet (activeOrders is empty):
      // Leaving/closing the tab abandons their draft cart so next guest gets an empty cart
      if (activeOrders.length === 0 && slug && table) {
        tableOrderService.abandonDraftCart(slug, table)
      }
    }

    window.addEventListener('pagehide', handleTabUnload)
    window.addEventListener('beforeunload', handleTabUnload)
    return () => {
      window.removeEventListener('pagehide', handleTabUnload)
      window.removeEventListener('beforeunload', handleTabUnload)
    }
  }, [slug, table, activeOrders.length])

  const totalOrderedItemsCount = useMemo(() => {
    return activeOrders
      .filter((o) => o.status !== 'CANCELLED')
      .reduce((sum, o) => sum + (o.items || []).reduce((is, i) => is + (i.quantity || 1), 0), 0)
  }, [activeOrders])

  const runningBillTotal = useMemo(() => {
    return activeOrders
      .filter((o) => o.status !== 'CANCELLED')
      .reduce((sum, o) => sum + (o.totalAmount || 0), 0)
  }, [activeOrders])

  const allOrdersCancelled = useMemo(() => {
    return activeOrders.length > 0 && activeOrders.every((o) => o.status === 'CANCELLED')
  }, [activeOrders])

  const hasAcceptedOrCompleted = useMemo(() => {
    return activeOrders.some((o) => o.status === 'ACCEPTED' || o.status === 'COMPLETED')
  }, [activeOrders])

  const nextRoundNumber = useMemo(() => {
    if (activeOrders.length === 0) return 1
    const maxRound = Math.max(...activeOrders.map((o) => o.round || 1))
    return maxRound + 1
  }, [activeOrders])

  const kitchenStatusSummary = useMemo(() => {
    if (activeOrders.length === 0) return null
    if (allOrdersCancelled) {
      return { status: 'CANCELLED', label: 'Order Declined', emoji: '❌' }
    }
    const nonCancelled = activeOrders.filter((o) => o.status !== 'CANCELLED')
    if (nonCancelled.some((o) => o.status === 'PENDING')) {
      return { status: 'PENDING', label: 'Sent to Kitchen', emoji: '⏳' }
    }
    if (nonCancelled.some((o) => o.status === 'ACCEPTED')) {
      return { status: 'ACCEPTED', label: 'Preparing', emoji: '🍳' }
    }
    if (nonCancelled.length > 0 && nonCancelled.every((o) => o.status === 'COMPLETED')) {
      return { status: 'COMPLETED', label: 'Served to Table', emoji: '✅' }
    }
    return { status: 'ACTIVE', label: 'Ordered', emoji: '🍽️' }
  }, [activeOrders, allOrdersCancelled])

  const hasNonCancelledOrders = useMemo(() => {
    return activeOrders.some((o) => o.status !== 'CANCELLED' && o.status !== 'PAID' && o.status !== 'SETTLED')
  }, [activeOrders])

  const isTableLocked = useMemo(() => {
    if (isTableOccupiedByOther) return false
    if (!table || !table.trim()) return false
    if (allOrdersCancelled) return false
    if (hasNonCancelledOrders) return true
    if (nextRoundNumber > 1) return true
    try {
      const storedRound = parseInt(sessionStorage.getItem('ar_order_round') || '1', 10)
      if (storedRound > 1) return true
      const storedIds = tableOrderService.getStoredOrderIds(table)
      if (storedIds && storedIds.length > 0) return true
    } catch {}
    return false
  }, [table, allOrdersCancelled, hasNonCancelledOrders, nextRoundNumber, isTableOccupiedByOther])

  // Sync table if URL parameter ?table=... changes (e.g. scanning/opening a different table QR code)
  useEffect(() => {
    const qTable = searchParams.get('table')
    if (qTable !== null && qTable !== table) {
      if (isTableLocked && table) {
        showToast(`🔒 Table is locked to Table ${table}. Ask staff to move tables.`)
        const params = new URLSearchParams(searchParams)
        params.set('table', table)
        setSearchParams(params, { replace: true })
        return
      }
      setTable(qTable)
      if (qTable) {
        localStorage.setItem('ar_smart_menu_table', qTable)
      } else {
        localStorage.removeItem('ar_smart_menu_table')
      }
      setActiveOrders([]) // Immediately wipe orders from previous table
    }
  }, [searchParams, isTableLocked, table, setSearchParams])

  const handleSelectTable = (newTable: string) => {
    if (isTableLocked && newTable !== table) {
      showToast(`🔒 Table is locked to Table ${table} while your active order is in progress.`)
      return
    }
    setTable(newTable)
    localStorage.setItem('ar_smart_menu_table', newTable)
    const params = new URLSearchParams(searchParams)
    params.set('table', newTable)
    setSearchParams(params, { replace: true })
    showToast(`📍 Seated at Table ${newTable}`)
  }

  const handleClearOrders = () => {
    setActiveOrders([])
    previousOrdersCount.current = 0
    setIsDeclinedBannerDismissed(false)
    sessionStorage.removeItem('ar_declined_dismissed')
    sessionStorage.setItem('ar_order_round', '1')
    sessionStorage.removeItem('ar_last_order_timestamp')
    sessionStorage.removeItem('ar_placed_order_ids')
    tableOrderService.clearStoredOrderIds(table)
    setIsOrderStatusOpen(false)
    showToast('✨ Cancelled order cleared! You can now place a fresh order.')
  }

  useEffect(() => {
    setLoading(true)
    productService
      .fetchMenuBySlug(slug || 'tasty-bites')
      .then((data) => setMenu(data))
      .catch((err) => {
        console.error('Failed to load menu:', err)
        setMenu(null)
      })
      .finally(() => setLoading(false))
  }, [slug])

  const allDishes = useMemo(() => menu?.categories.flatMap((c) => c.dishes) || [], [menu])
  allDishesRef.current = allDishes

  const categoriesWithCounts = useMemo(() => {
    if (!menu) return [{ name: 'All', count: 0 }]
    return [
      { name: 'All', count: allDishes.length },
      ...menu.categories.map((c) => ({ name: c.categoryName, count: c.dishes.length })),
    ]
  }, [menu, allDishes])

  const filteredDishes = useMemo(() => {
    let list = allDishes
    if (selectedCategory !== 'All') {
      const cat = menu?.categories.find((c) => c.categoryName === selectedCategory)
      list = cat ? cat.dishes : []
    }
    if (dietary === 'veg') list = list.filter((d) => d.vegStatus === 0 || d.vegStatus === 2)
    if (dietary === 'non-veg') list = list.filter((d) => d.vegStatus === 1)
    if (popularOnly) list = list.filter((d) => d.isBestseller)
    if (arOnly) list = list.filter((d) => d.has3dModel)
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase()
      list = list.filter((d) => d.name.toLowerCase().includes(q) || d.description?.toLowerCase().includes(q))
    }
    return list
  }, [allDishes, menu, selectedCategory, dietary, popularOnly, arOnly, searchQuery])

  const activeCheckboxFilterCount = (popularOnly ? 1 : 0) + (arOnly ? 1 : 0)
  const popularCount = useMemo(() => allDishes.filter((d) => d.isBestseller).length, [allDishes])
  const arCount = useMemo(() => allDishes.filter((d) => d.has3dModel).length, [allDishes])

  const handleNicknameChange = (newName: string) => {
    tableOrderService.setDinerNickname(newName)
    setDinerNickname(newName)
    showToast(`👤 Name updated to ${newName}`)
  }

  const handleClearCart = async () => {
    lastLocalEditTimestamp.current = Date.now()
    setCart({})
    if (slug && table) {
      await tableOrderService.clearSharedCart(slug, table)
    }
  }

  const handleQty = async (
    dish: PublicMenuDish,
    qty: number,
    customization?: DishCustomization,
    cartItemKey?: string,
  ) => {
    lastLocalEditTimestamp.current = Date.now()
    if (qty > 0 && isTableOccupiedByOther) {
      showToast(`⚠️ Table ${table} is occupied. Please select an available table.`)
      setIsTableOpen(true)
      return
    }

    // Determine target key:
    let targetKey = cartItemKey
    if (!targetKey) {
      targetKey = getCartItemKey(dish.id, customization)
    }

    // Find existing item in cart: check targetKey, fallback to dish.id if not found
    const existing = cartRef.current[targetKey] || (targetKey !== dish.id ? cartRef.current[dish.id] : undefined)

    // Effective customization: explicit customization argument takes precedence, then existing customization
    const effectiveCustomization = customization !== undefined ? customization : existing?.customization

    const basePrice = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0
    let addonsTotal = 0
    if (effectiveCustomization?.selectedAddons && effectiveCustomization.selectedAddons.length > 0) {
      addonsTotal = effectiveCustomization.selectedAddons.reduce((sum, a) => sum + a.price, 0)
    }
    const itemUnitPrice = basePrice + addonsTotal

    const finalKey = cartItemKey || getCartItemKey(dish.id, effectiveCustomization)

    // 1. Optimistic local update
    setCart((prev) => {
      const next = { ...prev }
      if (qty <= 0) {
        delete next[finalKey]
        if (finalKey !== dish.id && next[dish.id]) {
          delete next[dish.id]
        }
      } else {
        next[finalKey] = {
          id: finalKey,
          dish,
          quantity: qty,
          customization: effectiveCustomization,
          unitPrice: itemUnitPrice > 0 ? itemUnitPrice : (existing?.unitPrice ?? basePrice),
          addedBy: dinerNickname,
          clientId: myClientId,
        }
      }
      return next
    })

    // 2. Atomic communal table cart update (preserves companion dishes)
    if (slug && table && !isTableOccupiedByOther) {
      const mods: string[] = []
      if (effectiveCustomization?.spiceLevel) mods.push(`${effectiveCustomization.spiceLevel} Spicy`)
      if (effectiveCustomization?.dietary && effectiveCustomization.dietary !== 'Regular') {
        mods.push(effectiveCustomization.dietary)
      }
      if (effectiveCustomization?.selectedAddons) {
        for (const a of effectiveCustomization.selectedAddons) {
          mods.push(`${a.name} (+₹${a.price})`)
        }
      }

      const sharedItem: SharedCartItem = {
        id: finalKey,
        dishId: dish.id,
        name: dish.name,
        unitPrice: itemUnitPrice > 0 ? itemUnitPrice : (existing?.unitPrice ?? basePrice),
        quantity: qty,
        imageUrl: dish.thumbnailUrl || (dish.photoUrls && dish.photoUrls[0]),
        modifiers: mods.length > 0 ? mods : undefined,
        notes: effectiveCustomization?.notes?.trim() || undefined,
        clientId: myClientId,
        addedBy: dinerNickname,
      }

      try {
        const updated = await tableOrderService.setSharedCartItem(
          slug,
          table,
          sharedItem,
          qty,
          myClientId,
          dinerNickname,
        )
        if (updated) {
          applySharedCart(updated, false)
        }
      } catch (err) {
        console.warn('Failed to sync item to table cart:', err)
      }
    }
  }

  const getDishTotalQty = (dishId: string) => {
    return Object.values(cart)
      .filter((i) => i.dish.id === dishId)
      .reduce((sum, i) => sum + i.quantity, 0)
  }

  const handleDishCardQty = (dish: PublicMenuDish, newQty: number) => {
    const itemsForDish = Object.entries(cart).filter(([_, item]) => item.dish.id === dish.id)
    if (itemsForDish.length === 0) {
      handleQty(dish, newQty)
      return
    }

    if (itemsForDish.length === 1) {
      const [key, item] = itemsForDish[0]
      handleQty(dish, newQty, item.customization, key)
      return
    }

    // Multiple custom variations exist in cart
    const currentTotal = itemsForDish.reduce((sum, [_, item]) => sum + item.quantity, 0)
    if (newQty > currentTotal) {
      setCustomizingDish(dish)
      showToast(`Customize another ${dish.name} or adjust quantities in cart.`)
    } else {
      setIsCartOpen(true)
      showToast(`Choose which ${dish.name} to remove in cart.`)
    }
  }

  const cartItems = useMemo(() => Object.values(cart), [cart])
  const cartCount = cartItems.reduce((s, i) => s + i.quantity, 0)
  const cartTotal = cartItems.reduce(
    (s, i) => s + (i.unitPrice ?? (i.dish.pricePaise ? Math.round(i.dish.pricePaise / 100) : 0)) * i.quantity,
    0,
  )

  const handleSharePartyPin = async () => {
    if (!activePartyPin) return
    const inviteUrl = `${window.location.origin}${window.location.pathname}?table=${encodeURIComponent(table || '')}&pin=${activePartyPin}`
    const shareText = `Join our table at ${menu?.businessName || 'Restaurant'} (Table ${table})! 🍽️ Enter Table PIN: ${activePartyPin} or open this link:`
    if (navigator.share) {
      try {
        await navigator.share({
          title: `Join Table ${table} (PIN: ${activePartyPin})`,
          text: shareText,
          url: inviteUrl,
        })
        return
      } catch {}
    }
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(activePartyPin)
      showToast(`📋 Table PIN ${activePartyPin} copied! Share it with friends at Table ${table}`)
    } else {
      showToast(`👥 Table PIN: ${activePartyPin}`)
    }
  }

  const handleShare = async () => {
    const shareUrl = activePartyPin && table
      ? `${window.location.origin}${window.location.pathname}?table=${encodeURIComponent(table)}&pin=${activePartyPin}`
      : window.location.href
    const title = activePartyPin
      ? `Join Table ${table} at ${menu?.businessName || 'Restaurant'} (PIN: ${activePartyPin})`
      : (menu?.businessName || 'Restaurant Menu')
    if (navigator.share) {
      try {
        await navigator.share({ title, url: shareUrl })
        return
      } catch {}
    }
    navigator.clipboard.writeText(shareUrl)
    showToast(activePartyPin ? `🔗 Table ${table} invite link copied (includes PIN: ${activePartyPin})!` : '🔗 Menu link copied!')
  }

  if (loading) {
    return (
      <div className="h-full w-full bg-[#121319] text-white flex flex-col items-center justify-center gap-3">
        <div className="w-10 h-10 border-2 border-[#FF5353]/20 border-t-[#FF5353] rounded-full animate-spin" />
        <p className="text-xs text-gray-400">Loading 3D AR Menu...</p>
      </div>
    )
  }

  if (!menu) {
    return (
      <div className="h-full w-full bg-[#121319] text-white flex flex-col items-center justify-center p-6 text-center">
        <h2 className="text-lg font-bold">Restaurant Menu Not Found</h2>
        <p className="text-xs text-gray-400 mt-1 max-w-xs">
          We could not load dishes for this restaurant. Please verify the QR code.
        </p>
        <button
          type="button"
          onClick={() => window.location.reload()}
          className="mt-4 px-5 py-2 bg-[#FF5353] text-white rounded-full text-xs font-bold cursor-pointer"
        >
          Try Again
        </button>
      </div>
    )
  }

  if (menu.isBusinessActive === false) {
    return (
      <div className="h-full w-full bg-[#121319] text-white flex flex-col items-center justify-center p-6 text-center">
        <div className="w-16 h-16 rounded-full bg-amber-500/10 border border-amber-500/30 flex items-center justify-center mb-4">
          <PauseCircle className="w-8 h-8 text-amber-500" />
        </div>
        <h2 className="text-xl font-bold">{menu.businessName}</h2>
        <p className="text-sm text-amber-400 font-medium mt-1">Temporarily Closed / Paused</p>
        <p className="text-xs text-gray-400 mt-2 max-w-xs">
          {menu.inactiveMessage || 'This restaurant is currently closed or paused. Please check back later!'}
        </p>
      </div>
    )
  }

  const heroDish = allDishes.find((d) => d.has3dModel && d.thumbnailUrl) || allDishes[0]

  const renderDishGrid = (dishes: PublicMenuDish[]) => (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-2.5 sm:gap-3">
      {dishes.map((dish) => (
        <DishCard
          key={dish.id}
          dish={dish}
          quantity={getDishTotalQty(dish.id)}
          onQuantityChange={handleDishCardQty}
          onOpen3d={(d) => setActive3dDish(d)}
          onCustomize={(d) => setCustomizingDish(d)}
        />
      ))}
    </div>
  )


  return (
    <div className="h-full w-full bg-[#121319] text-white overflow-y-auto overscroll-contain">
      <div className={`w-full max-w-5xl mx-auto min-h-full ${cartCount > 0 ? 'pb-32' : 'pb-16'}`}>
        
        {/* ========================================================= */}
        {/* 1. RESTAURANT HERO HEADER (Directly from Reference Screen 2)*/}
        {/* ========================================================= */}
        <div className="relative menu-header-glass rounded-b-[2rem] p-5 sm:p-7 lg:p-9 overflow-hidden">
          
          {/* Top Nav: Back + Table Badge + Title + Action Icons */}
          <div className="flex items-center justify-between gap-3 mb-5 z-10 relative">
            <div className="flex items-center gap-2.5">
              <Link
                to="/home"
                className="w-10 h-10 rounded-full bg-[#242735] hover:bg-[#2e3244] text-gray-300 hover:text-white flex items-center justify-center transition shadow-sm"
                title="Home"
              >
                <ArrowLeft size={17} />
              </Link>

              <button
                type="button"
                onClick={() => {
                  if (isTableLocked) {
                    showToast(`🔒 Table is locked to Table ${table} for your active dining session.`)
                    return
                  }
                  setIsTableOpen(true)
                }}
                className={`border px-4 py-2 rounded-full text-xs font-bold flex items-center gap-2 cursor-pointer shadow-sm transition ${
                  isTableLocked
                    ? 'bg-[#242735] border-amber-500/40 text-amber-300'
                    : hasConfiguredTables && !isTableValid
                    ? 'bg-rose-500/20 hover:bg-rose-500/30 border-rose-500/50 text-rose-300 animate-pulse'
                    : 'bg-[#242735] hover:bg-[#2e3244] border-[#34384B] text-[#FF5353]'
                }`}
                title={
                  isTableLocked
                    ? `Table locked to Table ${table} for active dining session`
                    : 'Click to select table number'
                }
              >
                {isTableLocked ? (
                  <>
                    <Lock size={13} className="text-amber-400" />
                    <span>
                      {table
                        ? (table.toLowerCase().startsWith('table') || table.toLowerCase() === 'dine-in' || table.toLowerCase() === 'takeaway'
                            ? table
                            : `Table ${table}`)
                        : 'Table Locked'}
                    </span>
                    <span className="text-[10px] text-amber-400/80 font-normal">🔒</span>
                  </>
                ) : (
                  <>
                    <MapPin size={13} className={hasConfiguredTables && !isTableValid ? 'text-rose-400' : 'text-[#FF5353]'} />
                    <span>
                      {hasConfiguredTables && !isTableValid
                        ? `Invalid (${table ? `T-${table}` : 'No Table'})`
                        : table
                        ? (table.toLowerCase().startsWith('table') || table.toLowerCase() === 'dine-in' || table.toLowerCase() === 'takeaway'
                            ? table
                            : `Table ${table}`)
                        : (hasConfiguredTables ? 'Select Table' : 'Dine-in')}
                    </span>
                    <ChevronRight size={12} className="text-gray-400" />
                  </>
                )}
              </button>

              {!isTableOccupiedByOther && activeOrders.length > 0 && (
                <button
                  type="button"
                  onClick={() => setIsOrderStatusOpen(true)}
                  className="bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 text-emerald-400 px-3.5 py-2 rounded-full text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-sm transition animate-pulse"
                  title="Click to track live orders for this table"
                >
                  <span className="w-2 h-2 rounded-full bg-emerald-400" />
                  <span>{kitchenStatusSummary?.emoji} {totalOrderedItemsCount} Items ({kitchenStatusSummary?.label})</span>
                </button>
              )}

              {!isTableOccupiedByOther && activePartyPin && (
                <button
                  type="button"
                  onClick={handleSharePartyPin}
                  className="bg-amber-500/15 hover:bg-amber-500/25 border border-amber-500/40 text-amber-300 px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-sm transition"
                  title="Tap to copy Table PIN or share with friends"
                >
                  <Users size={12} className="text-amber-400" />
                  <span>PIN: <span className="font-mono font-black tracking-wider text-white bg-amber-500/30 px-1.5 py-0.5 rounded border border-amber-400/40">{activePartyPin}</span></span>
                  <Copy size={11} className="text-amber-400/80 ml-0.5" />
                </button>
              )}
            </div>

            <div className="flex items-center gap-2.5">
              <button
                type="button"
                onClick={() => setIsInfoOpen(true)}
                className="w-10 h-10 rounded-full bg-[#242735] hover:bg-[#2e3244] text-gray-300 hover:text-white flex items-center justify-center cursor-pointer transition shadow-sm"
                title="Restaurant Details"
              >
                <Info size={17} />
              </button>
              <button
                type="button"
                onClick={handleShare}
                className="w-10 h-10 rounded-full bg-[#242735] hover:bg-[#2e3244] text-gray-300 hover:text-white flex items-center justify-center cursor-pointer transition shadow-sm"
                title="Share Menu"
              >
                <Share2 size={17} />
              </button>
            </div>
          </div>

          {/* Restaurant Title & Tagline with Hero Dish on Right (Reference Screen 2) */}
          <div className="flex items-center justify-between gap-5 pt-2 z-10 relative">
            <div className="flex-1 max-w-lg">
              <div className="flex items-center gap-2.5 flex-wrap">
                <h1 className="text-2xl sm:text-3xl lg:text-4xl font-black text-white tracking-tight">
                  {menu.businessName}
                </h1>
                <span className="w-5 h-5 rounded-full bg-[#20BF6B] text-white text-[11px] font-black inline-flex items-center justify-center shadow">
                  ✓
                </span>
              </div>

              <p className="text-xs sm:text-sm text-[#9CA3AF] mt-2 leading-relaxed">
                Your neighborhood favorite dining place serving authentic, handcrafted delicacies with premium fresh ingredients.
              </p>
            </div>

            {/* Circular Hero Dish Cutout on Right (Matching Screen 2 Reference) */}
            {heroDish?.thumbnailUrl && (
              <div
                onClick={() => heroDish.has3dModel && setActive3dDish(heroDish)}
                className="hidden sm:flex dish-plate-halo relative w-36 h-36 lg:w-44 lg:h-44 rounded-full overflow-hidden border-4 border-white/10 ring-4 ring-black/40 shadow-2xl bg-[#242735] flex-shrink-0 cursor-pointer group"
                title="Tap to view featured 3D dish"
              >
                <img
                  src={heroDish.thumbnailUrl}
                  alt={heroDish.name}
                  className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent flex items-end justify-center pb-2.5">
                  <span className="ar-shimmer-badge text-white text-[10px] font-black px-2.5 py-0.5 rounded-full flex items-center gap-1">
                    <Sparkles size={10} /> Featured 3D
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Invalid / Unselected Table Banner */}
        {hasConfiguredTables && !isTableValid && (
          <div className="mx-4 sm:mx-6 lg:mx-8 mt-4 p-4 rounded-2xl bg-gradient-to-r from-red-950/70 via-[#1C1820] to-rose-950/50 border border-red-500/40 text-red-200 shadow-xl flex items-start gap-3.5">
            <div className="p-2.5 rounded-xl bg-red-500/20 border border-red-500/30 text-red-400 shrink-0 mt-0.5">
              <XCircle className="w-5 h-5" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="font-bold text-white text-sm flex items-center gap-2">
                <span>{table ? `Table "${table}" Does Not Exist` : 'Table Not Selected'}</span>
                <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-red-500/20 text-red-300 border border-red-500/30">
                  Invalid QR / URL
                </span>
              </div>
              <p className="text-xs text-red-200/90 mt-1 leading-relaxed">
                {menu?.businessName} has configured <strong>Tables 1 to {menu?.availableTables?.[menu.availableTables.length - 1]}</strong>. Please select your table below to place orders:
              </p>
              <div className="flex flex-wrap items-center gap-2 mt-3">
                <span className="text-[11px] font-semibold text-red-300">Choose your table:</span>
                {menu?.availableTables?.map((tNum) => (
                  <button
                    key={tNum}
                    type="button"
                    onClick={() => handleSelectTable(tNum)}
                    className="px-3 py-1.5 text-xs font-black rounded-xl bg-[#EB4F16] hover:bg-[#FF6A3D] text-white shadow-md shadow-[#EB4F16]/20 border border-[#FF6A3D]/40 transition cursor-pointer"
                  >
                    Table {tNum}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Table Occupied Warning Banner */}
        {isTableValid && isTableOccupiedByOther && (
          <div className="mx-4 sm:mx-6 lg:mx-8 mt-4 p-4 rounded-2xl bg-amber-500/15 border border-amber-500/40 backdrop-blur-md flex items-start gap-3.5 shadow-lg shadow-amber-950/20 animate-in fade-in slide-in-from-top-2 duration-300">
            <div className="p-2.5 rounded-xl bg-amber-500/20 border border-amber-500/30 text-amber-400 shrink-0 mt-0.5">
              <AlertTriangle className="w-5 h-5" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="font-bold text-white text-sm flex items-center gap-2">
                <span>Table {table} is Occupied</span>
                <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30">
                  Not Available
                </span>
              </div>
              <p className="text-xs text-amber-200/90 mt-1 leading-relaxed">
                {occupiedMessage || `Table "${table}" currently has an active order.`} If you are dining with friends, join with PIN. If previous guests left, alert your server:
              </p>
              {isNewPartyClaimed ? (
                <div className="flex items-center gap-2 text-xs font-bold text-amber-300 bg-amber-500/20 border border-amber-500/40 rounded-xl px-3 py-2 mt-3 animate-pulse">
                  <span className="w-2 h-2 rounded-full bg-amber-400 inline-block animate-ping" />
                  <span>🔔 Waiter alerted: "New Party at Table {table}". Please wait while staff verifies to unlock this table.</span>
                </div>
              ) : (
                <div className="flex flex-wrap items-center gap-2 mt-3">
                  <button
                    type="button"
                    onClick={handleJoinTableParty}
                    disabled={isJoiningTable}
                    className="px-3.5 py-1.5 text-xs font-black rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-950/20 border border-emerald-400/40 transition cursor-pointer flex items-center gap-1.5"
                  >
                    <Users className="w-3.5 h-3.5" />
                    <span>Join Friends (Enter PIN)</span>
                  </button>
                  <button
                    type="button"
                    onClick={handleClaimNewParty}
                    disabled={isClaimingParty}
                    className="px-3.5 py-1.5 text-xs font-black rounded-xl bg-amber-500 hover:bg-amber-400 text-black shadow-md shadow-amber-950/20 border border-amber-300 transition cursor-pointer flex items-center gap-1.5"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-black" />
                    <span>{isClaimingParty ? 'Alerting Staff...' : 'New Party at Table (Reset)'}</span>
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsTableOpen(true)}
                    className="px-3 py-1.5 text-xs font-bold rounded-xl bg-white/10 hover:bg-white/15 text-white/90 border border-white/20 transition cursor-pointer"
                  >
                    Change Table
                  </button>
                </div>
              )}
            </div>
          </div>
        )}

        {/* ========================================================= */}
        {/* 2. SEARCH BAR & QUICK FILTERS (Matching Reference Screen 3)*/}
        {/* ========================================================= */}
        <div
          className="px-4 sm:px-6 lg:px-8"
          style={{ marginTop: '28px', marginBottom: '12px' }}
        >
          <div className="flex items-center gap-3">
            <div className="relative flex-1">
              <Search
                size={18}
                className="absolute top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"
                style={{ left: '18px' }}
              />
              <input
                type="text"
                placeholder="Search dishes or drinks..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ paddingLeft: '56px', paddingRight: '44px' }}
                className="search-input-glass w-full h-12 rounded-full text-xs sm:text-sm text-white placeholder-gray-400 outline-none"
              />
              {searchQuery && (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white p-1 cursor-pointer transition"
                  aria-label="Clear search"
                >
                  <X size={15} />
                </button>
              )}
            </div>

            {/* Veg / Non-Veg Radio Group */}
            <div className="flex items-center bg-[#1C1E28] border border-[#2D3142] p-1 rounded-full h-12 shadow-md flex-shrink-0">
              {/* Veg Option */}
              <button
                type="button"
                role="radio"
                aria-checked={dietary === 'veg'}
                onClick={() => setDietary(dietary === 'veg' ? 'all' : 'veg')}
                className={`px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1.5 transition cursor-pointer ${
                  dietary === 'veg'
                    ? 'bg-[#20BF6B] text-white shadow-sm'
                    : 'text-gray-400 hover:text-white'
                }`}
                title={dietary === 'veg' ? 'Click to show all' : 'Show Vegetarian only'}
              >
                <span
                  className={`w-3.5 h-3.5 border-[1.5px] rounded-[3px] inline-flex items-center justify-center ${
                    dietary === 'veg' ? 'border-white bg-white/20' : 'border-[#20BF6B] bg-[#20BF6B]/15'
                  }`}
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${dietary === 'veg' ? 'bg-white' : 'bg-[#20BF6B]'}`} />
                </span>
                <span>Veg</span>
              </button>

              {/* Non-Veg Option */}
              <button
                type="button"
                role="radio"
                aria-checked={dietary === 'non-veg'}
                onClick={() => setDietary(dietary === 'non-veg' ? 'all' : 'non-veg')}
                className={`px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1.5 transition cursor-pointer ${
                  dietary === 'non-veg'
                    ? 'bg-[#FF5353] text-white shadow-sm'
                    : 'text-gray-400 hover:text-white'
                }`}
                title={dietary === 'non-veg' ? 'Click to show all' : 'Show Non-Vegetarian only'}
              >
                <span
                  className={`w-3.5 h-3.5 border-[1.5px] rounded-[3px] inline-flex items-center justify-center ${
                    dietary === 'non-veg' ? 'border-white bg-white/20' : 'border-[#FF5353] bg-[#FF5353]/15'
                  }`}
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${dietary === 'non-veg' ? 'bg-white' : 'bg-[#FF5353]'}`} />
                </span>
                <span>Non-Veg</span>
              </button>
            </div>

            {/* Checkbox Filter Icon Button (Row 1) */}
            <button
              type="button"
              onClick={() => setIsFilterModalOpen(true)}
              className={`h-12 px-3 sm:px-3.5 rounded-full border flex items-center justify-center gap-1.5 cursor-pointer transition shadow-md flex-shrink-0 ${
                activeCheckboxFilterCount > 0
                  ? 'bg-[#FF5353] border-[#FF5353] text-white shadow-lg shadow-[#FF5353]/30'
                  : 'bg-[#1C1E28] border-[#2D3142] text-gray-400 hover:text-white hover:border-gray-500'
              }`}
              title="More filters (Popular, 3D AR)"
              aria-label="Dish filters"
            >
              <SlidersHorizontal size={16} />
              <span className="hidden sm:inline text-xs font-bold">Filter</span>
              {activeCheckboxFilterCount > 0 && (
                <span className="w-4 h-4 rounded-full bg-white text-[#FF5353] text-[9px] font-extrabold flex items-center justify-center">
                  {activeCheckboxFilterCount}
                </span>
              )}
            </button>
          </div>
        </div>

        {/* ========================================================= */}
        {/* 3. STICKY CATEGORY PILLS BAR (Pure single-select categories) */}
        {/* ========================================================= */}
        <div className="sticky top-0 z-30 bg-[#121319]/90 backdrop-blur-xl border-b border-white/5 px-4 sm:px-6 lg:px-8 pt-2 pb-3.5 mb-4 flex gap-2.5 items-center overflow-x-auto no-scrollbar">
          {/* Checkbox Filter Icon Pill in category bar */}
          <button
            type="button"
            onClick={() => setIsFilterModalOpen(true)}
            className={`category-pill px-3.5 py-2 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer flex items-center gap-1.5 transition flex-shrink-0 ${
              activeCheckboxFilterCount > 0
                ? 'bg-[#FF5353] text-white shadow-md shadow-[#FF5353]/30 border border-[#FF5353]'
                : 'bg-[#1C1E28] border border-[#2D3142] text-gray-300 hover:text-white hover:border-gray-500'
            }`}
            title="Filter by Popular or 3D AR"
          >
            <SlidersHorizontal size={13} className={activeCheckboxFilterCount > 0 ? 'text-white' : 'text-gray-400'} />
            <span>Filter</span>
            {activeCheckboxFilterCount > 0 && (
              <span className="w-4 h-4 rounded-full font-extrabold text-[10px] bg-white text-[#FF5353] flex items-center justify-center">
                {activeCheckboxFilterCount}
              </span>
            )}
          </button>

          {/* Single-select category tabs (All, MainCourse, Starter, Beverage, Dessert...) */}
          {categoriesWithCounts.map(({ name, count }) => {
            const active = selectedCategory === name
            return (
              <button
                key={name}
                type="button"
                onClick={() => setSelectedCategory(name)}
                className={`category-pill px-4.5 py-2 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer flex items-center gap-2 ${
                  active ? 'category-pill-active' : 'category-pill-inactive'
                }`}
              >
                <span>{name}</span>
                <span
                  className={`text-[10px] px-1.5 py-0.5 rounded-full font-bold ${
                    active ? 'bg-white/25 text-white' : 'bg-[#252837] text-gray-400'
                  }`}
                >
                  {count}
                </span>
              </button>
            )
          })}
        </div>

        {/* Active Filter Chips (Instant removal when Popular or 3D AR is active) */}
        {activeCheckboxFilterCount > 0 && (
          <div className="px-4 sm:px-6 lg:px-8 -mt-2 mb-4 flex items-center gap-2 flex-wrap">
            <span className="text-[11px] text-gray-400 font-medium">Active filters:</span>
            {popularOnly && (
              <button
                type="button"
                onClick={() => setPopularOnly(false)}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#FF5353]/15 border border-[#FF5353]/40 text-[#FF5353] text-xs font-bold hover:bg-[#FF5353]/25 cursor-pointer transition"
                title="Remove Popular filter"
              >
                <span>🔥 Popular</span>
                <X size={12} />
              </button>
            )}
            {arOnly && (
              <button
                type="button"
                onClick={() => setArOnly(false)}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#8B5CF6]/15 border border-[#8B5CF6]/40 text-[#A78BFA] text-xs font-bold hover:bg-[#8B5CF6]/25 cursor-pointer transition"
                title="Remove 3D AR filter"
              >
                <Sparkles size={11} />
                <span>3D AR Only</span>
                <X size={12} />
              </button>
            )}
            <button
              type="button"
              onClick={() => {
                setPopularOnly(false)
                setArOnly(false)
              }}
              className="text-xs text-gray-400 hover:text-white underline cursor-pointer ml-1"
            >
              Clear
            </button>
          </div>
        )}

        {/* ========================================================= */}
        {/* 4. DISHES RESPONSIVE LIST (Directly from Reference Screen 2)*/}
        {/* Mobile: 1 Column | Tablet & Desktop: 2 Balanced Columns    */}
        {/* ========================================================= */}
        <div className="px-4 sm:px-6 lg:px-8 pb-12">
          {filteredDishes.length === 0 ? (
            <div className="text-center py-16 bg-[#1C1E28] border border-[#2D3142] rounded-3xl p-8 text-gray-400 space-y-3 max-w-md mx-auto shadow-lg">
              <div className="text-3xl">🔍</div>
              <p className="text-sm font-bold text-white">No dishes found</p>
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('')
                  setDietary('all')
                  setPopularOnly(false)
                  setArOnly(false)
                  setSelectedCategory('All')
                }}
                className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-[#252837] text-xs font-bold text-white hover:bg-[#34384B] cursor-pointer transition shadow"
              >
                <RotateCcw size={12} />
                <span>Reset Filters</span>
              </button>
            </div>
          ) : selectedCategory === 'All' && !searchQuery.trim() && !arOnly && !popularOnly && dietary === 'all' ? (
            <div className="space-y-10">
              {menu.categories.map((cat) => {
                const catDishes = cat.dishes
                if (catDishes.length === 0) return null
                return (
                  <div key={cat.categoryName} className="scroll-mt-24">
                    <div className="flex items-center justify-between mb-4 pb-2 border-b border-white/10">
                      <div className="flex items-center gap-2.5">
                        <h2 className="text-lg sm:text-xl font-black text-white tracking-tight">
                          {cat.categoryName}
                        </h2>
                        <span className="text-xs px-2.5 py-0.5 rounded-full bg-[#242735] text-gray-300 font-bold border border-[#34384B]">
                          {catDishes.length}
                        </span>
                      </div>
                      <button
                        type="button"
                        onClick={() => setSelectedCategory(cat.categoryName)}
                        className="text-xs text-[#FF5353] hover:text-[#ff7043] font-bold flex items-center gap-1 cursor-pointer transition"
                      >
                        <span>View only {cat.categoryName}</span>
                        <ChevronRight size={13} />
                      </button>
                    </div>
                    {renderDishGrid(catDishes)}
                  </div>
                )
              })}
            </div>
          ) : (
            <div>
              {selectedCategory !== 'All' && (
                <div className="flex items-center justify-between mb-5 pb-2 border-b border-white/10">
                  <div className="flex items-center gap-2.5">
                    <h2 className="text-lg sm:text-xl font-black text-white tracking-tight">
                      {selectedCategory}
                    </h2>
                    <span className="text-xs px-2.5 py-0.5 rounded-full bg-[#242735] text-[#FF5353] font-bold border border-[#34384B]">
                      {filteredDishes.length} dishes
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setSelectedCategory('All')}
                    className="text-xs text-gray-400 hover:text-white font-medium cursor-pointer transition"
                  >
                    ← View full menu
                  </button>
                </div>
              )}
              {searchQuery.trim() && (
                <div className="mb-4 text-xs text-gray-400">
                  Found <span className="font-bold text-white">{filteredDishes.length}</span> results for &ldquo;{searchQuery}&rdquo;
                </div>
              )}
              {renderDishGrid(filteredDishes)}
            </div>
          )}
        </div>
      </div>

      {/* ========================================================= */}
      {/* 5. FLOATING BOTTOM BAR (Cart CTA or Live Order Tracker)   */}
      {/* ========================================================= */}
      {cartCount > 0 ? (
        <div className="floating-cart-glass fixed bottom-4 inset-x-4 max-w-xl mx-auto z-40 p-3.5 rounded-2xl">
          <div className="flex items-center justify-between gap-3">
            <div
              onClick={() => setIsCartOpen(true)}
              className="flex items-center gap-3 cursor-pointer"
            >
              <div className="relative w-11 h-11 rounded-xl bg-gradient-to-br from-[#FF5353] to-[#FF7043] text-white flex items-center justify-center shadow-lg shadow-[#FF5353]/30">
                <ShoppingBag size={20} />
                <span className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white text-[#FF5353] text-[11px] font-black flex items-center justify-center shadow">
                  {cartCount}
                </span>
              </div>
              <div>
                <p className="text-[11px] text-gray-400 uppercase font-bold tracking-wide flex items-center gap-1.5">
                  {table ? (
                    <>
                      <span className="inline-flex items-center gap-1 text-emerald-400 font-bold">
                        <Users size={12} /> Table {table} Cart
                      </span>
                      <span>• {cartCount} items</span>
                    </>
                  ) : (
                    `${cartCount} items in cart`
                  )}
                </p>
                <p className="text-lg font-black text-white">₹{cartTotal.toLocaleString('en-IN')}</p>
              </div>
            </div>

            <button
              type="button"
              onClick={() => setIsCartOpen(true)}
              className="btn-order-coral px-6 py-2.5 text-white text-xs sm:text-sm font-bold rounded-full flex items-center gap-1.5 cursor-pointer shadow-lg"
            >
              <span>View Cart</span>
              <ChevronRight size={15} />
            </button>
          </div>
        </div>
      ) : !isTableOccupiedByOther && activeOrders.length > 0 && !(allOrdersCancelled && isDeclinedBannerDismissed) ? (
        <div className={`floating-cart-glass fixed bottom-4 inset-x-4 max-w-xl mx-auto z-40 p-3.5 rounded-2xl border backdrop-blur-md shadow-2xl ${
          allOrdersCancelled
            ? 'border-rose-500/30 bg-[#20181A]/95'
            : 'border-emerald-500/30 bg-[#161A1D]/95'
        }`}>
          <div className="flex items-center justify-between gap-3">
            <div
              onClick={() => setIsOrderStatusOpen(true)}
              className="flex items-center gap-3 cursor-pointer flex-1 min-w-0"
            >
              <div className={`relative w-11 h-11 shrink-0 rounded-xl text-white flex items-center justify-center shadow-lg ${
                allOrdersCancelled
                  ? 'bg-gradient-to-br from-rose-500 to-red-600 shadow-rose-500/30'
                  : 'bg-gradient-to-br from-emerald-500 to-teal-600 shadow-emerald-500/30'
              }`}>
                {allOrdersCancelled ? (
                  <XCircle size={20} />
                ) : (
                  <ChefHat size={20} className="animate-pulse" />
                )}
                {!allOrdersCancelled && (
                  <span className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white text-emerald-600 text-[11px] font-black flex items-center justify-center shadow">
                    {totalOrderedItemsCount}
                  </span>
                )}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-1.5 flex-wrap">
                  <span className={`text-xs font-black uppercase tracking-wide truncate ${
                    allOrdersCancelled ? 'text-rose-400' : 'text-emerald-400'
                  }`}>
                    {kitchenStatusSummary?.emoji} {kitchenStatusSummary?.label}
                  </span>
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-white/10 text-gray-300 font-semibold shrink-0">
                    {table ? (table.toLowerCase().startsWith('table') ? table : `Table ${table}`) : 'Table'}
                  </span>
                  {activePartyPin && (
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleSharePartyPin()
                      }}
                      className="text-[10px] px-2 py-0.5 rounded-full bg-amber-500/20 hover:bg-amber-500/30 border border-amber-400/40 text-amber-300 font-mono font-bold flex items-center gap-1 transition cursor-pointer shrink-0"
                      title="Tap to copy Table PIN"
                    >
                      <Users size={10} className="text-amber-400" />
                      <span>PIN: <strong>{activePartyPin}</strong></span>
                      <Copy size={9} />
                    </button>
                  )}
                </div>
                <p className="text-xs font-semibold text-gray-200 mt-0.5 truncate">
                  {allOrdersCancelled
                    ? `Previous order declined • Tap to order Round ${nextRoundNumber}`
                    : kitchenStatusSummary?.status === 'PENDING'
                    ? `${totalOrderedItemsCount} items • ₹${runningBillTotal.toLocaleString('en-IN')} (Can cancel before kitchen accepts)`
                    : kitchenStatusSummary?.status === 'ACCEPTED'
                    ? `Preparing dishes • Cannot cancel after acceptance`
                    : `${totalOrderedItemsCount} items ordered • ₹${runningBillTotal.toLocaleString('en-IN')}`}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <button
                type="button"
                onClick={() => setIsOrderStatusOpen(true)}
                className={`px-4 sm:px-5 py-2.5 text-white text-xs font-bold rounded-full flex items-center gap-1.5 cursor-pointer shadow-lg ${
                  allOrdersCancelled
                    ? 'bg-gradient-to-r from-[#FF5353] to-[#FF7043] hover:from-[#ff4040] hover:to-[#ff6233] shadow-[#FF5353]/25'
                    : 'bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 shadow-emerald-500/25'
                }`}
              >
                <span>{allOrdersCancelled ? `Order Round ${nextRoundNumber}` : 'Track Order'}</span>
                <ChevronRight size={15} />
              </button>

              {allOrdersCancelled && (
                <button
                  type="button"
                  title="Dismiss alert"
                  onClick={(e) => {
                    e.stopPropagation()
                    setIsDeclinedBannerDismissed(true)
                    sessionStorage.setItem('ar_declined_dismissed', 'true')
                  }}
                  className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-gray-300 hover:text-white flex items-center justify-center cursor-pointer transition-colors"
                >
                  <X size={15} />
                </button>
              )}
            </div>
          </div>
        </div>
      ) : null}

      {/* Modals */}
      {active3dDish && (
        <Interactive3dModal
          dish={active3dDish}
          quantity={getDishTotalQty(active3dDish.id)}
          onClose={() => setActive3dDish(null)}
          onQuantityChange={handleDishCardQty}
          onAddedToCart={(d) => showToast(`✨ Added "${d.name}"`)}
        />
      )}

      <CartDrawer
        isOpen={isCartOpen}
        items={cartItems}
        tableNumber={table}
        restaurantName={menu.businessName}
        menuSlug={slug || ''}
        activeOrdersCount={totalOrderedItemsCount}
        nextRound={nextRoundNumber}
        allCancelled={allOrdersCancelled}
        canRequestBill={hasAcceptedOrCompleted}
        myClientId={myClientId}
        dinerNickname={dinerNickname}
        onNicknameChange={handleNicknameChange}
        lastSharedBy={lastSharedBy}
        onOpenOrderStatus={() => setIsOrderStatusOpen(true)}
        onOrderPlaced={(order) => {
          soundAlerts.playOrderPlaced()
          setIsDeclinedBannerDismissed(false)
          sessionStorage.removeItem('ar_declined_dismissed')
          setCart({})
          setActiveOrders((prev) => {
            const exists = prev.some((o) => o.id === order.id)
            return exists ? prev.map((o) => (o.id === order.id ? order : o)) : [...prev, order]
          })
          setIsOrderStatusOpen(true)
          if (order.partyPin) {
            showToast(`🍳 Round ${order.round} placed! Table PIN: ${order.partyPin} (share with friends)`)
          } else {
            showToast(`🍳 Round ${order.round} sent to kitchen! Tracking status...`)
          }
          fetchOrders(true)
        }}
        onClose={() => setIsCartOpen(false)}
        onQuantityChange={handleQty}
        onClearCart={handleClearCart}
        onChangeTable={() => {
          if (isTableLocked) {
            showToast(`🔒 Table is locked to Table ${table} for your active dining session.`)
            return
          }
          setIsCartOpen(false)
          setIsTableOpen(true)
        }}
        isTableValid={isTableValid}
        isTableOccupied={isTableOccupiedByOther}
        occupiedMessage={occupiedMessage}
        isTableLocked={isTableLocked}
        onCustomizeDish={(d) => setCustomizingDish(d)}
      />

      <TableOrderStatusModal
        isOpen={isOrderStatusOpen && !isTableOccupiedByOther}
        onClose={() => setIsOrderStatusOpen(false)}
        orders={activeOrders}
        restaurantName={menu.businessName}
        tableNumber={table}
        slug={slug}
        upiId={menu.upiId}
        isRefreshing={isRefreshingOrders}
        onRefresh={() => fetchOrders(false)}
        onOrderMore={() => {
          setIsOrderStatusOpen(false)
          showToast(`Browse menu to add dishes for Round ${nextRoundNumber}`)
        }}
        onReorderItems={(reorderList) => {
          setCart((prev) => {
            const next = { ...prev }
            reorderList.forEach((item) => {
              const rawDishId = item.id.includes('__') ? item.id.split('__')[0] : item.id
              const dish = allDishes.find((d) => d.id === rawDishId || d.name.toLowerCase() === item.name.toLowerCase())
              if (dish) {
                const custom = (item as any).modifiers || (item as any).notes
                  ? parseCustomizationFromModifiers((item as any).modifiers, (item as any).notes)
                  : undefined
                const targetKey = item.id || getCartItemKey(dish.id, custom)
                const basePrice = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0
                const addonsTotal = custom?.selectedAddons?.reduce((s, a) => s + a.price, 0) ?? 0
                next[targetKey] = {
                  id: targetKey,
                  dish,
                  quantity: item.quantity || 1,
                  customization: custom,
                  unitPrice: basePrice + addonsTotal,
                  addedBy: dinerNickname,
                  clientId: myClientId,
                }
              }
            })
            return next
          })
          setIsOrderStatusOpen(false)
          setIsCartOpen(true)
          showToast(`🛒 Re-ordered dishes added to cart! Tap Send to submit Round ${nextRoundNumber}.`)
        }}
        onBillRequested={() => {
          soundAlerts.playBillRequested()
          fetchOrders(true)
          showToast('🔔 Bill requested! Restaurant staff notified.')
        }}
        onClearOrders={handleClearOrders}
        wifiName={menu.wifiName}
        wifiPassword={menu.wifiPassword}
      />

      <RestaurantInfoModal
        isOpen={isInfoOpen}
        businessName={menu.businessName}
        city={menu.city}
        address={menu.address}
        whatsAppNumber={menu.whatsAppNumber}
        wifiName={menu.wifiName}
        wifiPassword={menu.wifiPassword}
        onClose={() => setIsInfoOpen(false)}
      />

      <TableSelectorModal
        isOpen={isTableOpen}
        currentTable={table}
        availableTables={menu.availableTables}
        onClose={() => setIsTableOpen(false)}
        onSelectTable={handleSelectTable}
        isLocked={isTableLocked}
        lockedMessage={`Table is locked to Table ${table} for your active dining session. Please ask restaurant staff if you need to move tables.`}
      />

      {/* Dish Customization & Add-ons Modal */}
      <DishCustomizationModal
        isOpen={!!customizingDish}
        dish={customizingDish}
        initialCustomization={undefined}
        onClose={() => setCustomizingDish(null)}
        onConfirm={(dish, qty, custom) => {
          const targetKey = getCartItemKey(dish.id, custom)
          const existingQty = cart[targetKey]?.quantity || 0
          handleQty(dish, existingQty + qty, custom, targetKey)
          showToast(`✨ ${qty > 1 ? `${qty}x ` : ''}${dish.name} customized & added to cart!`)
        }}
      />

      {/* 3-Digit Table Party PIN Modal */}
      {isJoinPinModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
          <div className="w-full max-w-sm bg-[#181920] border border-[#2B2C38] rounded-3xl p-6 shadow-2xl relative text-center">
            <div className="w-12 h-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center mx-auto mb-3 text-emerald-400">
              <Users size={24} />
            </div>
            <h3 className="text-lg font-black text-white">Join Table {table}</h3>
            <p className="text-xs text-gray-300 mt-1.5 leading-relaxed">
              Enter the <span className="font-bold text-amber-400">3-digit PIN</span> shown on your table mate's screen to view and add orders together.
            </p>

            <form onSubmit={submitJoinWithPin} className="mt-5 space-y-4">
              <div>
                <input
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]*"
                  maxLength={3}
                  value={enteredPin}
                  onChange={(e) => {
                    const val = e.target.value.replace(/\D/g, '').slice(0, 3)
                    setEnteredPin(val)
                    if (pinErrorMessage) setPinErrorMessage(null)
                  }}
                  placeholder="•••"
                  autoFocus
                  className="w-36 text-center text-3xl font-mono font-black tracking-[0.5em] px-4 py-2.5 rounded-2xl bg-[#121319] border-2 border-emerald-500/40 text-emerald-300 focus:outline-none focus:border-emerald-400 focus:ring-4 focus:ring-emerald-500/20 placeholder:text-gray-600 transition"
                />
              </div>

              {pinErrorMessage && (
                <p className="text-xs text-rose-400 font-semibold bg-rose-500/10 border border-rose-500/20 rounded-xl px-3 py-2">
                  {pinErrorMessage}
                </p>
              )}

              <div className="grid grid-cols-2 gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    setIsJoinPinModalOpen(false)
                    setEnteredPin('')
                    setPinErrorMessage(null)
                  }}
                  className="w-full py-2.5 px-4 rounded-xl bg-[#23242E] hover:bg-[#2C2D3A] text-gray-300 text-xs font-bold transition cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isJoiningTable || enteredPin.length !== 3}
                  className="w-full py-2.5 px-4 rounded-xl bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-black transition cursor-pointer shadow-lg shadow-emerald-950/30 flex items-center justify-center gap-1.5"
                >
                  {isJoiningTable ? 'Verifying...' : 'Join Table'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* Checkbox Filter Modal Dialog (Popular & 3D AR Only)      */}
      {/* ========================================================= */}
      {isFilterModalOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in duration-200"
          onClick={() => setIsFilterModalOpen(false)}
          role="dialog"
          aria-modal="true"
          aria-labelledby="filter-dialog-title"
        >
          <div
            className="w-full max-w-sm bg-[#1C1E28] border border-[#2D3142] rounded-3xl p-5 shadow-2xl space-y-4 animate-in zoom-in-95 duration-150"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between pb-3 border-b border-[#2D3142]">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-full bg-[#FF5353]/15 flex items-center justify-center text-[#FF5353]">
                  <SlidersHorizontal size={16} />
                </div>
                <div>
                  <h3 id="filter-dialog-title" className="text-sm font-bold text-white">
                    Dish Filters
                  </h3>
                  <p className="text-[11px] text-gray-400">
                    Select checkboxes to filter menu
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setIsFilterModalOpen(false)}
                className="text-gray-400 hover:text-white p-1 rounded-full transition cursor-pointer"
                aria-label="Close filters"
              >
                <X size={18} />
              </button>
            </div>

            {/* Checkbox Options */}
            <div className="space-y-2.5">
              {/* Checkbox 1: Popular Dishes */}
              <label
                className={`flex items-center justify-between p-3.5 rounded-2xl border transition cursor-pointer select-none ${
                  popularOnly
                    ? 'bg-[#FF5353]/15 border-[#FF5353] text-white shadow-sm'
                    : 'bg-[#141620] border-[#2A2D3C] text-gray-300 hover:border-gray-500'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`w-5 h-5 rounded-md border flex items-center justify-center transition flex-shrink-0 ${
                      popularOnly ? 'bg-[#FF5353] border-[#FF5353]' : 'border-gray-500 bg-[#1E202C]'
                    }`}
                  >
                    {popularOnly && <Check size={13} className="text-white stroke-[3]" />}
                  </div>
                  <input
                    type="checkbox"
                    className="sr-only"
                    checked={popularOnly}
                    onChange={(e) => setPopularOnly(e.target.checked)}
                  />
                  <div>
                    <div className="flex items-center gap-1.5 font-bold text-xs text-white">
                      <span>🔥 Popular Dishes</span>
                    </div>
                    <p className="text-[11px] text-gray-400 mt-0.5">Bestselling customer favorites</p>
                  </div>
                </div>
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#252837] text-gray-300">
                  {popularCount}
                </span>
              </label>

              {/* Checkbox 2: 3D AR Only */}
              <label
                className={`flex items-center justify-between p-3.5 rounded-2xl border transition cursor-pointer select-none ${
                  arOnly
                    ? 'bg-[#8B5CF6]/15 border-[#8B5CF6] text-white shadow-sm'
                    : 'bg-[#141620] border-[#2A2D3C] text-gray-300 hover:border-gray-500'
                }`}
              >
                <div className="flex items-center gap-3">
                  <div
                    className={`w-5 h-5 rounded-md border flex items-center justify-center transition flex-shrink-0 ${
                      arOnly ? 'bg-[#8B5CF6] border-[#8B5CF6]' : 'border-gray-500 bg-[#1E202C]'
                    }`}
                  >
                    {arOnly && <Check size={13} className="text-white stroke-[3]" />}
                  </div>
                  <input
                    type="checkbox"
                    className="sr-only"
                    checked={arOnly}
                    onChange={(e) => setArOnly(e.target.checked)}
                  />
                  <div>
                    <div className="flex items-center gap-1.5 font-bold text-xs text-white">
                      <Sparkles size={13} className="text-[#A78BFA]" />
                      <span>3D AR Only</span>
                    </div>
                    <p className="text-[11px] text-gray-400 mt-0.5">Interactive augmented reality 3D</p>
                  </div>
                </div>
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-[#252837] text-gray-300">
                  {arCount}
                </span>
              </label>
            </div>

            {/* Modal Footer */}
            <div className="pt-2 flex items-center justify-between border-t border-[#2D3142]">
              <div className="text-xs text-gray-400">
                Matches: <strong className="text-white">{filteredDishes.length}</strong> dishes
              </div>
              <div className="flex items-center gap-2">
                {activeCheckboxFilterCount > 0 && (
                  <button
                    type="button"
                    onClick={() => {
                      setPopularOnly(false)
                      setArOnly(false)
                    }}
                    className="text-xs font-semibold text-gray-400 hover:text-white px-3 py-1.5 rounded-full hover:bg-white/5 transition cursor-pointer"
                  >
                    Reset
                  </button>
                )}
                <button
                  type="button"
                  onClick={() => setIsFilterModalOpen(false)}
                  className="px-5 py-2 rounded-full bg-gradient-to-r from-[#FF5353] to-[#FF793F] text-white text-xs font-bold shadow-md cursor-pointer hover:opacity-95 transition"
                >
                  Apply Filters
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Floating Toast Notification - Positioned at Right Top */}
      {toast && (
        <div
          role="status"
          aria-live="polite"
          className={`fixed top-4 right-4 z-50 max-w-sm px-4 py-2.5 rounded-2xl text-xs font-bold shadow-2xl flex items-center gap-2.5 animate-in fade-in slide-in-from-top-2 duration-200 border backdrop-blur-md ${
            toast.isError
              ? 'bg-[#2A1519]/95 border-rose-500/40 text-rose-200 shadow-rose-950/40'
              : 'bg-[#15261D]/95 border-emerald-500/40 text-emerald-200 shadow-emerald-950/40'
          }`}
        >
          {toast.isError ? (
            <AlertCircle size={16} className="text-rose-400 shrink-0" />
          ) : (
            <Check size={16} className="text-emerald-400 shrink-0" />
          )}
          <span className="leading-snug">{toast.message}</span>
        </div>
      )}
    </div>
  )
}
