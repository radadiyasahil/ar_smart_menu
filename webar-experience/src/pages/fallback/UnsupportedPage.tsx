import { AlertTriangle, RefreshCw, Smartphone } from 'lucide-react'
import { Link } from 'react-router-dom'

import { GlassButton } from '@/components/ui/GlassButton'
import { GlassCard } from '@/components/ui/GlassCard'
import { getDeviceCapabilities } from '@/utils/device'

/** Fallback UI for unsupported mobile browsers. */
export function UnsupportedPage() {
  const caps = getDeviceCapabilities()

  return (
    <div className="flex min-h-full flex-col items-center justify-center bg-background p-6">
      <GlassCard className="max-w-md p-8 text-center">
        <Smartphone className="mx-auto h-14 w-14 text-primary" />
        <h1 className="mt-4 text-xl font-bold text-white">
          AR Not Supported
        </h1>
        <p className="mt-3 text-sm text-white/70">
          This WebAR experience requires a modern mobile browser with AR support.
        </p>
        <ul className="mt-4 space-y-2 text-left text-xs text-white/60">
          <li>• Android: Chrome browser recommended</li>
          <li>• iPhone: Safari with AR Quick Look</li>
          <li>• Your device: {caps.platform}</li>
        </ul>
        <GlassButton
          variant="primary"
          className="mt-6 w-full"
          onClick={() => window.location.reload()}
        >
          <RefreshCw className="h-4 w-4" />
          Retry
        </GlassButton>
        <Link
          to="/"
          className="mt-4 block text-xs text-white/50 underline"
        >
          Go back
        </Link>
      </GlassCard>
    </div>
  )
}

interface ModelErrorOverlayProps {
  message: string
  onRetry: () => void
}

/** Failed model loading UI with retry. */
export function ModelErrorOverlay({ message, onRetry }: ModelErrorOverlayProps) {
  return (
    <div className="absolute inset-0 z-40 flex items-center justify-center bg-black/80 p-6">
      <GlassCard className="max-w-sm p-6 text-center">
        <AlertTriangle className="mx-auto h-12 w-12 text-primary" />
        <h2 className="mt-4 text-lg font-bold text-white">Model Failed to Load</h2>
        <p className="mt-2 text-sm text-white/70">{message}</p>
        <GlassButton variant="primary" className="mt-6 w-full" onClick={onRetry}>
          <RefreshCw className="h-4 w-4" />
          Retry
        </GlassButton>
      </GlassCard>
    </div>
  )
}
