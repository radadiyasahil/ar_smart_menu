import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { UtensilsCrossed, Sparkles, QrCode } from 'lucide-react'
import { productService, type PublicMenuResponse } from '@/services/productService'

export function HomePage() {
  const [menu, setMenu] = useState<PublicMenuResponse | null>(null)

  const currentHost =
    window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
      ? window.location.hostname
      : window.location.hostname
  const port = window.location.port ? `:${window.location.port}` : ''
  const menuSlug = menu?.slug || 'tasty-bites'
  const mobileMenuUrl = `http://${currentHost}${port}/menu/${menuSlug}`
  const qrCodeUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(mobileMenuUrl)}`

  useEffect(() => {
    productService
      .fetchMenuBySlug('tasty-bites')
      .then((data) => setMenu(data))
      .catch((err) => console.error('Failed to load restaurant dishes:', err))
  }, [])

  const dishes = menu?.categories.flatMap((c) => c.dishes) || []

  return (
    <div className="min-h-full bg-[#0F0F12] text-white p-6 max-w-lg mx-auto flex flex-col items-center justify-center text-center">
      {/* Brand Header */}
      <div className="w-16 h-16 rounded-2xl bg-[#27272A] border border-[#EB4F16]/50 flex items-center justify-center mb-4 shadow-xl">
        {menu?.logoUrl ? (
          <img src={menu.logoUrl} alt={menu.businessName} className="w-full h-full object-cover rounded-2xl" />
        ) : (
          <UtensilsCrossed size={32} className="text-[#EB4F16]" />
        )}
      </div>

      <h1 className="text-2xl font-black text-white">{menu?.businessName || 'AR Smart Menu'}</h1>
      <p className="text-xs text-gray-400 mt-1 max-w-sm">
        {menu?.city ? `📍 ${menu.city}` : ''} • Scan to view interactive 3D dishes on your table!
      </p>

      {/* QR Code Card */}
      <div className="bg-[#18181B] border border-[#27272A] rounded-2xl p-5 my-5 flex flex-col items-center gap-3 shadow-2xl">
        <span className="text-xs font-bold text-[#FF6A3D] uppercase tracking-wider flex items-center gap-1.5">
          <QrCode size={14} />
          <span>Scan with Phone Camera</span>
        </span>
        <div className="bg-white p-2 rounded-xl">
          <img src={qrCodeUrl} alt="Scan table menu" width={180} height={180} className="rounded block" />
        </div>
        <Link
          to={`/menu/${menuSlug}`}
          className="text-xs text-gray-300 hover:text-white underline"
        >
          Or open on this device
        </Link>
      </div>

      {/* Owner's Dynamic Dishes */}
      <div className="w-full space-y-2 max-w-xs">
        <Link
          to={`/menu/${menuSlug}`}
          className="w-full py-3 px-4 bg-gradient-to-r from-[#EB4F16] to-[#FF6A3D] hover:from-[#d64510] hover:to-[#f05e30] text-white font-bold rounded-full text-sm flex items-center justify-center gap-2 shadow-lg shadow-[#EB4F16]/30 cursor-pointer"
        >
          <Sparkles size={16} />
          <span>Explore 3D Menu</span>
        </Link>

        {dishes.length > 0 && (
          <div className="pt-2">
            <span className="text-[11px] font-semibold text-gray-500 uppercase block mb-2">
              Dishes by {menu?.businessName}
            </span>
            <div className="space-y-1.5">
              {dishes.slice(0, 4).map((d) => (
                <Link
                  key={d.id}
                  to={`/dish/${d.dishSlug}`}
                  className="w-full py-2 px-3 bg-[#1F1F23] hover:bg-[#27272A] border border-[#2E2E34] text-gray-200 hover:text-white rounded-xl text-xs font-semibold flex items-center justify-between transition"
                >
                  <span className="truncate">{d.name}</span>
                  <span className="text-[#FF6A3D] font-bold">
                    {d.pricePaise ? `₹${Math.round(d.pricePaise / 100)}` : 'View 3D'}
                  </span>
                </Link>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
