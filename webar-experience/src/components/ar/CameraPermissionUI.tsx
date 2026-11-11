import { Camera, ShieldAlert } from 'lucide-react'

import { GlassButton } from '@/components/ui/GlassButton'
import { GlassCard } from '@/components/ui/GlassCard'
import type { CameraPermissionState } from '@/types/product'

interface CameraPermissionUIProps {
  permission: CameraPermissionState
  isChecking: boolean
  onRequestAccess: () => void
  onContinueWithoutAr?: () => void
}

/** Camera permission prompt shown before AR session. */
export function CameraPermissionUI({
  permission,
  isChecking,
  onRequestAccess,
  onContinueWithoutAr,
}: CameraPermissionUIProps) {
  if (isChecking) return null

  if (permission === 'granted') return null

  if (permission === 'denied' || permission === 'unsupported') {
    return (
      <div className="absolute inset-0 z-40 flex items-center justify-center bg-black/80 p-6">
        <GlassCard className="max-w-sm p-6 text-center">
          <ShieldAlert className="mx-auto h-12 w-12 text-danger" />
          <h2 className="mt-4 text-lg font-bold text-white">
            {permission === 'unsupported'
              ? 'Camera Not Available'
              : 'Camera Access Denied'}
          </h2>
          <p className="mt-2 text-sm text-white/70">
            {permission === 'unsupported'
              ? 'Your browser does not support camera access required for AR.'
              : 'Enable camera permission in browser settings to use AR features.'}
          </p>
          {onContinueWithoutAr && (
            <GlassButton
              variant="outline"
              className="mt-6 w-full"
              onClick={onContinueWithoutAr}
            >
              Preview 3D Without AR
            </GlassButton>
          )}
        </GlassCard>
      </div>
    )
  }

  // prompt state
  return (
    <div className="absolute inset-0 z-40 flex items-end justify-center bg-gradient-to-t from-black/80 via-black/40 to-transparent p-6 pb-32">
      <GlassCard className="w-full max-w-sm p-5">
        <div className="flex items-start gap-4">
          <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-primary/20">
            <Camera className="h-6 w-6 text-primary" />
          </div>
          <div>
            <h2 className="font-bold text-white">Camera Access Needed</h2>
            <p className="mt-1 text-sm text-white/70">
              Allow camera access to place products on your table in augmented
              reality.
            </p>
          </div>
        </div>
        <GlassButton
          variant="primary"
          className="mt-5 w-full"
          onClick={onRequestAccess}
        >
          Allow Camera
        </GlassButton>
        {onContinueWithoutAr && (
          <button
            type="button"
            className="mt-3 w-full text-center text-xs text-white/50 underline"
            onClick={onContinueWithoutAr}
          >
            Skip — preview in 3D only
          </button>
        )}
      </GlassCard>
    </div>
  )
}
