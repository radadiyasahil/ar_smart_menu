/**
 * Zero-dependency Web Audio API sound alerts for customer WebAR digital menu.
 * Works seamlessly across iOS Safari, Android Chrome, and Desktop browsers.
 */

class SoundAlertManager {
  private ctx: AudioContext | null = null
  private isUnlocked = false

  private getAudioContext(): AudioContext | null {
    if (typeof window === 'undefined') return null
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as any).webkitAudioContext
      if (AudioCtx) {
        this.ctx = new AudioCtx()
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {})
    }
    return this.ctx
  }

  /**
   * Must be called on user interaction (tap, click, scroll) to satisfy browser autoplay policies.
   */
  public unlock() {
    if (this.isUnlocked) return
    const ctx = this.getAudioContext()
    if (!ctx) return

    if (ctx.state === 'suspended') {
      ctx.resume().then(() => {
        this.isUnlocked = true
      }).catch(() => {})
    } else {
      this.isUnlocked = true
    }
  }

  private playTone(frequency: number, durationSeconds: number, type: OscillatorType = 'sine', volume: number = 0.25) {
    try {
      const ctx = this.getAudioContext()
      if (!ctx) return

      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.type = type
      osc.frequency.setValueAtTime(frequency, ctx.currentTime)

      gain.gain.setValueAtTime(volume, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + durationSeconds)

      osc.connect(gain)
      gain.connect(ctx.destination)

      osc.start()
      osc.stop(ctx.currentTime + durationSeconds)
    } catch {
      // AudioContext unavailable or blocked by browser policy
    }
  }

  /**
   * Positive ascending 2-tone chime when an order is placed (C5 -> G5).
   */
  public playOrderPlaced() {
    this.unlock()
    this.playTone(523.25, 0.22, 'sine', 0.25) // C5
    setTimeout(() => {
      this.playTone(783.99, 0.35, 'sine', 0.28) // G5
    }, 150)
  }

  /**
   * Melodic 3-tone chime when kitchen accepts the customer's order (E5 -> G5 -> C6).
   */
  public playOrderAccepted() {
    this.unlock()
    this.playTone(659.25, 0.2, 'sine', 0.25) // E5
    setTimeout(() => {
      this.playTone(783.99, 0.2, 'sine', 0.28) // G5
      setTimeout(() => {
        this.playTone(1046.5, 0.45, 'triangle', 0.3) // C6
      }, 140)
    }, 140)
  }

  /**
   * Joyful ready / served arpeggio when food is marked served (G5 -> C6 -> E6).
   */
  public playOrderServed() {
    this.unlock()
    this.playTone(783.99, 0.2, 'sine', 0.26) // G5
    setTimeout(() => {
      this.playTone(1046.5, 0.2, 'sine', 0.28) // C6
      setTimeout(() => {
        this.playTone(1318.51, 0.5, 'triangle', 0.32) // E6
      }, 150)
    }, 150)
  }

  /**
   * Descending 2-tone notification when an order is cancelled / declined (F5 -> D5).
   */
  public playOrderCancelled() {
    this.unlock()
    this.playTone(698.46, 0.22, 'triangle', 0.25) // F5
    setTimeout(() => {
      this.playTone(587.33, 0.35, 'sine', 0.22) // D5
    }, 180)
  }

  /**
   * Clear, resonant bell chime when ringing the waiter (D6).
   */
  public playWaiterCalled() {
    this.unlock()
    this.playTone(1174.66, 0.5, 'sine', 0.35) // D6
    setTimeout(() => {
      this.playTone(1174.66, 0.3, 'triangle', 0.15)
    }, 100)
  }

  /**
   * Dual bell chime when requesting the final bill (B5 -> E6).
   */
  public playBillRequested() {
    this.unlock()
    this.playTone(987.77, 0.25, 'sine', 0.28) // B5
    setTimeout(() => {
      this.playTone(1318.51, 0.5, 'triangle', 0.32) // E6
    }, 160)
  }

  /**
   * Harmonious celebration flourish when bill is settled & table closed (C5 -> E5 -> G5 -> C6).
   */
  public playBillSettled() {
    this.unlock()
    const notes = [523.25, 659.25, 783.99, 1046.5]
    notes.forEach((freq, idx) => {
      setTimeout(() => {
        this.playTone(freq, idx === notes.length - 1 ? 0.6 : 0.25, idx === 3 ? 'triangle' : 'sine', 0.26)
      }, idx * 130)
    })
  }
}

export const soundAlerts = new SoundAlertManager()

// Unlock audio on initial user interaction anywhere in the window
if (typeof window !== 'undefined') {
  const handleInteraction = () => {
    soundAlerts.unlock()
    window.removeEventListener('click', handleInteraction)
    window.removeEventListener('touchstart', handleInteraction)
  }
  window.addEventListener('click', handleInteraction, { once: true, passive: true })
  window.addEventListener('touchstart', handleInteraction, { once: true, passive: true })
}
