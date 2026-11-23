import React, { useState } from 'react'
import { Star, MessageSquare, X, Heart, Sparkles, Send, Loader2 } from 'lucide-react'
import { tableOrderService } from '@/services/tableOrderService'

interface CustomerFeedbackModalProps {
  isOpen: boolean
  onClose: () => void
  slug: string
  tableNumber?: string
  restaurantName?: string
  initialRating?: number
  onFeedbackSubmitted?: (feedback: { rating: number; comment?: string; tags?: string[] }) => void
}

const EXPERIENCE_TAGS = [
  '🍲 Delicious Food',
  '✨ Great 3D AR Menu',
  '⚡ Fast Service',
  '🧼 Clean & Hygienic',
  '👨‍🍳 Friendly Staff',
  '💰 Value for Money',
  '🔥 Hot & Fresh',
  '🍹 Great Ambience',
]

const RATING_SENTIMENTS: Record<number, { title: string; subtitle: string; color: string }> = {
  5: {
    title: '🌟 Outstanding!',
    subtitle: 'We are thrilled you had an extraordinary time!',
    color: 'text-amber-400',
  },
  4: {
    title: '😊 Very Good!',
    subtitle: 'So glad you enjoyed your dining experience.',
    color: 'text-emerald-400',
  },
  3: {
    title: '🙂 Good Experience',
    subtitle: 'Thank you! We always strive to do better.',
    color: 'text-cyan-400',
  },
  2: {
    title: '😐 Could Be Better',
    subtitle: 'We appreciate your honesty and want to improve.',
    color: 'text-orange-400',
  },
  1: {
    title: '😞 Disappointing',
    subtitle: 'We sincerely apologize. Please let us know what went wrong.',
    color: 'text-rose-400',
  },
}

