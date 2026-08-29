import 'package:flutter/foundation.dart';

/// Former Android Visualizer client.
///
/// Session Visualizer JNI aborts the process on many Play devices, so attach
/// is a permanent no-op. Bars use a Dart-only playing pulse instead.
class SystemFftCapture {
  final List<double> buffer = List<double>.filled(256, 0.0);

  bool get hasFreshData => false;

  Future<void> attach(int? sessionId) async {
    debugPrint('visualizer attach skipped (disabled for stability)');
  }

  bool copyInto(List<double> dest) {
    for (var i = 0; i < dest.length; i++) {
      dest[i] = 0.0;
    }
    return false;
  }

  Future<void> detach() async {}
}
