import { useCallback, useEffect, useState } from 'react'

import type { CameraPermissionState } from '@/types/product'

/**
 * Tracks camera / AR permission state.
 * WebXR permissions are requested when AR session starts — we surface UI accordingly.
 */
export function useCameraPermission() {
  const [permission, setPermission] = useState<CameraPermissionState>('prompt')
  const [isChecking, setIsChecking] = useState(true)

  useEffect(() => {
    async function checkPermission() {
      if (!navigator.mediaDevices?.getUserMedia) {
        setPermission('unsupported')
        setIsChecking(false)
        return
      }

      try {
        // Query permission API if available (not on all browsers)
        const permStatus = await navigator.permissions
          ?.query({ name: 'camera' as PermissionName })
          .catch(() => null)

        if (permStatus) {
          setPermission(permStatus.state as CameraPermissionState)
          permStatus.onchange = () => {
            setPermission(permStatus.state as CameraPermissionState)
          }
        } else {
          setPermission('prompt')
        }
      } catch {
        setPermission('prompt')
      } finally {
        setIsChecking(false)
      }
    }

    void checkPermission()
  }, [])

  const requestCameraAccess = useCallback(async (): Promise<boolean> => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true })
      stream.getTracks().forEach((t) => t.stop())
      setPermission('granted')
      return true
    } catch {
      setPermission('denied')
      return false
    }
  }, [])

  return { permission, isChecking, requestCameraAccess }
}
