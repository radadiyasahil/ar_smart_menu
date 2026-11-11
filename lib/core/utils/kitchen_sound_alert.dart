import 'kitchen_sound_alert_stub.dart'
    if (dart.library.js_interop) 'kitchen_sound_alert_web.dart';

class KitchenSoundAlert {
  KitchenSoundAlert._();

  static DateTime _lastAlertTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Plays a distinctive 2-tone chime ("Ding-dong!") for new table orders.
  static void playNewOrderAlert() {
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inMilliseconds < 1500) return;
    _lastAlertTime = now;

    playAlertTone(frequency: 659.25, durationSeconds: 0.25); // E5
    Future.delayed(const Duration(milliseconds: 180), () {
      playAlertTone(frequency: 880.0, durationSeconds: 0.35); // A5
    });
  }

  /// Plays a high-pitch single chime for waiter call.
  static void playWaiterCallAlert() {
    final now = DateTime.now();
    if (now.difference(_lastAlertTime).inMilliseconds < 1500) return;
    _lastAlertTime = now;

    playAlertTone(frequency: 783.99, durationSeconds: 0.2); // G5
    Future.delayed(const Duration(milliseconds: 150), () {
      playAlertTone(frequency: 1046.50, durationSeconds: 0.3); // C6
    });
  }
}
