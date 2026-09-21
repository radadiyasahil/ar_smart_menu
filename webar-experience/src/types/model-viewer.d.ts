import type { DetailedHTMLProps, HTMLAttributes } from 'react'

export interface ModelViewerAttributes extends HTMLAttributes<HTMLElement> {
  src?: string
  'ios-src'?: string
  alt?: string
  ar?: boolean
  'ar-modes'?: string
  'camera-controls'?: boolean
  'touch-action'?: string
  'auto-rotate'?: boolean
  'shadow-intensity'?: string
  exposure?: string
  'environment-image'?: string
  'interaction-prompt'?: string
  'ar-placement'?: string
  'ar-scale'?: string
  scale?: string
  orientation?: string
  loading?: 'auto' | 'lazy' | 'eager'
  poster?: string
  reveal?: string
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
  }
}

export {}
