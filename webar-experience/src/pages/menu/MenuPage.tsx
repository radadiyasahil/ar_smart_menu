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
} from 'lucide-react'
import {
  productService,
  type PublicMenuResponse,
  type PublicMenuDish,
} from '@/services/productService'
import type { CartItem } from '@/types/cart'
import { DishCard } from './components/DishCard'
import { Interactive3dModal } from './components/Interactive3dModal'
import { CartDrawer, RestaurantInfoModal, TableSelectorModal } from './components/MenuModals'
import { TableOrderStatusModal } from './components/TableOrderStatusModal'
import { tableOrderService, type LiveTableOrder } from '@/services/tableOrderService'

export function MenuPage() {
  const { slug } = useParams<{ slug: string }>()
  const [searchParams, setSearchParams] = useSearchParams()

  const [menu, setMenu] = useState<PublicMenuResponse | null>(null)
  const [loading, setLoading] = useState(true)

  // Table number state
  const [table, setTable] = useState<string>(
    () => searchParams.get('table') || localStorage.getItem('ar_smart_menu_table') || '',
  )

  // Filters
  const [selectedCategory, setSelectedCategory] = useState('All')
  const [searchQuery, setSearchQuery] = useState('')
  const [dietary, setDietary] = useState<'all' | 'veg' | 'non-veg'>('all')
  const [popularOnly, setPopularOnly] = useState(false)
  const [arOnly, setArOnly] = useState(false)

  // Cart & Modals
  const [cart, setCart] = useState<Record<string, CartItem>>({})
  const [active3dDish, setActive3dDish] = useState<PublicMenuDish | null>(null)
  const [isCartOpen, setIsCartOpen] = useState(false)
  const [isInfoOpen, setIsInfoOpen] = useState(false)
  const [isTableOpen, setIsTableOpen] = useState(false)
  const [toast, setToast] = useState<string | null>(null)
  const toastTimer = useRef<number | null>(null)

  const showToast = (msg: string) => {
    if (toastTimer.current) clearTimeout(toastTimer.current)
    setToast(msg)
    toastTimer.current = window.setTimeout(() => setToast(null), 2500)
  }

  // Live Table Order Status Tracking (Round 1, Round 2, Round 3...)
  const [activeOrders, setActiveOrders] = useState<LiveTableOrder[]>([])
  const [isOrderStatusOpen, setIsOrderStatusOpen] = useState(false)
  const [isRefreshingOrders, setIsRefreshingOrders] = useState(false)

  const fetchOrders = async (silent = false) => {
    if (!slug) return
    if (!silent) setIsRefreshingOrders(true)
    try {
      const orders = await tableOrderService.fetchTableOrders(slug, table || 'Dine-in')
      setActiveOrders(orders)
    } catch (e) {
      console.warn('Failed to poll table orders:', e)
    } finally {
      if (!silent) setIsRefreshingOrders(false)
    }
  }

  // Poll table orders every 6 seconds for real-time kitchen status updates
  useEffect(() => {
    if (!slug) return
    fetchOrders(true)
    const interval = setInterval(() => {
      fetchOrders(true)
    }, 6000)
    return () => clearInterval(interval)
  }, [slug, table])

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

  const kitchenStatusSummary = useMemo(() => {
    if (activeOrders.length === 0) return null
    if (activeOrders.some((o) => o.status === 'PENDING')) {
      return { status: 'PENDING', label: 'Sent to Kitchen', emoji: '⏳' }
    }
    if (activeOrders.some((o) => o.status === 'ACCEPTED')) {
      return { status: 'ACCEPTED', label: 'Preparing', emoji: '🍳' }
    }
    if (activeOrders.every((o) => o.status === 'COMPLETED')) {
      return { status: 'COMPLETED', label: 'Served', emoji: '✅' }
    }
    return { status: 'ACTIVE', label: 'Ordered', emoji: '🍽️' }
  }, [activeOrders])

  const handleSelectTable = (newTable: string) => {
    setTable(newTable)
    localStorage.setItem('ar_smart_menu_table', newTable)
    const params = new URLSearchParams(searchParams)
    params.set('table', newTable)
    setSearchParams(params, { replace: true })
    showToast(`📍 Seated at Table ${newTable}`)
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

  const handleQty = (dish: PublicMenuDish, qty: number) => {
    setCart((prev) => {
      const next = { ...prev }
      if (qty <= 0) delete next[dish.id]
      else next[dish.id] = { dish, quantity: qty }
      return next
    })
  }

  const cartItems = useMemo(() => Object.values(cart), [cart])
  const cartCount = cartItems.reduce((s, i) => s + i.quantity, 0)
  const cartTotal = cartItems.reduce(
    (s, i) => s + (i.dish.pricePaise ? Math.round(i.dish.pricePaise / 100) : 0) * i.quantity,
    0,
  )

  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({ title: menu?.businessName, url: window.location.href })
        return
      } catch {}
    }
    navigator.clipboard.writeText(window.location.href)
    showToast('🔗 Menu link copied!')
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
    <div className="grid grid-cols-1 md:grid-cols-2 gap-5 sm:gap-6">
      {dishes.map((dish) => (
        <DishCard
          key={dish.id}
          dish={dish}
          quantity={cart[dish.id]?.quantity || 0}
          onQuantityChange={handleQty}
          onOpen3d={(d) => setActive3dDish(d)}
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
                onClick={() => setIsTableOpen(true)}
                className="bg-[#242735] hover:bg-[#2e3244] border border-[#34384B] text-[#FF5353] px-4 py-2 rounded-full text-xs font-bold flex items-center gap-2 cursor-pointer shadow-sm transition"
                title="Click to select table number"
              >
                <MapPin size={13} className="text-[#FF5353]" />
                <span>{table ? `Table ${table}` : 'Select Table'}</span>
                <ChevronRight size={12} className="text-gray-400" />
              </button>

              {activeOrders.length > 0 && (
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
          </div>
        </div>

        {/* ========================================================= */}
        {/* 3. STICKY CATEGORY PILLS BAR (Matching Reference Screen 2) */}
        {/* ========================================================= */}
        <div className="sticky top-0 z-30 bg-[#121319]/90 backdrop-blur-xl border-b border-white/5 px-4 sm:px-6 lg:px-8 pt-2 pb-3.5 mb-6 flex gap-2.5 overflow-x-auto no-scrollbar">
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

          <button
            type="button"
            onClick={() => setPopularOnly(!popularOnly)}
            className={`category-pill px-4.5 py-2 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer ${
              popularOnly ? 'category-pill-active' : 'category-pill-inactive'
            }`}
          >
            🔥 Popular
          </button>

          <button
            type="button"
            onClick={() => setArOnly(!arOnly)}
            className={`category-pill px-4.5 py-2 rounded-full text-xs font-bold whitespace-nowrap cursor-pointer flex items-center gap-1.5 ${
              arOnly ? 'category-pill-active' : 'category-pill-inactive'
            }`}
          >
            <Sparkles size={12} />
            <span>3D AR Only ({allDishes.filter((d) => d.has3dModel).length})</span>
          </button>
        </div>

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
                <p className="text-[11px] text-gray-400 uppercase font-bold tracking-wide">
                  {table ? `Table ${table} • ${cartCount} items in cart` : `${cartCount} items in cart`}
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
      ) : activeOrders.length > 0 ? (
        <div className="floating-cart-glass fixed bottom-4 inset-x-4 max-w-xl mx-auto z-40 p-3.5 rounded-2xl border border-emerald-500/30 bg-[#161A1D]/95 backdrop-blur-md shadow-2xl">
          <div className="flex items-center justify-between gap-3">
            <div
              onClick={() => setIsOrderStatusOpen(true)}
              className="flex items-center gap-3 cursor-pointer"
            >
              <div className="relative w-11 h-11 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white flex items-center justify-center shadow-lg shadow-emerald-500/30">
                <ChefHat size={20} className="animate-pulse" />
                <span className="absolute -top-1.5 -right-1.5 w-5 h-5 rounded-full bg-white text-emerald-600 text-[11px] font-black flex items-center justify-center shadow">
                  {totalOrderedItemsCount}
                </span>
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-black text-emerald-400 uppercase tracking-wide">
                    {kitchenStatusSummary?.emoji} {kitchenStatusSummary?.label}
                  </span>
                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-white/10 text-gray-300 font-semibold">
                    {table ? (table.toLowerCase().startsWith('table') ? table : `Table ${table}`) : 'Table'}
                  </span>
                </div>
                <p className="text-xs font-semibold text-gray-200 mt-0.5">
                  {totalOrderedItemsCount} items ordered • ₹{runningBillTotal.toLocaleString('en-IN')}
                </p>
              </div>
            </div>

            <button
              type="button"
              onClick={() => setIsOrderStatusOpen(true)}
              className="px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-white text-xs font-bold rounded-full flex items-center gap-1.5 cursor-pointer shadow-lg shadow-emerald-500/25"
            >
              <span>Track Order</span>
              <ChevronRight size={15} />
            </button>
          </div>
        </div>
      ) : null}

      {/* Modals */}
      {active3dDish && (
        <Interactive3dModal
          dish={active3dDish}
          quantity={cart[active3dDish.id]?.quantity || 0}
          onClose={() => setActive3dDish(null)}
          onQuantityChange={handleQty}
          onAddedToCart={(d) => showToast(`✨ Added "${d.name}"`)}
        />
      )}

      <CartDrawer
        isOpen={isCartOpen}
        items={cartItems}
        tableNumber={table}
        restaurantName={menu.businessName}
        whatsAppNumber={menu.whatsAppNumber}
        menuSlug={slug || ''}
        activeOrdersCount={activeOrders.length}
        onOpenOrderStatus={() => setIsOrderStatusOpen(true)}
        onOrderPlaced={(order) => {
          setActiveOrders((prev) => {
            const exists = prev.some((o) => o.id === order.id)
            return exists ? prev.map((o) => (o.id === order.id ? order : o)) : [...prev, order]
          })
          setIsOrderStatusOpen(true)
          showToast('🍳 Order sent to kitchen! Tracking live status...')
          fetchOrders(true)
        }}
        onClose={() => setIsCartOpen(false)}
        onQuantityChange={handleQty}
        onClearCart={() => {
          setCart({})
          showToast('Cart cleared')
        }}
        onChangeTable={() => {
          setIsCartOpen(false)
          setIsTableOpen(true)
        }}
      />

      <TableOrderStatusModal
        isOpen={isOrderStatusOpen}
        onClose={() => setIsOrderStatusOpen(false)}
        orders={activeOrders}
        restaurantName={menu.businessName}
        tableNumber={table}
        whatsAppNumber={menu.whatsAppNumber}
        isRefreshing={isRefreshingOrders}
        onRefresh={() => fetchOrders(false)}
        onOrderMore={() => setIsOrderStatusOpen(false)}
      />

      <RestaurantInfoModal
        isOpen={isInfoOpen}
        businessName={menu.businessName}
        city={menu.city}
        address={menu.address}
        whatsAppNumber={menu.whatsAppNumber}
        onClose={() => setIsInfoOpen(false)}
      />

      <TableSelectorModal
        isOpen={isTableOpen}
        currentTable={table}
        onClose={() => setIsTableOpen(false)}
        onSelectTable={handleSelectTable}
      />

      {/* Floating Toast Notification */}
      {toast && (
        <div className="fixed top-5 left-1/2 -translate-x-1/2 z-50 bg-[#1F2028] border border-[#2B2C38] text-white px-4 py-2 rounded-full text-xs font-bold shadow-2xl flex items-center gap-2 animate-in fade-in duration-200">
          <Check size={13} className="text-[#20BF6B]" />
          <span>{toast}</span>
        </div>
      )}
    </div>
  )
}
