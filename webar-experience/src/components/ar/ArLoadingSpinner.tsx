import { Loader2 } from 'lucide-react'

/** Centered loading spinner for 3D model fetch. */
export function ArLoadingSpinner({ label = 'Loading 3D model...' }: { label?: string }) {
  return (
    <div className="pointer-events-none absolute inset-0 z-20 flex flex-col items-center justify-center bg-black/40">
      <Loader2 className="h-10 w-10 animate-spin text-primary" />
      <p className="mt-3 text-sm font-medium text-white/90">{label}</p>
    </div>
  )
}
