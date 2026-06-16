import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';

class _RetiringTrack {
  final SoundHandle handle;
  final AudioSource source;

  const _RetiringTrack({required this.handle, required this.source});
}

/// Implementation of [AudioRepository] using flutter_soloud (C++ engine).
class AudioRepositoryImpl implements AudioRepository {
  final SoLoud _soloud = SoLoud.instance;
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  final List<double> _fftBuffer = List<double>.filled(256, 0.0);
  final List<_RetiringTrack> _retiringTracks = <_RetiringTrack>[];

  SoundHandle? _currentHandle;
  AudioSource? _currentSource;
  AudioData? _audioData;
  AudioSource? _preloadedSource;
  String? _preloadedFilePath;
  Timer? _positionTimer;

  bool _initialized = false;
  bool _disposed = false;
  bool _completionFired = false;
  bool _transitionInProgress = false;
  Duration _lastPosition = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _crossfadeEnabled = false;
  Duration _crossfadeDuration = const Duration(seconds: 3);

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _soloud.init();
    _soloud.setVisualizationEnabled(true);
    _audioData = AudioData(GetSamplesKind.linear);
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _initialized = false;
    _positionTimer?.cancel();
    await _stopAllTracks();
    await _disposePreloadedSource();
    _audioData?.dispose();
    _audioData = null;
    await _positionController.close();
    await _completionController.close();
  }

  @override
  Future<void> play(Song song) async {
    if (_transitionInProgress) return;
    _transitionInProgress = true;
    try {
      if (!_initialized) await initialize();
      final nextSource = await _takeOrLoadSource(song);
      await _playSource(nextSource);
    } finally {
      _transitionInProgress = false;
    }
  }

  @override
  Future<void> preload(Song song) async {
    if (!_initialized) await initialize();
    if (_preloadedFilePath == song.filePath && _preloadedSource != null) {
      return;
    }

    await _disposePreloadedSource();
    _preloadedSource = await _soloud.loadFile(
      song.filePath,
      mode: LoadMode.disk,
    );
    _preloadedFilePath = song.filePath;
  }

  @override
  Future<void> playPreloaded() async {
    if (_preloadedSource == null) return;
    if (_transitionInProgress) return;
    _transitionInProgress = true;
    try {
      final preloadedSource = _preloadedSource!;
      _preloadedSource = null;
      _preloadedFilePath = null;
      await _playSource(preloadedSource);
    } finally {
      _transitionInProgress = false;
    }
  }

  @override
  Future<void> pause() async {
    for (final handle in _allActiveHandles()) {
      try {
        _soloud.setPause(handle, true);
      } catch (e) {
        debugPrint('pause error: $e');
      }
    }
  }

  @override
  Future<void> resume() async {
    for (final handle in _allActiveHandles()) {
      try {
        _soloud.setPause(handle, false);
      } catch (e) {
        debugPrint('resume error: $e');
      }
    }
  }

  @override
  Future<void> stop() async {
    _positionTimer?.cancel();
    _lastPosition = Duration.zero;
    _completionFired = true;
    await _stopAllTracks();
  }

  @override
  Future<void> seek(Duration position) async {
    final handle = _currentHandle;
    if (handle == null) return;
    _soloud.seek(handle, position);
    _lastPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_currentHandle != null) {
      _soloud.setVolume(_currentHandle!, _volume);
    }
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  List<double> getFFTData() {
    if (_disposed || !_initialized || _audioData == null) {
      _fillFftBuffer(0.0);
      return _fftBuffer;
    }

    try {
      _audioData!.updateSamples();
      final raw = _audioData!.getAudioData();
      final fftLength = raw.length >= _fftBuffer.length
          ? _fftBuffer.length
          : raw.length;
      for (var i = 0; i < fftLength; i++) {
        _fftBuffer[i] = raw[i].toDouble();
      }
      for (var i = fftLength; i < _fftBuffer.length; i++) {
        _fftBuffer[i] = 0.0;
      }
    } catch (e) {
      debugPrint('FFT data error: $e');
      _fillFftBuffer(0.0);
    }

    return _fftBuffer;
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    if (_currentHandle != null) {
      _soloud.setRelativePlaySpeed(_currentHandle!, _speed);
    }
  }

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {
    _crossfadeEnabled = enabled;
  }

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {
    _crossfadeDuration = duration;
  }

  // ── Equalizer ──────────────────────────────────────────────────────

  bool _eqActive = false;
  final List<double> _eqBands = List.filled(8, 1.0);

  @override
  Future<void> setEqualizerActive(bool active) async {
    if (!_initialized) return;
    if (active && !_eqActive) {
      _soloud.filters.equalizerFilter.activate();
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
      case 0:
        eq.band1.value = gain;
      case 1:
        eq.band2.value = gain;
      case 2:
        eq.band3.value = gain;
      case 3:
        eq.band4.value = gain;
      case 4:
        eq.band5.value = gain;
      case 5:
        eq.band6.value = gain;
      case 6:
        eq.band7.value = gain;
      case 7:
        eq.band8.value = gain;
    }
  }

  @override
  Future<void> resetEqualizerBands() async {
    for (int i = 0; i < 8; i++) {
      _eqBands[i] = 1.0;
    }
    if (_eqActive && _initialized) {
      for (int i = 0; i < 8; i++) {
        _setEqBandInternal(i, 1.0);
      }
    }
  }

  @override
  List<double> getEqualizerBands() => List.unmodifiable(_eqBands);

  Future<void> _playSource(AudioSource nextSource) async {
    final canCrossfade = _shouldCrossfadeCurrentTrack();
    final previousHandle = _currentHandle;
    final previousSource = _currentSource;

    if (canCrossfade) {
      final fadeDuration = _crossfadeDuration;
      final nextHandle = await _soloud.play(nextSource, volume: 0.0);
      _currentHandle = nextHandle;
      _currentSource = nextSource;
      _completionFired = false;
      _lastPosition = Duration.zero;
      _applyCurrentHandleSpeed();
      _startPositionTracking();
      _soloud.fadeVolume(nextHandle, _volume, fadeDuration);

      if (previousHandle != null && previousSource != null) {
        final retiringTrack = _RetiringTrack(
          handle: previousHandle,
          source: previousSource,
        );
        _retiringTracks.add(retiringTrack);
        try {
          _soloud.fadeVolume(retiringTrack.handle, 0.0, fadeDuration);
        } catch (e) {
          debugPrint('fadeVolume error: $e');
        }
        unawaited(_cleanupRetiringTrack(retiringTrack, fadeDuration));
      }
      return;
    }

    await _stopCurrentTrack();
    _currentSource = nextSource;
    _currentHandle = await _soloud.play(nextSource, volume: _volume);
    _completionFired = false;
    _lastPosition = Duration.zero;
    _applyCurrentHandleSpeed();
    _startPositionTracking();
  }

  bool _shouldCrossfadeCurrentTrack() {
    if (!_crossfadeEnabled ||
        _crossfadeDuration <= Duration.zero ||
        _currentHandle == null ||
        _currentSource == null) {
      return false;
    }

    try {
      return !_soloud.getPause(_currentHandle!);
    } catch (_) {
      return false;
    }
  }

  Future<AudioSource> _takeOrLoadSource(Song song) async {
    if (_preloadedSource != null && _preloadedFilePath == song.filePath) {
      final source = _preloadedSource!;
      _preloadedSource = null;
      _preloadedFilePath = null;
      return source;
    }

    return _soloud.loadFile(song.filePath, mode: LoadMode.disk);
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final currentHandle = _currentHandle;
      final currentSource = _currentSource;
      if (currentHandle == null || currentSource == null) {
        return;
      }

      try {
        if (_soloud.getPause(currentHandle)) {
          return;
        }

        final position = _soloud.getPosition(currentHandle);
        if (position != _lastPosition) {
          _lastPosition = position;
          _positionController.add(position);
        }

        final length = _soloud.getLength(currentSource);
        if (position >= length && length > Duration.zero && !_completionFired) {
          _completionFired = true;
          _completionController.add(null);
        }
      } catch (e) {
        debugPrint('position tracking error: $e');
      }
    });
  }

  void _applyCurrentHandleSpeed() {
    final currentHandle = _currentHandle;
    if (currentHandle == null) return;
    _soloud.setRelativePlaySpeed(currentHandle, _speed);
  }

  Future<void> _cleanupRetiringTrack(
    _RetiringTrack track,
    Duration fadeDuration,
  ) async {
    await Future.delayed(fadeDuration);
    if (_disposed || !_retiringTracks.remove(track)) {
      return;
    }

    try {
      await _soloud.stop(track.handle);
    } catch (e) {
      debugPrint('cleanup stop error: $e');
    }
    try {
      await _soloud.disposeSource(track.source);
    } catch (e) {
      debugPrint('cleanup dispose error: $e');
    }
  }

  Iterable<SoundHandle> _allActiveHandles() sync* {
    if (_currentHandle != null) {
      yield _currentHandle!;
    }
    for (final track in _retiringTracks) {
      yield track.handle;
    }
  }

  Future<void> _stopAllTracks() async {
    await _stopCurrentTrack();

    final retiringTracks = List<_RetiringTrack>.from(_retiringTracks);
    _retiringTracks.clear();
    for (final track in retiringTracks) {
      try {
        await _soloud.stop(track.handle);
      } catch (e) {
        debugPrint('stopAll retiring track stop error: $e');
      }
      try {
        await _soloud.disposeSource(track.source);
      } catch (e) {
        debugPrint('stopAll retiring track dispose error: $e');
      }
    }
  }

  Future<void> _stopCurrentTrack() async {
    final currentHandle = _currentHandle;
    final currentSource = _currentSource;
    _currentHandle = null;
    _currentSource = null;

    if (currentHandle != null) {
      try {
        await _soloud.stop(currentHandle);
      } catch (e) {
        debugPrint('stopCurrent stop error: $e');
      }
    }
    if (currentSource != null) {
      try {
        await _soloud.disposeSource(currentSource);
      } catch (e) {
        debugPrint('stopCurrent dispose error: $e');
      }
    }
  }

  Future<void> _disposePreloadedSource() async {
    if (_preloadedSource == null) return;
    try {
      await _soloud.disposeSource(_preloadedSource!);
    } catch (e) {
      debugPrint('disposePreloadedSource error: $e');
    }
    _preloadedSource = null;
    _preloadedFilePath = null;
  }

  void _fillFftBuffer(double value) {
    for (var i = 0; i < _fftBuffer.length; i++) {
      _fftBuffer[i] = value;
    }
  }
}
