import { useState, useRef, useEffect } from 'react'
import { X, Sparkles, Plus, Minus, RotateCw, Check } from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'

export function Interactive3dModal({
  dish,
  quantity,
  onClose,
  onQuantityChange,
  onAddedToCart,
}: {
  dish: PublicMenuDish | null
  quantity: number
  onClose: () => void
  onQuantityChange: (dish: PublicMenuDish, newQuantity: number) => void
  onAddedToCart: (dish: PublicMenuDish) => void
}) {
  const [loading, setLoading] = useState(true)
  const [autoRotate, setAutoRotate] = useState(true)
  const [qty, setQty] = useState(quantity > 0 ? quantity : 1)
  const [added, setAdded] = useState(false)
  const viewerRef = useRef<HTMLElement | null>(null)

  useEffect(() => {
    setQty(quantity > 0 ? quantity : 1)
    setLoading(true)
  }, [dish, quantity])

  if (!dish) return null

  const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
  const price = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0

  const handleAdd = () => {
    onQuantityChange(dish, qty)
    setAdded(true)
    onAddedToCart(dish)
    setTimeout(() => {
      setAdded(false)
      onClose()
    }, 500)
  }

  return (
    <div
      className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-end sm:items-center justify-center p-0 sm:p-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="w-full max-w-lg bg-[#18181B] border-t sm:border border-[#27272A] rounded-t-3xl sm:rounded-2xl max-h-[92vh] flex flex-col shadow-2xl overflow-hidden">
        {/* Top Header */}
        <div className="flex items-center justify-between p-4 border-b border-[#27272A]">
          <div className="flex items-center gap-2">
            <span
              className={`w-3.5 h-3.5 border rounded-[3px] inline-flex items-center justify-center ${
                isVeg ? 'border-[#20BF6B] bg-[#20BF6B]/10' : 'border-[#EF4444] bg-[#EF4444]/10'
              }`}
            >
              <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#EF4444]'}`} />
            </span>
            <h2 className="text-base font-bold text-white truncate max-w-[260px]">{dish.name}</h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[#27272A] text-gray-400 hover:text-white flex items-center justify-center cursor-pointer"
          >
            <X size={16} />
          </button>
        </div>

        {/* 3D Model Viewer Canvas */}
        <div className="relative w-full h-[320px] bg-radial from-[#25252b] to-[#111113] border-b border-[#27272A]">
          {loading && (
            <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2 bg-[#121214]/80">
              <div className="w-8 h-8 border-2 border-[#EB4F16]/20 border-t-[#EB4F16] rounded-full animate-spin" />
              <span className="text-xs text-gray-400">Loading 3D Dish...</span>
            </div>
          )}

          <model-viewer
            ref={(el) => {
              viewerRef.current = el
              if (el) {
                el.addEventListener('load', () => setLoading(false), { once: true })
                el.addEventListener('error', () => setLoading(false), { once: true })
              }
            }}
            src={dish.glbUrl || 'https://modelviewer.dev/shared-assets/models/Hamburger.glb'}
            ios-src={dish.usdzUrl}
            alt={dish.name}
            ar
            ar-modes="webxr scene-viewer quick-look"
            ar-placement="floor"
            ar-scale="fixed"
            camera-controls
            auto-rotate={autoRotate}
            rotation-per-second="25deg"
            touch-action="pan-y"
            shadow-intensity="1"
            exposure="1.2"
            style={{ width: '100%', height: '100%' }}
          >
            {/* AR Button */}
            <button
              slot="ar-button"
              className="absolute bottom-4 right-4 bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] text-white px-4 py-2 rounded-full text-xs font-bold flex items-center gap-1.5 shadow-lg shadow-[#EB4F16]/30 cursor-pointer z-10"
            >
              <Sparkles size={13} />
              <span>📱 View on Table (AR)</span>
            </button>
          </model-viewer>

          {/* Controls overlay */}
          <div className="absolute top-3 left-3 flex gap-2 z-10">
            <button
              type="button"
              onClick={() => setAutoRotate(!autoRotate)}
              className={`px-2.5 py-1 rounded-full text-[11px] font-semibold flex items-center gap-1 backdrop-blur cursor-pointer ${
                autoRotate ? 'bg-[#EB4F16]/90 text-white' : 'bg-black/60 text-gray-300'
              }`}
            >
              <RotateCw size={10} />
              <span>{autoRotate ? 'Spinning' : 'Paused'}</span>
            </button>
            <span className="px-2.5 py-1 rounded-full text-[11px] font-medium bg-black/60 text-gray-300 backdrop-blur">
              360° Touch
            </span>
          </div>

          <div className="absolute bottom-4 left-4 bg-black/60 backdrop-blur px-2.5 py-1 rounded-full text-[11px] text-gray-300">
            🍽️ 1:1 Scale
          </div>
        </div>

        {/* Dish Info */}
        <div className="p-4 space-y-3 overflow-y-auto flex-1">
          <div className="flex items-center justify-between">
            <span className="text-xl font-extrabold text-[#EB4F16]">₹{price}</span>
            <div className="flex gap-1.5">
              {dish.isBestseller && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-amber-500/15 text-amber-400 border border-amber-500/30">
                  🔥 Bestseller
                </span>
              )}
              {dish.isSpicy && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-red-500/15 text-red-400 border border-red-500/30">
                  🌶️ Spicy
                </span>
              )}
            </div>
          </div>

          <p className="text-xs text-gray-300 leading-relaxed">
            {dish.description || 'Prepared fresh with signature spice blends.'}
          </p>

          <div className="grid grid-cols-3 gap-2 text-center bg-[#1E1E22] border border-[#2A2A30] rounded-xl p-2 text-xs">
            <div>
              <span className="text-[10px] text-gray-500 block">Diet</span>
              <span className={`font-semibold ${isVeg ? 'text-[#20BF6B]' : 'text-[#EF4444]'}`}>
                {isVeg ? 'Veg' : 'Non-Veg'}
              </span>
            </div>
            <div className="border-x border-[#2A2A30]">
              <span className="text-[10px] text-gray-500 block">Portion</span>
              <span className="font-semibold text-white">Serves 1-2</span>
            </div>
            <div>
              <span className="text-[10px] text-gray-500 block">Experience</span>
              <span className="font-semibold text-[#FF6A3D]">WebAR 3D</span>
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-[#1E1E22] border-t border-[#2A2A30] flex items-center gap-3">
          <div className="flex items-center bg-[#27272A] border border-[#3F3F46] rounded-full px-3 py-1.5 gap-3">
            <button
              type="button"
              onClick={() => setQty(Math.max(1, qty - 1))}
              disabled={qty <= 1}
              className="text-white disabled:opacity-40 cursor-pointer"
            >
              <Minus size={13} />
            </button>
            <span className="text-xs font-bold text-white min-w-[14px] text-center">{qty}</span>
            <button
              type="button"
              onClick={() => setQty(qty + 1)}
              className="text-white hover:text-[#EB4F16] cursor-pointer"
            >
              <Plus size={13} />
            </button>
          </div>

          <button
            type="button"
            onClick={handleAdd}
            className={`flex-1 py-3 px-4 rounded-full text-xs font-bold flex items-center justify-center gap-1.5 cursor-pointer shadow-lg transition ${
              added
                ? 'bg-[#20BF6B] text-white shadow-[#20BF6B]/30'
                : 'bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] text-white shadow-[#EB4F16]/30'
            }`}
          >
            {added ? (
              <>
                <Check size={14} />
                <span>Added!</span>
              </>
            ) : (
              <>
                <span>Add to Table Order</span>
                <span>•</span>
                <span>₹{price * qty}</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  )
}
