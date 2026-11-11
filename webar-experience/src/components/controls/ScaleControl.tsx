import { SCALE_PRESETS, type ScalePreset } from '@/types/product'

interface ScaleControlProps {
  activeScale: ScalePreset
  onCycle: () => void
}

export function ScaleControl({ activeScale, onCycle }: ScaleControlProps) {
  const label =
    SCALE_PRESETS.find((preset) => preset.value === activeScale)?.label ??
    'Actual size'

  return (
    <button
      type="button"
      className="size-btn"
      onClick={onCycle}
      aria-label="Change model size"
    >
      <span>{label}</span>
    </button>
  )
}
