import { useState, useId, useMemo } from 'react'
import { X, Check, ChefHat, Sparkles, Plus, Minus } from 'lucide-react'
import { isSweetOrBeverageDish, type PublicMenuDish } from '@/services/productService'
import type { DishAddon, DishCustomization } from '@/types/cart'

const DEFAULT_FOOD_ADDONS: DishAddon[] = [
  { id: 'extra_cheese', name: 'Extra Cheese 🧀', price: 40 },
  { id: 'signature_dip', name: 'Signature Dip / Chutney 🥣', price: 25 },
  { id: 'extra_butter', name: 'Extra Butter 🧈', price: 20 },
  { id: 'cold_beverage', name: 'Chilled Drink Combo 🥤', price: 45 },
]

const SPICE_OPTIONS = [
  { value: 'Mild', label: 'Mild', icon: '🟢' },
  { value: 'Medium', label: 'Medium', icon: '🟡' },
  { value: 'Spicy', label: 'Spicy', icon: '🌶️' },
] as const

const DIETARY_OPTIONS = [
  { value: 'Regular', label: 'Regular', icon: '✨' },
  { value: 'Jain', label: 'Jain', icon: '🧅🚫' },
  { value: 'Vegan', label: 'Vegan', icon: '🌱' },
] as const

function OptionButtonGroup<T extends string>({
  options,
  selected,
  onSelect,
  activeClass,
}: {
  options: readonly { value: T; label: string; icon: string }[]
  selected: T
  onSelect: (val: T) => void
  activeClass: string
}) {
  return (
    <div className="grid grid-cols-3 gap-2">
      {options.map((opt) => {
        const isSelected = selected === opt.value
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => onSelect(opt.value)}
            className={`py-2.5 px-2 rounded-xl border text-xs font-bold flex items-center justify-center gap-1 cursor-pointer transition ${
              isSelected
                ? `${activeClass} shadow-sm`
                : 'bg-[#20222C] border-white/10 text-gray-300 hover:border-white/20'
            }`}
          >
            <span>{opt.icon}</span>
            <span>{opt.label}</span>
          </button>
        )
      })}
    </div>
  )
}

