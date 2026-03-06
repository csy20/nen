import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';

/// Implementation of [AudioRepository] using flutter_soloud (C++ engine).
class AudioRepositoryImpl implements AudioRepository {
  final SoLoud _soloud = SoLoud.instance;
  SoundHandle? _currentHandle;
  AudioSource? _currentSource;
  bool _initialized = false;
  AudioData? _audioData;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  Timer? _positionTimer;
  AudioSource? _preloadedSource;
  bool _completionFired = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _soloud.init();
    _soloud.setVisualizationEnabled(true);
    // Allocate AudioData for linear FFT+wave samples
    _audioData = AudioData(GetSamplesKind.linear);
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _positionTimer?.cancel();
    _positionController.close();
    _completionController.close();
    _audioData?.dispose();
    if (_currentSource != null) {
      await _soloud.disposeSource(_currentSource!);
    }
    if (_initialized) {
      _soloud.deinit();
      _initialized = false;
    }
  }

  @override
  Future<void> play(Song song) async {
    if (!_initialized) await initialize();

    // Dispose previous source
    if (_currentSource != null) {
      await _soloud.disposeSource(_currentSource!);
      _currentSource = null;
      _currentHandle = null;
    }

    // Load from disk for large file streaming
    _currentSource = await _soloud.loadFile(
      song.filePath,
      mode: LoadMode.disk,
    );

    _currentHandle = await _soloud.play(_currentSource!);
    _completionFired = false;

    _startPositionTracking();
  }

  @override
  Future<void> preload(Song song) async {
    if (!_initialized) await initialize();
    // Dispose any previous preloaded source
    if (_preloadedSource != null) {
      try { await _soloud.disposeSource(_preloadedSource!); } catch (_) {}
    }
    _preloadedSource = await _soloud.loadFile(
      song.filePath,
      mode: LoadMode.disk,
    );
  }

  @override
  Future<void> playPreloaded() async {
    if (_preloadedSource == null) return;
    // Stop current
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
    }
    if (_currentSource != null) {
      await _soloud.disposeSource(_currentSource!);
    }
    _currentSource = _preloadedSource;
    _preloadedSource = null;
    _currentHandle = await _soloud.play(_currentSource!);
    _completionFired = false;
    _startPositionTracking();
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        if (_currentHandle == null || _currentSource == null) return;

        try {
          final position = _soloud.getPosition(_currentHandle!);
          _positionController.add(position);

          final length = _soloud.getLength(_currentSource!);
          if (position >= length && length > Duration.zero && !_completionFired) {
            _completionFired = true;
            _completionController.add(null);
          }
        } catch (_) {
          // Handle may have been invalidated
        }
      },
    );
  }

  @override
  Future<void> pause() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, true);
    }
  }

  @override
  Future<void> resume() async {
    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, false);
    }
  }

  @override
  Future<void> stop() async {
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
      _currentHandle = null;
    }
    _positionTimer?.cancel();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_currentHandle != null) {
      _soloud.seek(_currentHandle!, position);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_currentHandle != null) {
      _soloud.setVolume(_currentHandle!, volume.clamp(0.0, 1.0));
    }
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  List<double> getFFTData() {
    if (!_initialized || _audioData == null) return List.filled(256, 0.0);
    try {
      _audioData!.updateSamples();
      final Float32List raw = _audioData!.getAudioData();
      if (raw.isEmpty) return List.filled(256, 0.0);
      final fftLen = raw.length >= 256 ? 256 : raw.length;
      return List<double>.generate(fftLen, (i) => raw[i].toDouble());
    } catch (_) {
      return List.filled(256, 0.0);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_currentHandle != null) {
      _soloud.setRelativePlaySpeed(_currentHandle!, speed.clamp(0.5, 2.0));
    }
  }

  // ── Equalizer ──────────────────────────────────────────────────────

  bool _eqActive = false;
  final List<double> _eqBands = List.filled(8, 1.0);

  @override
  Future<void> setEqualizerActive(bool active) async {
    if (!_initialized) return;
    if (active && !_eqActive) {
      _soloud.filters.equalizerFilter.activate();
      // Apply current band values
      for (int i = 0; i < 8; i++) {
        _setEqBandInternal(i, _eqBands[i]);
      }
    } else if (!active && _eqActive) {
      _soloud.filters.equalizerFilter.deactivate();
    }
    _eqActive = active;
  }

  @override
  Future<void> setEqualizerBand(int band, double gain) async {
    if (band < 1 || band > 8) return;
    _eqBands[band - 1] = gain.clamp(0.0, 4.0);
    if (_eqActive && _initialized) {
      _setEqBandInternal(band - 1, _eqBands[band - 1]);
    }
  }

  void _setEqBandInternal(int index, double gain) {
    final eq = _soloud.filters.equalizerFilter;
    switch (index) {
      case 0: eq.band1.value = gain;
      case 1: eq.band2.value = gain;
      case 2: eq.band3.value = gain;
      case 3: eq.band4.value = gain;
      case 4: eq.band5.value = gain;
      case 5: eq.band6.value = gain;
      case 6: eq.band7.value = gain;
      case 7: eq.band8.value = gain;
    }
  }

  @override
  List<double> getEqualizerBands() => List.unmodifiable(_eqBands);
}
