import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

void playAlertTone({double frequency = 587.33, double durationSeconds = 0.2}) {
  try {
    final ctx = web.AudioContext();
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.type = 'sine';
    osc.frequency.setValueAtTime(frequency, ctx.currentTime);

    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + durationSeconds);

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    osc.stop(ctx.currentTime + durationSeconds);
  } catch (_) {
    SystemSound.play(SystemSoundType.alert);
  }
}