export const CustomerFeedbackModal: React.FC<CustomerFeedbackModalProps> = ({
  isOpen,
  onClose,
  slug,
  tableNumber = 'Dine-in',
  restaurantName = 'Our Restaurant',
  initialRating = 5,
  onFeedbackSubmitted,
}) => {
  const [rating, setRating] = useState<number>(initialRating)
  const [hoverRating, setHoverRating] = useState<number | null>(null)
  const [selectedTags, setSelectedTags] = useState<string[]>([])
  const [comment, setComment] = useState('')
  const [phone, setPhone] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isSubmitted, setIsSubmitted] = useState(false)
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  if (!isOpen) return null

  const activeRating = hoverRating ?? rating
  const sentiment = RATING_SENTIMENTS[activeRating] || RATING_SENTIMENTS[5]

  const toggleTag = (tag: string) => {
    setSelectedTags((prev) =>
      prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag],
    )
  }

  const handleSubmit = async (e?: React.FormEvent) => {
    if (e) e.preventDefault()
    if (isSubmitting) return

    setIsSubmitting(true)
    setErrorMessage(null)

    try {
      const res = await tableOrderService.submitFeedback(slug, tableNumber, {
        rating,
        comment: comment.trim() || undefined,
        tags: selectedTags,
        customerPhone: phone.trim() || undefined,
      })

      if (res.success) {
        setIsSubmitted(true)
        onFeedbackSubmitted?.({
          rating,
          comment: comment.trim() || undefined,
          tags: selectedTags,
        })
        try {
          sessionStorage.setItem(`ar_feedback_submitted_${tableNumber}`, 'true')
        } catch (_) {}
      } else {
        setErrorMessage(res.message || 'Unable to submit feedback. Please try again.')
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Something went wrong. Please try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-md bg-[#131b2e] border border-white/10 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
        {/* Modal Header */}
        <div className="relative px-6 pt-6 pb-4 border-b border-white/10 bg-gradient-to-b from-white/5 to-transparent flex items-start justify-between">
          <div className="pr-6">
            <div className="flex items-center gap-2">
              <span className="p-1.5 rounded-xl bg-amber-500/15 border border-amber-500/30 text-amber-400">
                <Sparkles className="w-4 h-4" />
              </span>
              <h3 className="text-lg font-bold text-white tracking-wide">
                {isSubmitted ? 'Thank You!' : 'Rate Your Experience'}
              </h3>
            </div>
            <p className="text-xs text-gray-400 mt-1">
              {restaurantName} • Table {tableNumber}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 text-gray-400 hover:text-white rounded-full bg-white/5 hover:bg-white/10 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-6">
          {isSubmitted ? (
            <div className="py-6 text-center space-y-4">
              <div className="w-16 h-16 mx-auto rounded-full bg-emerald-500/20 border border-emerald-500/40 flex items-center justify-center text-emerald-400 animate-bounce">
                <Heart className="w-8 h-8 fill-emerald-400/30" />
              </div>
              <div>
                <h4 className="text-xl font-bold text-white">We Appreciate You!</h4>
                <p className="text-sm text-gray-300 mt-1 max-w-xs mx-auto">
                  Your feedback helps us continuously elevate your dining and AR experience.
                </p>
              </div>
              <div className="pt-2 flex justify-center gap-1.5">
                {Array.from({ length: rating }).map((_, i) => (
                  <Star key={i} className="w-6 h-6 fill-amber-400 text-amber-400" />
                ))}
              </div>
              <div className="pt-4">
                <button
                  type="button"
                  onClick={onClose}
                  className="w-full py-3 px-4 rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white font-bold text-sm shadow-lg shadow-amber-500/20 transition active:scale-95"
                >
                  Done
                </button>
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-5">
              {/* Star Rating Section */}
              <div className="text-center space-y-2 py-1">
                <div className="flex justify-center items-center gap-2">
                  {[1, 2, 3, 4, 5].map((starVal) => {
                    const isLit = starVal <= activeRating
                    return (
                      <button
                        key={starVal}
                        type="button"
                        onClick={() => setRating(starVal)}
                        onMouseEnter={() => setHoverRating(starVal)}
                        onMouseLeave={() => setHoverRating(null)}
                        className="p-1 transition transform hover:scale-125 active:scale-95 focus:outline-none"
                      >
                        <Star
                          className={`w-9 h-9 transition-colors ${
                            isLit
                              ? 'fill-amber-400 text-amber-400 drop-shadow-[0_0_8px_rgba(251,191,36,0.5)]'
                              : 'text-gray-600 hover:text-gray-400'
                          }`}
                        />
                      </button>
                    )
                  })}
                </div>
                <div className="min-h-[44px]">
                  <p className={`text-sm font-bold ${sentiment.color}`}>
                    {sentiment.title}
                  </p>
                  <p className="text-xs text-gray-400 mt-0.5">
                    {sentiment.subtitle}
                  </p>
                </div>
              </div>

              {/* Experience Tags */}
              <div className="space-y-2">
                <label className="text-xs font-semibold text-gray-300 uppercase tracking-wider block">
                  What did you like the most?
                </label>
                <div className="flex flex-wrap gap-2">
                  {EXPERIENCE_TAGS.map((tag) => {
                    const isSelected = selectedTags.includes(tag)
                    return (
                      <button
                        key={tag}
                        type="button"
                        onClick={() => toggleTag(tag)}
                        className={`text-xs px-3 py-1.5 rounded-full font-medium transition-all ${
                          isSelected
                            ? 'bg-amber-500/20 text-amber-300 border border-amber-500/50 shadow-sm shadow-amber-500/20'
                            : 'bg-white/5 text-gray-300 border border-white/10 hover:bg-white/10'
                        }`}
                      >
                        {tag}
                      </button>
                    )
                  })}
                </div>
              </div>

              {/* Review / Comments */}
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-300 uppercase tracking-wider flex items-center gap-1.5">
                  <MessageSquare className="w-3.5 h-3.5 text-gray-400" />
                  Your comments or suggestions (Optional)
                </label>
                <textarea
                  rows={3}
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  placeholder="Tell us what stood out or what we could improve..."
                  className="w-full text-xs p-3 rounded-xl bg-black/40 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-amber-500/50 transition resize-none"
                />
              </div>

              {/* Optional Phone Number */}
              <div className="space-y-1">
                <label className="text-[11px] font-semibold text-gray-400 block">
                  Mobile Number (Optional, for bill & special rewards)
                </label>
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="e.g. 9876543210"
                  className="w-full text-xs px-3 py-2.5 rounded-xl bg-black/40 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-amber-500/50 transition"
                />
              </div>

              {/* Error Message */}
              {errorMessage && (
                <div className="p-2.5 rounded-xl bg-rose-500/15 border border-rose-500/30 text-rose-300 text-xs">
                  {errorMessage}
                </div>
              )}

              {/* Submit Button */}
              <div className="pt-2">
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full py-3 px-4 rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 hover:from-amber-600 hover:to-orange-600 text-white font-bold text-sm shadow-lg shadow-amber-500/20 transition flex items-center justify-center gap-2 active:scale-95 disabled:opacity-50"
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      <span>Submitting...</span>
                    </>
                  ) : (
                    <>
                      <Send className="w-4 h-4" />
                      <span>Submit Feedback</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  )
}
