import { useState, useRef, useEffect, useCallback } from 'react'
import { X, Sparkles, Plus, Minus, Check, Camera, ScanLine, Box } from 'lucide-react'
import type { PublicMenuDish } from '@/services/productService'
import { getDeviceCapabilities } from '@/utils/device'
import { SurfaceScanOverlay } from '@/components/ar/SurfaceScanOverlay'

type ArSessionStatus = 'not-presenting' | 'session-started' | 'object-placed' | 'failed'

interface ModelViewerElement extends HTMLElement {
  activateAR: () => Promise<void>
  canActivateAR?: boolean
}

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
  const [qty, setQty] = useState(quantity > 0 ? quantity : 1)
  const [added, setAdded] = useState(false)
  const [arStatus, setArStatus] = useState<ArSessionStatus>('not-presenting')
  const [arLaunching, setArLaunching] = useState(false)
  const [arError, setArError] = useState<string | null>(null)
  const [previewOnly, setPreviewOnly] = useState(false)
  const viewerRef = useRef<ModelViewerElement | null>(null)
  const caps = getDeviceCapabilities()

  useEffect(() => {
    setQty(quantity > 0 ? quantity : 1)
    setLoading(true)
    setArStatus('not-presenting')
    setArLaunching(false)
    setArError(null)
    setPreviewOnly(false)
  }, [dish, quantity])

  const handleArStatus = useCallback((e: Event) => {
    const status = (e as CustomEvent).detail?.status as ArSessionStatus | undefined
    if (!status) return
    setArStatus(status)
    setArLaunching(false)
    if (status === 'failed') {
      setArError(
        caps.isMobile
          ? 'Could not start AR. Use Chrome (Android) or Safari (iPhone) over HTTPS, and allow camera access.'
          : 'Table AR needs a phone or tablet camera. Open this menu on your mobile device.',
      )
    }
  }, [caps.isMobile])

  useEffect(() => {
    const el = viewerRef.current
    if (!el) return
    el.addEventListener('ar-status', handleArStatus)
    return () => el.removeEventListener('ar-status', handleArStatus)
  }, [handleArStatus, dish])

  const launchAr = useCallback(async () => {
    const el = viewerRef.current
    if (!el || loading) return

    setArError(null)
    setArLaunching(true)
    setPreviewOnly(false)

    try {
      await el.activateAR()
    } catch {
      setArLaunching(false)
      setArError(
        caps.isMobile
          ? 'AR could not start. Allow camera permission, then try again. On Android use Chrome; on iPhone use Safari.'
          : 'Open this page on your phone or tablet to place the dish on your table.',
      )
    }
  }, [loading, caps.isMobile])

  if (!dish) return null

  const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
  const price = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0
  const glbSrc = dish.glbUrl || 'https://modelviewer.dev/shared-assets/models/Hamburger.glb'
  // Never pass the sample hamburger USDZ — it replaces the real dish on iOS Quick Look
  const usdzSrc =
    dish.usdzUrl && !dish.usdzUrl.includes('Hamburger.usdz') ? dish.usdzUrl : undefined
  const inAr = arStatus === 'session-started' || arStatus === 'object-placed'
  const showScanHint = arLaunching || arStatus === 'session-started'

  const handleAdd = () => {
    if (!dish || dish.soldOutToday) return
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

        <div className="relative w-full h-[340px] bg-[#0c0c0e] border-b border-[#27272A]">
          {loading && (
            <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2 bg-[#121214]/80">
              <div className="w-8 h-8 border-2 border-[#EB4F16]/20 border-t-[#EB4F16] rounded-full animate-spin" />
              <span className="text-xs text-gray-400">Loading dish model...</span>
            </div>
          )}

          <model-viewer
            ref={(el) => {
              viewerRef.current = el as ModelViewerElement | null
              if (el) {
                el.addEventListener('load', () => setLoading(false), { once: true })
                el.addEventListener('error', () => setLoading(false), { once: true })
              }
            }}
            src={glbSrc}
            ios-src={usdzSrc}
            alt={dish.name}
            ar
            ar-modes="webxr scene-viewer quick-look"
            ar-placement="floor"
            ar-scale="fixed"
            camera-controls={previewOnly || !caps.isMobile}
            touch-action="pan-y"
            shadow-intensity="1.2"
            shadow-softness="0.9"
            exposure="1.15"
            environment-image="neutral"
            interaction-prompt="none"
            camera-orbit="0deg 65deg 105%"
            field-of-view="28deg"
            style={{ width: '100%', height: '100%', background: 'transparent' }}
          >
            {/* Hidden native AR trigger — we drive AR via activateAR() from our CTA */}
            <button slot="ar-button" style={{ display: 'none' }} aria-hidden="true" />
            <div slot="ar-prompt" className="ar-prompt">
              Point at your table, then tap to place
            </div>
          </model-viewer>

          <SurfaceScanOverlay
            visible={showScanHint && !previewOnly}
            message={
              arStatus === 'object-placed'
                ? 'Dish placed — walk around the table'
                : 'Move phone slowly over the table'
            }
          />

          {!loading && !inAr && !previewOnly && (
            <div className="absolute inset-0 z-20 flex flex-col items-center justify-end bg-gradient-to-t from-black/90 via-black/45 to-transparent p-5 pb-5 pointer-events-none">
              <div className="pointer-events-auto w-full max-w-sm flex flex-col items-center gap-3">
                <div className="flex items-center gap-2 text-white/90 text-xs font-medium">
                  <ScanLine size={14} className="text-[#FF6A3D]" />
                  <span>See it life-size on your dining table</span>
                </div>

                <button
                  type="button"
                  onClick={() => void launchAr()}
                  disabled={arLaunching}
                  className="w-full py-3.5 px-4 rounded-full text-sm font-bold flex items-center justify-center gap-2 bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] text-white shadow-lg shadow-[#EB4F16]/35 cursor-pointer disabled:opacity-70"
                >
                  <Camera size={16} />
                  <span>{arLaunching ? 'Opening camera...' : 'Place on Table (AR)'}</span>
                  <Sparkles size={14} />
                </button>

                {!caps.isMobile && (
                  <p className="text-[11px] text-center text-gray-400 leading-relaxed">
                    Best on phone or tablet — point the camera at a flat table surface.
                  </p>
                )}

                <button
                  type="button"
                  onClick={() => setPreviewOnly(true)}
                  className="text-[11px] text-gray-400 hover:text-white flex items-center gap-1 cursor-pointer"
                >
                  <Box size={12} />
                  <span>Preview 3D only</span>
                </button>
              </div>
            </div>
          )}

          {previewOnly && !inAr && (
            <div className="absolute top-3 left-3 right-3 z-20 flex items-center justify-between gap-2">
              <span className="px-2.5 py-1 rounded-full text-[11px] font-medium bg-black/60 text-gray-300 backdrop-blur">
                3D preview · drag to rotate
              </span>
              <button
                type="button"
                onClick={() => void launchAr()}
                className="px-3 py-1.5 rounded-full text-[11px] font-bold bg-[#EB4F16] text-white flex items-center gap-1 cursor-pointer shadow-md"
              >
                <Camera size={12} />
                Place on Table
              </button>
            </div>
          )}

          {arError && (
            <div className="absolute bottom-3 left-3 right-3 z-30 rounded-xl bg-rose-950/90 border border-rose-500/40 px-3 py-2.5">
              <p className="text-[11px] text-rose-200 leading-relaxed">{arError}</p>
              <button
                type="button"
                onClick={() => {
                  setArError(null)
                  void launchAr()
                }}
                className="mt-1.5 text-[11px] font-bold text-white underline cursor-pointer"
              >
                Try again
              </button>
            </div>
          )}
        </div>

        <div className="p-4 space-y-3 overflow-y-auto flex-1">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className={`text-xl font-extrabold ${dish.soldOutToday ? 'text-gray-500 line-through' : 'text-[#EB4F16]'}`}>
                ₹{price}
              </span>
              {dish.soldOutToday && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-black bg-rose-500/20 text-rose-300 border border-rose-500/40 uppercase tracking-tight">
                  Sold Out for Today
                </span>
              )}
            </div>
            <div className="flex gap-1.5">
              {dish.isBestseller && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-amber-500/15 text-amber-400 border border-amber-500/30">
                  Bestseller
                </span>
              )}
              {dish.isSpicy && (
                <span className="px-2 py-0.5 rounded-full text-[11px] font-semibold bg-red-500/15 text-red-400 border border-red-500/30">
                  Spicy
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
              <span className="font-semibold text-[#FF6A3D]">Table AR</span>
            </div>
          </div>
        </div>

        <div className="p-4 bg-[#1E1E22] border-t border-[#2A2A30] flex items-center gap-3">
          {dish.soldOutToday ? (
            <div className="w-full flex items-center justify-between bg-rose-500/10 border border-rose-500/30 rounded-2xl px-4 py-3">
              <div className="flex items-center gap-2 text-rose-300">
                <span className="text-base">⛔</span>
                <div>
                  <span className="text-xs font-bold block text-rose-300">Sold Out for Today</span>
                  <span className="text-[10px] text-gray-400">Owner marked this item unavailable</span>
                </div>
              </div>
              <button
                type="button"
                disabled
                className="py-2 px-4 rounded-full text-xs font-bold bg-neutral-800 text-neutral-400 border border-neutral-700/60 cursor-not-allowed select-none opacity-80"
              >
                Cannot Order
              </button>
            </div>
          ) : (
            <>
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
            </>
          )}
        </div>
      </div>
    </div>
  )
}
