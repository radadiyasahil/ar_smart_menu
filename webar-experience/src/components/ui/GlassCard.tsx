import { cn } from '@/utils/cn'
import type { HTMLAttributes, ReactNode } from 'react'

interface GlassCardProps extends HTMLAttributes<HTMLDivElement> {
  children: ReactNode
}

/** Translucent glass card for AR overlay UI. */
export function GlassCard({ className, children, ...props }: GlassCardProps) {
  return (
    <div
      className={cn(
        'glass-card rounded-2xl shadow-xl shadow-black/20',
        className,
      )}
      {...props}
    >
      {children}
    </div>
  )
}
