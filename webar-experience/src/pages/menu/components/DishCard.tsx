import { Sparkles, Plus, Minus, Flame } from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'

export function DishCard({
  dish,
  quantity,
  onQuantityChange,
  onOpen3d,
}: {
  dish: PublicMenuDish
  quantity: number
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number) => void
  onOpen3d: (dish: PublicMenuDish) => void
}) {
  const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
  const price = dish.pricePaise
    ? `₹${Math.round(dish.pricePaise / 100).toLocaleString('en-IN')}`
    : '—'

  return (
    <div className="menu-dish-card rounded-3xl p-4 sm:p-5 flex items-center gap-4 sm:gap-5">
      {/* Left: Circular Food Dish Plate (as in reference Screen 2) */}
      <div
        onClick={() => dish.has3dModel && onOpen3d(dish)}
        className={`dish-plate-halo relative w-22 h-22 sm:w-26 sm:h-26 min-w-[88px] sm:min-w-[104px] rounded-full overflow-hidden bg-[#242735] border-2 border-white/15 flex-shrink-0 flex items-center justify-center ${
          dish.has3dModel ? 'cursor-pointer group' : ''
        }`}
        title={dish.has3dModel ? 'Tap to view 3D model' : undefined}
      >
        {dish.thumbnailUrl ? (
          <img
            src={dish.thumbnailUrl}
            alt={dish.name}
            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-500"
            loading="lazy"
            onError={(e) => {
              ;(e.target as HTMLElement).style.display = 'none'
            }}
          />
        ) : (
          <div className="text-3xl sm:text-4xl">🍽️</div>
        )}

        {/* 3D AR Pill badge with shimmer on bottom of circular food plate */}
        {dish.has3dModel && (
          <div className="ar-shimmer-badge absolute bottom-1 inset-x-2 text-white py-0.5 rounded-full text-[9px] font-black flex items-center justify-center gap-1 backdrop-blur-sm">
            <Sparkles size={10} />
            <span>3D AR</span>
          </div>
        )}
      </div>

      {/* Right: Dish Info & Actions */}
      <div className="flex-1 flex flex-col justify-between min-w-0 py-0.5">
        <div>
          {/* Top row: Veg Indicator + Popular + Category Pill Tag */}
          <div className="flex items-center justify-between gap-2 mb-1.5">
            <div className="flex items-center gap-2 flex-wrap">
              <span
                className={`w-3.5 h-3.5 border-[1.5px] rounded-[3px] inline-flex items-center justify-center ${
                  isVeg ? 'border-[#20BF6B] bg-[#20BF6B]/15' : 'border-[#FF5353] bg-[#FF5353]/15'
                }`}
                title={isVeg ? 'Vegetarian' : 'Non-Vegetarian'}
              >
                <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#FF5353]'}`} />
              </span>

              {dish.isBestseller && (
                <span className="text-[10px] font-extrabold text-amber-400 bg-amber-400/10 border border-amber-400/25 px-2 py-0.5 rounded-full flex items-center gap-0.5">
                  <Flame size={10} /> Popular
                </span>
              )}
              {dish.isSpicy && <span className="text-xs" title="Spicy">🌶️</span>}
            </div>

            <span className="bg-[#FF5353]/15 text-[#FF6A3D] border border-[#FF5353]/30 px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider whitespace-nowrap">
              {dish.isBestseller ? 'Chef Special' : 'Main Dish'}
            </span>
          </div>

          {/* Dish Name */}
          <h3 className="text-base sm:text-lg font-black text-white truncate leading-snug">
            {dish.name}
          </h3>

          {/* Description */}
          {dish.description && (
            <p className="text-xs text-[#9CA3AF] mt-1 line-clamp-2 leading-relaxed font-normal">
              {dish.description}
            </p>
          )}

          {/* Price */}
          <div className="text-base sm:text-lg font-black text-white mt-1.5">
            {price}
          </div>
        </div>

        {/* Bottom Action Row (Order Now / 3D View - Matching Reference Style) */}
        <div className="flex items-center justify-between mt-3 pt-2.5 border-t border-white/5 gap-2.5">
          {dish.has3dModel ? (
            <button
              type="button"
              onClick={() => onOpen3d(dish)}
              className="btn-view-3d px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-sm"
            >
              <Sparkles size={12} />
              <span>3D View</span>
            </button>
          ) : (
            <div />
          )}

          {quantity === 0 ? (
            <button
              type="button"
              onClick={() => onQuantityChange(dish, 1)}
              className="btn-order-coral text-white text-xs font-bold px-4.5 py-2 rounded-full flex items-center gap-1.5 cursor-pointer ml-auto"
            >
              <span>Order Now</span>
              <Plus size={13} />
            </button>
          ) : (
            <div className="qty-counter-pill rounded-full px-3 py-1.5 gap-3 flex items-center ml-auto">
              <button
                type="button"
                onClick={() => onQuantityChange(dish, quantity - 1)}
                className="text-white hover:opacity-80 cursor-pointer transition active:scale-90"
                aria-label="Decrease"
              >
                <Minus size={12} />
              </button>
              <span className="text-xs font-black text-white min-w-[14px] text-center">
                {quantity}
              </span>
              <button
                type="button"
                onClick={() => onQuantityChange(dish, quantity + 1)}
                className="text-white hover:opacity-80 cursor-pointer transition active:scale-90"
                aria-label="Increase"
              >
                <Plus size={12} />
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
