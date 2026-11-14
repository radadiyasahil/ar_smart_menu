import { Sparkles, Plus, Minus, Flame, SlidersHorizontal } from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'

export function DishCard({
  dish,
  quantity,
  onQuantityChange,
  onOpen3d,
  onCustomize,
}: {
  dish: PublicMenuDish
  quantity: number
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number) => void
  onOpen3d: (dish: PublicMenuDish) => void
  onCustomize?: (dish: PublicMenuDish) => void
}) {
  const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
  const price = dish.pricePaise
    ? `₹${Math.round(dish.pricePaise / 100).toLocaleString('en-IN')}`
    : '—'

  return (
    <div className="menu-dish-card rounded-2xl p-2.5 sm:p-3 flex items-center gap-3 sm:gap-3.5 transition-all">
      {/* Left: Compact Dish Thumbnail */}
      <div
        onClick={() => dish.has3dModel && onOpen3d(dish)}
        className={`relative w-12 h-12 sm:w-13 sm:h-13 min-w-[48px] sm:min-w-[52px] rounded-xl overflow-hidden bg-[#242735] border border-white/10 shrink-0 flex items-center justify-center ${
          dish.has3dModel ? 'cursor-pointer group' : ''
        }`}
        title={dish.has3dModel ? 'Tap to view 3D model' : undefined}
      >
        {dish.thumbnailUrl ? (
          <img
            src={dish.thumbnailUrl}
            alt={dish.name}
            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
            loading="lazy"
            onError={(e) => {
              ;(e.target as HTMLElement).style.display = 'none'
            }}
          />
        ) : (
          <div className="text-xl sm:text-2xl">🍽️</div>
        )}

        {/* 3D AR Pill badge on thumbnail */}
        {dish.has3dModel && (
          <div className="ar-shimmer-badge absolute bottom-0 inset-x-0 text-white py-0.2 text-[8px] font-black flex items-center justify-center gap-0.5">
            <Sparkles size={8} />
            <span>3D</span>
          </div>
        )}
      </div>

      {/* Middle: Dish Details (Veg Dot, Name, Price, Category) */}
      <div className="flex-1 min-w-0 flex flex-col justify-center gap-0.5">
        {/* Row 1: Veg indicator + Dish Name + Popular Badge */}
        <div className="flex items-center gap-1.5 min-w-0">
          <span
            className={`w-3 h-3 border-[1.5px] rounded-[2px] shrink-0 inline-flex items-center justify-center ${
              isVeg ? 'border-[#20BF6B] bg-[#20BF6B]/15' : 'border-[#FF5353] bg-[#FF5353]/15'
            }`}
            title={isVeg ? 'Vegetarian' : 'Non-Vegetarian'}
          >
            <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#FF5353]'}`} />
          </span>

          <h3 className="text-sm sm:text-base font-bold text-white truncate leading-snug">
            {dish.name}
          </h3>

          {dish.isBestseller && (
            <span
              className="text-[9px] font-extrabold text-amber-400 bg-amber-400/10 border border-amber-400/25 px-1.5 py-0.2 rounded-full shrink-0 flex items-center gap-0.5"
              title="Chef Special / Popular"
            >
              <Flame size={9} />
            </span>
          )}
        </div>

        {/* Row 2: Price (Green like revenue screen) + Category / Tag */}
        <div className="flex items-center gap-1.5 text-xs">
          <span className="font-extrabold text-emerald-400 text-sm tracking-tight shrink-0">
            {price}
          </span>
          {dish.description ? (
            <span className="text-[11px] text-gray-400 truncate max-w-[120px] sm:max-w-[200px]">
              • {dish.description}
            </span>
          ) : (
            <span className="text-[10px] text-gray-400 uppercase tracking-wider font-semibold shrink-0">
              • {dish.isBestseller ? 'Chef Special' : 'Main Dish'}
            </span>
          )}
        </div>
      </div>

      {/* Right: Compact Action Buttons (Matching Revenue Photo trailing actions style) */}
      <div className="flex items-center gap-1.5 shrink-0 ml-auto">
        {dish.has3dModel && (
          <button
            type="button"
            onClick={() => onOpen3d(dish)}
            className="btn-view-3d p-1.5 sm:px-2 sm:py-1 rounded-lg text-xs font-bold flex items-center gap-1 cursor-pointer"
            title="View 3D AR Model"
          >
            <Sparkles size={11} />
            <span className="hidden sm:inline text-[11px]">3D</span>
          </button>
        )}

        {onCustomize && (
          <button
            type="button"
            onClick={() => onCustomize(dish)}
            className="text-[11px] font-bold text-gray-300 hover:text-white px-2.5 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 flex items-center gap-1 cursor-pointer transition active:scale-95"
            title="Customize spice, add-ons, or notes"
          >
            <SlidersHorizontal size={11} className="text-[#FF7043]" />
            <span className="hidden xs:inline">Custom</span>
          </button>
        )}

        {quantity === 0 ? (
          <button
            type="button"
            onClick={() => onQuantityChange(dish, 1)}
            className="btn-order-coral text-white text-xs font-bold px-3 py-1.5 rounded-full flex items-center gap-1 cursor-pointer active:scale-95 transition shadow-sm"
          >
            <span>Order</span>
            <Plus size={12} />
          </button>
        ) : (
          <div className="qty-counter-pill rounded-full px-2 py-1 gap-2 flex items-center">
            <button
              type="button"
              onClick={() => onQuantityChange(dish, quantity - 1)}
              className="text-white hover:opacity-80 cursor-pointer p-0.5 transition active:scale-90"
              aria-label="Decrease"
            >
              <Minus size={11} />
            </button>
            <span className="text-xs font-black text-white min-w-[12px] text-center">
              {quantity}
            </span>
            <button
              type="button"
              onClick={() => onQuantityChange(dish, quantity + 1)}
              className="text-white hover:opacity-80 cursor-pointer p-0.5 transition active:scale-90"
              aria-label="Increase"
            >
              <Plus size={11} />
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
