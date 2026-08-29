import 'package:flutter/foundation.dart';

/// Former Android session-Equalizer client.
///
/// `android.media.audiofx.Equalizer` construction native-aborts on several
/// OEMs, so this never talks to a platform channel.
class SystemEqualizer {
  bool get isAttached => false;

  Future<bool> attach(int? sessionId) async {
    debugPrint('system equalizer attach skipped (disabled for stability)');
    return false;
  }

  Future<void> detach() async {}

  Future<void> setEnabled(bool enabled) async {}

  Future<void> setBand(int band, double gain) async {}

  Future<void> setBands(List<double> bands) async {}

  Future<void> reset() async {}
}

/// UI mapping used by EqualizerScreen: 1.0 → 0 dB, 2.0 → +12 dB.
int eqGainToMillibels(double gain, {int minMb = -1500, int maxMb = 1500}) {
  final db = (gain.clamp(0.0, 4.0) - 1.0) * 12.0;
  final mb = (db * 100.0).round();
  if (mb < minMb) return minMb;
  if (mb > maxMb) return maxMb;
  return mb;
}
