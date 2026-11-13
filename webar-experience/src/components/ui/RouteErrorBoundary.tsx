import { useRouteError, isRouteErrorResponse, Link } from 'react-router-dom'
import { RotateCw, Home, AlertCircle } from 'lucide-react'

export function RouteErrorBoundary() {
  const error = useRouteError()

  let errorMessage = 'An unexpected error occurred.'
  if (isRouteErrorResponse(error)) {
    errorMessage = `${error.status} ${error.statusText}: ${error.data || 'Page not found'}`
  } else if (error instanceof Error) {
    errorMessage = error.message
  }

  return (
    <div className="min-h-screen bg-[#121319] text-white flex flex-col items-center justify-center p-6 text-center select-none">
      <div className="w-16 h-16 rounded-full bg-red-500/10 border border-red-500/25 flex items-center justify-center mb-4 text-red-400">
        <AlertCircle size={32} />
      </div>
      <h1 className="text-xl font-bold mb-2">Something went wrong</h1>
      <p className="text-xs text-gray-400 max-w-sm mb-6 leading-relaxed">
        {errorMessage || 'We encountered a momentary glitch. Please reload or return home.'}
      </p>
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => window.location.reload()}
          className="px-5 py-2.5 rounded-full bg-gradient-to-r from-[#FF5353] to-[#FF7043] text-white text-xs font-bold flex items-center gap-2 shadow-lg shadow-[#FF5353]/30 hover:opacity-90 active:scale-95 transition cursor-pointer"
        >
          <RotateCw size={14} />
          <span>Reload Page</span>
        </button>
        <Link
          to="/"
          className="px-4 py-2.5 rounded-full bg-white/10 hover:bg-white/15 border border-white/10 text-white text-xs font-medium flex items-center gap-1.5 transition"
        >
          <Home size={14} />
          <span>Home</span>
        </Link>
      </div>
    </div>
  )
}
