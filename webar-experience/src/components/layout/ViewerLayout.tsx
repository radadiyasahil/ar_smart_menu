import type { ReactNode } from 'react'

interface ViewerLayoutProps {
  children: ReactNode
}

/** Full-viewport layout wrapper for immersive AR experience. */
export function ViewerLayout({ children }: ViewerLayoutProps) {
  return (
    <div className="h-full w-full max-w-[100vw] overflow-hidden">
      {children}
    </div>
  )
}
