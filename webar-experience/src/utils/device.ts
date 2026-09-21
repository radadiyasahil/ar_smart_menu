export interface DeviceCapabilities {
  isMobile: boolean
  isIOS: boolean
  isAndroid: boolean
  supportsWebXR: boolean
  supportsSceneViewer: boolean
  deviceType: 'mobile' | 'desktop'
  platform: 'ios' | 'android' | 'web'
}

export function getDeviceInfo(): Pick<DeviceCapabilities, 'deviceType' | 'platform'> {
  const ua = navigator.userAgent
  const isIOS = /iPad|iPhone|iPod/.test(ua)
  const isAndroid = /Android/.test(ua)
  return {
    deviceType: /Mobi|Android/i.test(ua) ? 'mobile' : 'desktop',
    platform: isIOS ? 'ios' : isAndroid ? 'android' : 'web',
  }
}

export function getDeviceCapabilities(): DeviceCapabilities {
  const ua = navigator.userAgent
  const isIOS = /iPad|iPhone|iPod/.test(ua)
  const isAndroid = /Android/.test(ua)
  const isMobile = /Mobi|Android/i.test(ua)
  const info = getDeviceInfo()

  return {
    isMobile,
    isIOS,
    isAndroid,
    supportsWebXR: 'xr' in navigator,
    supportsSceneViewer: isAndroid,
    deviceType: info.deviceType,
    platform: info.platform,
  }
}

/** WebAR works on mobile Chrome/Safari; desktop gets 3D-only fallback. */
export function isBrowserSupported(): boolean {
  return typeof window !== 'undefined' && 'customElements' in window
}