export function DishCustomizationModal({
  isOpen,
  dish,
  initialCustomization,
  onClose,
  onConfirm,
}: {
  isOpen: boolean
  dish: PublicMenuDish | null
  initialCustomization?: DishCustomization
  onClose: () => void
  onConfirm: (dish: PublicMenuDish, quantity: number, customization: DishCustomization) => void
}) {
  const notesId = useId()
  const [spiceLevel, setSpiceLevel] = useState<'Mild' | 'Medium' | 'Spicy'>(
    initialCustomization?.spiceLevel ?? 'Medium'
  )
  const [dietary, setDietary] = useState<'Regular' | 'Jain' | 'Vegan'>(
    initialCustomization?.dietary ?? 'Regular'
  )
  const [selectedAddonIds, setSelectedAddonIds] = useState<string[]>(
    initialCustomization?.selectedAddons?.map((a) => a.id) ?? []
  )
  const [notes, setNotes] = useState(initialCustomization?.notes ?? '')
  const [quantity, setQuantity] = useState(1)

  const isSweetOrDrink = dish ? isSweetOrBeverageDish(dish) : false
  const showSpiceLevel = dish?.customization?.allowSpiceLevel ?? !isSweetOrDrink
  const showDietary = dish?.customization?.allowDietary ?? !isSweetOrDrink

  const availableAddons: DishAddon[] = useMemo(() => {
    if (!dish) return []
    // 1. Restaurant defined custom add-ons on this dish
    if (dish.customization?.addons && dish.customization.addons.length > 0) {
      return dish.customization.addons
    }
    // 2. Owner explicitly configured 0 add-ons for this dish
    if (dish.customization?.addons !== undefined && dish.customization.addons.length === 0) {
      return []
    }
    // 3. Category smart default: hide savory add-ons for sweet items/beverages
    if (isSweetOrDrink) {
      return []
    }
    return DEFAULT_FOOD_ADDONS
  }, [dish, isSweetOrDrink])

  if (!isOpen || !dish) return null

  const isVeg = dish.vegStatus === 0 || dish.vegStatus === 2
  const basePrice = dish.pricePaise ? Math.round(dish.pricePaise / 100) : 0

  const activeAddons = availableAddons.filter((a) => selectedAddonIds.includes(a.id))
  const addonsTotal = activeAddons.reduce((sum, a) => sum + a.price, 0)
  const itemUnitPrice = basePrice + addonsTotal
  const finalTotal = itemUnitPrice * quantity

  const toggleAddon = (id: string) => {
    setSelectedAddonIds((prev) =>
      prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]
    )
  }

  const handleSave = () => {
    const custom: DishCustomization = {
      spiceLevel: showSpiceLevel ? spiceLevel : undefined,
      dietary: showDietary ? dietary : undefined,
      selectedAddons: activeAddons,
      notes: notes.trim(),
    }
    onConfirm(dish, quantity, custom)
    onClose()
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/75 backdrop-blur-sm animate-fadeIn">
      <div className="w-full max-w-lg bg-[#181920] border border-white/10 rounded-t-3xl sm:rounded-3xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-white/10 flex items-center justify-between gap-3 bg-[#1F2029]">
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-12 h-12 rounded-xl bg-[#242735] overflow-hidden border border-white/10 flex-shrink-0 flex items-center justify-center">
              {dish.thumbnailUrl ? (
                <img src={dish.thumbnailUrl} alt={dish.name} className="w-full h-full object-cover" />
              ) : (
                <span className="text-xl">🍽️</span>
              )}
            </div>
            <div className="min-w-0">
              <div className="flex items-center gap-2">
                <span
                  className={`w-3 h-3 border-[1.5px] rounded-[2px] inline-flex items-center justify-center ${
                    isVeg ? 'border-[#20BF6B] bg-[#20BF6B]/20' : 'border-[#FF5353] bg-[#FF5353]/20'
                  }`}
                >
                  <span className={`w-1.5 h-1.5 rounded-full ${isVeg ? 'bg-[#20BF6B]' : 'bg-[#FF5353]'}`} />
                </span>
                <h3 className="text-base font-black text-white truncate">{dish.name}</h3>
              </div>
              <p className="text-xs text-gray-400 mt-0.5">Base Price: ₹{basePrice}</p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-gray-300 hover:text-white flex items-center justify-center cursor-pointer transition"
          >
            <X size={16} />
          </button>
        </div>

        {/* Scrollable Customization Content */}
        <div className="p-4 sm:p-5 space-y-5 overflow-y-auto">
          {/* 1. Spice Level (Hidden for beverages, desserts, or when disabled) */}
          {showSpiceLevel && (
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
                  <span>Spice Level</span>
                </span>
                <span className="text-[11px] text-gray-400">Selected: {spiceLevel}</span>
              </div>
              <OptionButtonGroup
                options={SPICE_OPTIONS}
                selected={spiceLevel}
                onSelect={(val) => setSpiceLevel(val as 'Mild' | 'Medium' | 'Spicy')}
                activeClass="bg-amber-500/15 border-amber-500 text-amber-300"
              />
            </div>
          )}

          {/* 2. Dietary Preference (Hidden for beverages, desserts, or when disabled) */}
          {showDietary && (
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
                  <span>Dietary Preference</span>
                </span>
                <span className="text-[11px] text-gray-400">Selected: {dietary}</span>
              </div>
              <OptionButtonGroup
                options={DIETARY_OPTIONS}
                selected={dietary}
                onSelect={(val) => setDietary(val as 'Regular' | 'Jain' | 'Vegan')}
                activeClass="bg-emerald-500/15 border-emerald-500 text-emerald-300"
              />
            </div>
          )}

          {/* 3. Dynamic Restaurant Add-ons */}
          {availableAddons.length > 0 && (
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-bold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
                  <Sparkles size={13} className="text-amber-400" />
                  <span>Available Add-ons (Optional)</span>
                </span>
                <span className="text-[11px] text-gray-400">
                  {activeAddons.length > 0 ? `+₹${addonsTotal}` : 'None'}
                </span>
              </div>
              <div className="space-y-2">
                {availableAddons.map((addon) => {
                  const isSelected = selectedAddonIds.includes(addon.id)
                  return (
                    <button
                      key={addon.id}
                      type="button"
                      onClick={() => toggleAddon(addon.id)}
                      className={`w-full py-2.5 px-3 rounded-xl border flex items-center justify-between text-xs cursor-pointer transition ${
                        isSelected
                          ? 'bg-[#FF5353]/15 border-[#FF5353] text-white'
                          : 'bg-[#20222C] border-white/10 text-gray-300 hover:border-white/20'
                      }`}
                    >
                      <div className="flex items-center gap-2.5">
                        <div
                          className={`w-4 h-4 rounded border flex items-center justify-center transition ${
                            isSelected
                              ? 'bg-[#FF5353] border-[#FF5353] text-white'
                              : 'border-gray-500 bg-transparent'
                          }`}
                        >
                          {isSelected && <Check size={11} strokeWidth={3} />}
                        </div>
                        <span className="font-semibold">{addon.name}</span>
                      </div>
                      <span className="font-bold text-amber-400">+₹{addon.price}</span>
                    </button>
                  )
                })}
              </div>
            </div>
          )}

          {/* 4. Special Kitchen Instructions */}
          <div>
            <label htmlFor={notesId} className="block text-xs font-bold text-gray-300 uppercase tracking-wider mb-2 flex items-center gap-1.5">
              <ChefHat size={13} className="text-gray-400" />
              <span>Special Chef Note for this Dish</span>
            </label>
            <input
              id={notesId}
              type="text"
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="e.g. Crispy crust, less oil, separate chutney..."
              maxLength={80}
              className="w-full bg-[#20222C] border border-white/10 rounded-xl px-3 py-2.5 text-xs text-white placeholder-gray-500 outline-none focus:border-[#FF5353] transition"
            />
          </div>
        </div>

        {/* Footer with Quantity & Add Button */}
        <div className="p-4 sm:p-5 border-t border-white/10 bg-[#1F2029] flex items-center gap-3">
          {/* Quantity pill */}
          <div className="flex items-center bg-[#282A36] border border-white/10 rounded-full px-3 py-1.5 gap-3">
            <button
              type="button"
              onClick={() => setQuantity((q) => Math.max(1, q - 1))}
              disabled={quantity <= 1}
              className="text-gray-300 hover:text-white disabled:opacity-30 cursor-pointer"
            >
              <Minus size={13} />
            </button>
            <span className="text-xs font-black text-white min-w-[14px] text-center">
              {quantity}
            </span>
            <button
              type="button"
              onClick={() => setQuantity((q) => q + 1)}
              className="text-gray-300 hover:text-white cursor-pointer"
            >
              <Plus size={13} />
            </button>
          </div>

          {/* Confirm Button */}
          <button
            type="button"
            onClick={handleSave}
            className="flex-1 py-3 bg-gradient-to-r from-[#FF5353] to-[#FF7043] hover:from-[#ff4040] hover:to-[#ff6233] text-white font-black rounded-full text-xs sm:text-sm cursor-pointer flex items-center justify-center gap-2 shadow-lg shadow-[#FF5353]/30 transition"
          >
            <span>Add to Order</span>
            <span>•</span>
            <span>₹{finalTotal}</span>
          </button>
        </div>
      </div>
    </div>
  )
}
