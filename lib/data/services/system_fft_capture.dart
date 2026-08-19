import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Captures FFT magnitudes from the Android Visualizer API for an ExoPlayer
/// audio session. No-op on other platforms.
class SystemFftCapture {
  static const _methods = MethodChannel('dev.csy20.nen/visualizer');
  static const _events = EventChannel('dev.csy20.nen/visualizer/fft');

  final List<double> buffer = List<double>.filled(256, 0.0);
  StreamSubscription<dynamic>? _sub;
  int? _sessionId;
  bool _live = false;
  int _lastUpdateMs = 0;

  bool get hasFreshData {
    if (!_live) return false;
    return DateTime.now().millisecondsSinceEpoch - _lastUpdateMs < 400;
  }

  Future<void> attach(int? sessionId) async {
    if (!Platform.isAndroid) return;
    if (sessionId == null || sessionId <= 0) {
      await detach();
      return;
    }
    if (_sessionId == sessionId && _live) return;
    await detach();
    _sessionId = sessionId;
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted && !mic.isLimited) {
        debugPrint('visualizer: RECORD_AUDIO not granted, using fallback FFT');
        return;
      }
      _sub = _events.receiveBroadcastStream().listen(_onFft, onError: (e) {
        debugPrint('visualizer stream error: $e');
        _live = false;
      });
      await _methods.invokeMethod<bool>('start', sessionId);
    } catch (e) {
      debugPrint('visualizer start failed: $e');
      await detach();
    }
  }

  void _onFft(dynamic event) {
    if (event is! List) return;
    final n = event.length < buffer.length ? event.length : buffer.length;
    for (var i = 0; i < n; i++) {
      final v = event[i];
      buffer[i] = v is num ? v.toDouble().clamp(0.0, 1.0) : 0.0;
    }
    for (var i = n; i < buffer.length; i++) {
      buffer[i] = 0.0;
    }
    _live = true;
    _lastUpdateMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool copyInto(List<double> dest) {
    if (!hasFreshData) return false;
    final n = dest.length < buffer.length ? dest.length : buffer.length;
    for (var i = 0; i < n; i++) {
      dest[i] = buffer[i];
    }
    for (var i = n; i < dest.length; i++) {
      dest[i] = 0.0;
    }
    return true;
  }

  Future<void> detach() async {
    _live = false;
    _sessionId = null;
    await _sub?.cancel();
    _sub = null;
    if (!Platform.isAndroid) return;
    try {
      await _methods.invokeMethod<void>('stop');
    } catch (_) {}
  }
}
