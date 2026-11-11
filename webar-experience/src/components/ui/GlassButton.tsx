import { cn } from '@/utils/cn'
import type { ButtonHTMLAttributes, ReactNode } from 'react'

interface GlassButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'ghost' | 'outline'
  children: ReactNode
}

/** Touch-friendly glassmorphism button for AR overlays. */
export function GlassButton({
  variant = 'ghost',
  className,
  children,
  ...props
}: GlassButtonProps) {
  return (
    <button
      type="button"
      className={cn(
        'inline-flex min-h-[44px] min-w-[44px] items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition-all active:scale-95',
        variant === 'primary' &&
          'bg-primary text-white shadow-lg shadow-primary/30 hover:bg-primary-dark',
        variant === 'ghost' &&
          'glass-card text-white hover:bg-white/20',
        variant === 'outline' &&
          'border border-white/25 text-white hover:bg-white/10',
        className,
      )}
      {...props}
    >
      {children}
    </button>
  )
}
