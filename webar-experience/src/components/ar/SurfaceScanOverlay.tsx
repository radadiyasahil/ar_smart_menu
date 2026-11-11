import { ScanLine } from 'lucide-react'

interface SurfaceScanOverlayProps {
  visible: boolean
  message?: string
}

/**
 * Animated surface detection prompt shown before AR placement.
 * Hidden automatically after object is placed in AR.
 */
export function SurfaceScanOverlay({
  visible,
  message = 'Move phone slowly to detect surface',
}: SurfaceScanOverlayProps) {
  if (!visible) return null

  return (
    <div className="pointer-events-none absolute inset-0 z-10 flex flex-col items-center justify-center">
      {/* Animated detection grid */}
      <div className="relative h-48 w-48">
        <div className="absolute inset-0 animate-pulse rounded-2xl border-2 border-dashed border-primary/60" />
        <div
          className="absolute inset-2 animate-ping rounded-xl border border-white/20"
          style={{ animationDuration: '2s' }}
        />
        <div className="absolute inset-4 rounded-lg bg-primary/5 backdrop-blur-sm" />
        <div className="absolute inset-0 flex items-center justify-center">
          <ScanLine className="h-10 w-10 text-primary animate-pulse" />
        </div>
      </div>

      <p className="mt-6 max-w-[260px] text-center text-sm font-medium text-white/90 drop-shadow-lg">
        {message}
      </p>
      <p className="mt-2 text-xs text-white/60">
        Point camera at a flat table or floor
      </p>
    </div>
  )
}
