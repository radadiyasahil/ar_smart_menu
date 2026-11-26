import type { DetailedHTMLProps, HTMLAttributes, Ref } from 'react'

export interface ModelViewerAttributes extends HTMLAttributes<HTMLElement> {
  src?: string
  'ios-src'?: string
  alt?: string
  ar?: boolean
  'ar-modes'?: string
  'camera-controls'?: boolean | string
  'touch-action'?: string
  'auto-rotate'?: boolean | string
  'auto-rotate-delay'?: string
  'rotation-per-second'?: string
  'shadow-intensity'?: string | number
  'shadow-softness'?: string | number
  exposure?: string | number
  'environment-image'?: string
  'interaction-prompt'?: string
  'ar-placement'?: string
  'ar-scale'?: string
  'camera-orbit'?: string
  'field-of-view'?: string
  scale?: string
  orientation?: string
  loading?: 'auto' | 'lazy' | 'eager'
  poster?: string
  reveal?: string
  ref?: Ref<HTMLElement | null>
}

declare module 'react' {
  namespace JSX {
    interface IntrinsicElements {
      'model-viewer': DetailedHTMLProps<ModelViewerAttributes, HTMLElement>
    }
  }
}

declare global {
  interface HTMLElement {
    toDataURL?: (type?: string) => string
    activateAR?: () => Promise<void>
    canActivateAR?: boolean
  }
}

export {}
