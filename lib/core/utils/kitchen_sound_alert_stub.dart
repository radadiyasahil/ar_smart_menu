import 'package:flutter/services.dart';

void playAlertTone({double frequency = 587.33, double durationSeconds = 0.2}) {
  SystemSound.play(SystemSoundType.alert);
  HapticFeedback.mediumImpact();
}
