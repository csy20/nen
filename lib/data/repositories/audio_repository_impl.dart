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

    _startPositionTracking();
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) {
        if (_currentHandle == null || _currentSource == null) return;

        try {
          final position = _soloud.getPosition(_currentHandle!);
          _positionController.add(position);

          final length = _soloud.getLength(_currentSource!);
          if (position >= length && length > Duration.zero) {
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
      // Linear mode returns 256 FFT bins + 256 wave samples = 512 floats.
      // We only use the first 256 (FFT portion).
      final fftLen = raw.length >= 256 ? 256 : raw.length;
      return List<double>.generate(fftLen, (i) => raw[i].toDouble());
    } catch (_) {
      return List.filled(256, 0.0);
    }
  }
}
