import 'kitchen_sound_alert_stub.dart'
    if (dart.library.js_interop) 'kitchen_sound_alert_web.dart';

class KitchenSoundAlert {
  KitchenSoundAlert._();

  static DateTime _lastAlertTime = DateTime.fromMillisecondsSinceEpoch(0);

  static bool _canPlay() {
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inMilliseconds < 800) return false;
    _lastAlertTime = now;
    return true;
  }

  /// Plays a distinctive 2-tone chime ("Ding-dong!") for new table orders.
  static void playNewOrderAlert() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 659.25, durationSeconds: 0.25); // E5
    Future.delayed(const Duration(milliseconds: 180), () {
      playAlertTone(frequency: 880.0, durationSeconds: 0.35); // A5
    });
  }

  /// Plays a high-pitch single chime for waiter call.
  static void playWaiterCallAlert() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 783.99, durationSeconds: 0.2); // G5
    Future.delayed(const Duration(milliseconds: 150), () {
      playAlertTone(frequency: 1046.50, durationSeconds: 0.3); // C6
    });
  }

  /// Plays an ascending 3-tone chime when customer requests the final bill.
  static void playBillRequestAlert() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 880.0, durationSeconds: 0.2); // A5
    Future.delayed(const Duration(milliseconds: 150), () {
      playAlertTone(frequency: 1108.73, durationSeconds: 0.2); // C#6
      Future.delayed(const Duration(milliseconds: 150), () {
        playAlertTone(frequency: 1318.51, durationSeconds: 0.35); // E6
      });
    });
  }

  /// Plays a reassuring harmonic chime when an order is accepted to kitchen.
  static void playOrderAcceptedChime() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 587.33, durationSeconds: 0.18); // D5
    Future.delayed(const Duration(milliseconds: 130), () {
      playAlertTone(frequency: 739.99, durationSeconds: 0.18); // F#5
      Future.delayed(const Duration(milliseconds: 130), () {
        playAlertTone(frequency: 880.0, durationSeconds: 0.3); // A5
      });
    });
  }

  /// Plays a cheerful flourish chime when dishes are marked ready / served.
  static void playOrderServedChime() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 783.99, durationSeconds: 0.18); // G5
    Future.delayed(const Duration(milliseconds: 130), () {
      playAlertTone(frequency: 1046.50, durationSeconds: 0.18); // C6
      Future.delayed(const Duration(milliseconds: 130), () {
        playAlertTone(frequency: 1318.51, durationSeconds: 0.35); // E6
      });
    });
  }

  /// Plays a descending alert tone when an order is cancelled or rejected.
  static void playOrderCancelledTone() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 698.46, durationSeconds: 0.22); // F5
    Future.delayed(const Duration(milliseconds: 160), () {
      playAlertTone(frequency: 587.33, durationSeconds: 0.3); // D5
    });
  }

  /// Plays a settlement flourish chime when a table bill is paid & closed.
  static void playBillSettledTone() {
    if (!_canPlay()) return;

    playAlertTone(frequency: 523.25, durationSeconds: 0.16); // C5
    Future.delayed(const Duration(milliseconds: 120), () {
      playAlertTone(frequency: 659.25, durationSeconds: 0.16); // E5
      Future.delayed(const Duration(milliseconds: 120), () {
        playAlertTone(frequency: 783.99, durationSeconds: 0.16); // G5
        Future.delayed(const Duration(milliseconds: 120), () {
          playAlertTone(frequency: 1046.50, durationSeconds: 0.4); // C6
        });
      });
    });
  }

  /// Dispatches the appropriate alert sound based on order status transition.
  static void playOrderStatusChangedAlert({required String status}) {
    switch (status.toUpperCase()) {
      case 'ACCEPTED':
        playOrderAcceptedChime();
        break;
      case 'COMPLETED':
      case 'SERVED':
        playOrderServedChime();
        break;
      case 'CANCELLED':
        playOrderCancelledTone();
        break;
    }
  }
}
