import { memo } from 'react'
import { Sparkles, Plus, Minus, Flame, SlidersHorizontal } from 'lucide-react'
import { isNonCustomizableDish, type PublicMenuDish } from '@/services/productService'

export const DishCard = memo(function DishCard({
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
  const isSoldOut = dish.soldOutToday

  return (
    <div
      className={`menu-dish-card rounded-2xl p-2.5 sm:p-3 flex items-center gap-3 sm:gap-3.5 transition-all ${
        isSoldOut ? 'opacity-75 bg-[#171821]/80 border-dashed border-rose-500/25' : ''
      }`}
    >
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
            className={`w-full h-full object-cover transition-transform duration-300 ${
              isSoldOut ? 'grayscale contrast-75' : 'group-hover:scale-105'
            }`}
            loading="lazy"
            onError={(e) => {
              ;(e.target as HTMLElement).style.display = 'none'
            }}
          />
        ) : (
          <div className="text-xl sm:text-2xl">🍽️</div>
        )}

        {/* Sold out overlay tag on thumbnail */}
        {isSoldOut ? (
          <div className="absolute inset-0 bg-black/60 backdrop-blur-[1px] flex items-center justify-center">
            <span className="text-[8px] font-black text-rose-300 uppercase tracking-tight bg-rose-950/80 border border-rose-500/40 px-1 py-0.2 rounded">
              86
            </span>
          </div>
        ) : dish.has3dModel ? (
          /* AR pill badge on thumbnail */
          <div className="ar-shimmer-badge absolute bottom-0 inset-x-0 text-white py-0.2 text-[8px] font-black flex items-center justify-center gap-0.5">
            <Sparkles size={8} />
            <span>AR</span>
          </div>
        ) : null}
      </div>

      {/* Middle: Dish Details (Veg Dot, Name, Price, Category) */}
      <div className="flex-1 min-w-0 flex flex-col justify-center gap-0.5">
        {/* Row 1: Veg indicator + Dish Name + Popular / Sold Out Badge */}
        <div className="flex items-center gap-1.5 min-w-0">
          <span
            className={`w-3 h-3 border-[1.5px] rounded-[2px] shrink-0 inline-flex items-center justify-center ${
              isVeg ? 'border-[#20BF6B] bg-[#20BF6B]/15' : 'border-[#FF5353] bg-[#FF5353]/15'
            }`}
            title={isVeg ? 'Vegetarian' : 'Non-Vegetarian'}
          >
            <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#FF5353]'}`} />
          </span>

          <h3
            className={`text-sm sm:text-base font-bold truncate leading-snug ${
              isSoldOut ? 'text-gray-400 line-through decoration-rose-500/50' : 'text-white'
            }`}
          >
            {dish.name}
          </h3>

          {isSoldOut ? (
            <span
              className="text-[9px] font-black tracking-wide text-rose-300 bg-rose-500/15 border border-rose-500/35 px-1.5 py-0.2 rounded-full shrink-0 uppercase"
              title="Sold out for today"
            >
              Sold Out
            </span>
          ) : dish.isBestseller ? (
            <span
              className="text-[9px] font-extrabold text-amber-400 bg-amber-400/10 border border-amber-400/25 px-1.5 py-0.2 rounded-full shrink-0 flex items-center gap-0.5"
              title="Chef Special / Popular"
            >
              <Flame size={9} />
            </span>
          ) : null}
        </div>

        {/* Row 2: Price + Category / Tag */}
        <div className="flex items-center gap-1.5 text-xs">
          <span
            className={`font-extrabold text-sm tracking-tight shrink-0 ${
              isSoldOut ? 'text-gray-500' : 'text-emerald-400'
            }`}
          >
            {price}
          </span>
          {isSoldOut ? (
            <span className="text-[10px] font-semibold text-rose-400/90 shrink-0">
              • Sold Out for Today
            </span>
          ) : dish.description ? (
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

      {/* Right: Compact Action Buttons */}
      <div className="flex items-center gap-1.5 shrink-0 ml-auto">
        {dish.has3dModel && (
          <button
            type="button"
            onClick={() => onOpen3d(dish)}
            className="btn-view-3d p-1.5 sm:px-2 sm:py-1 rounded-lg text-xs font-bold flex items-center gap-1 cursor-pointer"
            title="Place dish on your table in AR"
          >
            <Sparkles size={11} />
            <span className="hidden sm:inline text-[11px]">AR</span>
          </button>
        )}

        {isSoldOut ? (
          /* Disabled Order Button for Sold Out Products */
          <button
            type="button"
            disabled
            className="px-2.5 sm:px-3 py-1.5 rounded-full text-[11px] sm:text-xs font-bold bg-[#27272A]/90 text-rose-300/80 border border-rose-500/30 cursor-not-allowed select-none flex items-center gap-1 shadow-inner opacity-90"
            title="This product is sold out for today and cannot be added to cart"
          >
            <span>Sold Out</span>
          </button>
        ) : (
          <>
            {onCustomize && !isNonCustomizableDish(dish) && (
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
          </>
        )}
      </div>
    </div>
  )
})
