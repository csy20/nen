import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../domain/audio/audio_format.dart';
import '../../domain/audio/audio_playback_exception.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';
import '../services/system_fft_capture.dart';

class _RetiringTrack {
  final SoundHandle handle;
  final AudioSource source;

  const _RetiringTrack({required this.handle, required this.source});
}

enum _Backend { none, soloud, system }

/// Implementation of [AudioRepository] using SoLoud plus a system decoder.
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

  ja.AudioPlayer? _systemPlayer;
  StreamSubscription<Duration>? _systemPositionSub;
  StreamSubscription<ja.PlayerState>? _systemStateSub;
  StreamSubscription<Duration?>? _systemDurationSub;
  StreamSubscription<int?>? _systemSessionSub;
  final SystemFftCapture _systemFft = SystemFftCapture();

  bool _initialized = false;
  bool _soloudReady = false;
  bool _disposed = false;
  bool _completionFired = false;
  int _playGeneration = 0;
  bool _wantPlaying = false;
  _Backend _activeBackend = _Backend.none;
  Duration _lastPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;
  bool _crossfadeEnabled = false;
  Duration _crossfadeDuration = const Duration(seconds: 3);

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isVisualizerLive =>
      !_disposed &&
      _wantPlaying &&
      (_activeBackend == _Backend.soloud && _soloudReady ||
          _activeBackend == _Backend.system);

  @override
  Duration get currentDuration => _currentDuration;

  @override
  Future<void> initialize() async {
    // just_audio/ExoPlayer does not need SoLoud. Starting SoLoud here
    // grabs a low-latency AAudio stream and can silence library playback.
    _initialized = true;
  }

  Future<void> _ensureSoLoud() async {
    if (_soloudReady) return;
    var inited = false;
    try {
      await _soloud.init(
        sampleRate: 48000,
        bufferSize: 2048,
        channels: Channels.stereo,
      );
      inited = true;
    } catch (e) {
      debugPrint('SoLoud 48 kHz init failed, falling back: $e');
    }
    if (!inited) {
      await _soloud.init();
    }
    _soloud.setVisualizationEnabled(true);
    _audioData = AudioData(GetSamplesKind.linear);
    _soloudReady = true;
    if (_eqActive) {
      try {
        _soloud.filters.equalizerFilter.activate();
        for (var i = 0; i < 8; i++) {
          _setEqBandInternal(i, _eqBands[i]);
        }
        _setLimiterActive(true);
      } catch (e) {
        debugPrint('re-apply EQ after SoLoud init failed: $e');
      }
    }
  }

  Future<void> _releaseSoLoudEngine() async {
    if (!_soloudReady) return;
    await _stopCurrentTrack();
    await _disposePreloadedSource();
    _audioData?.dispose();
    _audioData = null;
    try {
      _soloud.deinit();
    } catch (e) {
      debugPrint('SoLoud deinit error: $e');
    }
    _soloudReady = false;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _initialized = false;
    _positionTimer?.cancel();
    await _stopAllTracks();
    await _disposeSystemPlayer();
    await _releaseSoLoudEngine();
    await _positionController.close();
    await _completionController.close();
  }

  @override
  Future<void> play(Song song) async {
    final gen = ++_playGeneration;
    _wantPlaying = true;
    if (!_initialized) await initialize();
    _ensureCurrent(gen);
    await _playSong(song, gen);
  }

  bool _stale(int gen) => _disposed || gen != _playGeneration;

  void _ensureCurrent(int gen) {
    if (_stale(gen)) throw const PlaybackSupersededException();
  }

  Future<void> _playSong(Song song, int gen) async {
    final preferred = AudioFormat.preferredBackend(
      extension: song.fileExtension,
      filePath: song.filePath,
      fileIsReadable: song.filePath.isNotEmpty,
      fileSize: song.fileSize,
      duration: song.duration,
    );
    final first = preferred == AudioBackend.soloud
        ? _Backend.soloud
        : _Backend.system;
    final second = AudioFormat.fallbackBackend(preferred) == AudioBackend.soloud
        ? _Backend.soloud
        : _Backend.system;

    Object? firstError;
    try {
      await _playWithBackend(song, first, gen);
      _ensureCurrent(gen);
      return;
    } on ja.PlayerInterruptedException {
      throw const PlaybackSupersededException();
    } on PlaybackSupersededException {
      rethrow;
    } catch (e) {
      _ensureCurrent(gen);
      firstError = e;
      debugPrint('primary backend $first failed: $e');
    }

    _ensureCurrent(gen);
    if (second == _Backend.soloud &&
        !AudioFormat.canSafelyDecodeToMemory(
          fileSizeBytes: song.fileSize,
          duration: song.duration,
        )) {
      throw AudioPlaybackException.unsupported(
        title: song.title,
        formatLabel: AudioFormat.displayName(
          AudioFormat.normalizeExtension(
            song.fileExtension,
            fallbackPath: song.filePath,
          ),
        ),
      );
    }

    try {
      await _playWithBackend(song, second, gen);
      _ensureCurrent(gen);
    } on ja.PlayerInterruptedException {
      throw const PlaybackSupersededException();
    } on PlaybackSupersededException {
      rethrow;
    } catch (e) {
      _ensureCurrent(gen);
      debugPrint('fallback backend $second failed: $e');
      debugPrint('primary backend error was: $firstError');
      throw AudioPlaybackException.unsupported(
        title: song.title,
        formatLabel: AudioFormat.displayName(
          AudioFormat.normalizeExtension(
            song.fileExtension,
            fallbackPath: song.filePath,
          ),
        ),
      );
    }
  }

  Future<void> _playWithBackend(Song song, _Backend backend, int gen) async {
    if (backend == _Backend.soloud) {
      await _playWithSoLoud(song, gen);
    } else {
      await _playWithSystem(song, gen);
    }
  }

  @override
  Future<void> preload(Song song) async {
    if (!_initialized) await initialize();
    if (!AudioFormat.canSafelyDecodeToMemory(
      fileSizeBytes: song.fileSize,
      duration: song.duration,
    )) {
      return;
    }
    final ext = AudioFormat.normalizeExtension(
      song.fileExtension,
      fallbackPath: song.filePath,
    );
    final readable = _isReadableFile(song.filePath);
    final preferred = AudioFormat.preferredBackend(
      extension: ext,
      filePath: song.filePath,
      fileIsReadable: readable,
      fileSize: song.fileSize,
      duration: song.duration,
    );
    if (preferred != AudioBackend.soloud || !readable) {
      return;
    }
    if (_preloadedFilePath == song.filePath && _preloadedSource != null) {
      return;
    }

    await _disposePreloadedSource();
    try {
      await _ensureSoLoud();
      _preloadedSource = await _soloud.loadFile(
        song.filePath,
        mode: _loadModeFor(song),
      );
      _preloadedFilePath = song.filePath;
    } catch (e) {
      debugPrint('preload failed: $e');
      _preloadedSource = null;
      _preloadedFilePath = null;
    }
  }

  @override
  Future<void> playPreloaded() async {
    if (_preloadedSource == null) return;
    final gen = ++_playGeneration;
    await _stopSystemPlayback();
    if (_stale(gen)) return;
    final preloadedSource = _preloadedSource!;
    _preloadedSource = null;
    _preloadedFilePath = null;
    await _playSoLoudSource(preloadedSource);
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    if (_activeBackend == _Backend.system) {
      try {
        await _systemPlayer?.pause();
      } catch (e) {
        debugPrint('system pause error: $e');
      }
    }
    if (_soloudReady) {
      for (final handle in _allActiveHandles()) {
        try {
          _soloud.setPause(handle, true);
        } catch (e) {
          debugPrint('pause error: $e');
        }
      }
    }
  }

  @override
  Future<void> resume() async {
    _wantPlaying = true;
    if (_activeBackend == _Backend.system) {
      try {
        await _systemPlayer?.play();
      } catch (e) {
        debugPrint('system resume error: $e');
      }
    }
    if (_soloudReady) {
      for (final handle in _allActiveHandles()) {
        try {
          _soloud.setPause(handle, false);
        } catch (e) {
          debugPrint('resume error: $e');
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    _playGeneration++;
    _wantPlaying = false;
    unawaited(_systemFft.detach());
    _positionTimer?.cancel();
    _lastPosition = Duration.zero;
    _completionFired = true;
    final player = _systemPlayer;
    if (player != null && _activeBackend == _Backend.system) {
      try {
        await player.pause();
      } catch (e) {
        debugPrint('system pause-on-stop error: $e');
      }
      unawaited(player.seek(Duration.zero));
      _activeBackend = _Backend.none;
      return;
    }
    if (_soloudReady) {
      unawaited(_stopAllTracks());
    } else {
      _activeBackend = _Backend.none;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_activeBackend == _Backend.system) {
      await _systemPlayer?.seek(position);
      _lastPosition = position;
      _positionController.add(position);
      return;
    }
    final handle = _currentHandle;
    if (handle == null || !_soloudReady) return;
    _soloud.seek(handle, position);
    _lastPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_systemPlayer != null) {
      try {
        await _systemPlayer!.setVolume(_volume);
      } catch (e) {
        debugPrint('system volume error: $e');
      }
    }
    if (_soloudReady) {
      for (final handle in _allActiveHandles()) {
        try {
          _soloud.setVolume(handle, _volume);
        } catch (e) {
          debugPrint('volume error: $e');
        }
      }
    }
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  List<double> getFFTData() {
    if (_disposed) {
      _fillFftBuffer(0.0);
      return _fftBuffer;
    }
    if (_activeBackend == _Backend.system && _wantPlaying) {
      if (_systemFft.copyInto(_fftBuffer)) return _fftBuffer;
      _fillPlayingFallback();
      return _fftBuffer;
    }
    if (!_soloudReady ||
        _audioData == null ||
        _activeBackend != _Backend.soloud) {
      _fillFftBuffer(0.0);
      return _fftBuffer;
    }

    try {
      _audioData!.updateSamples();
      final raw = _audioData!.getAudioData();
      // Never copy an unexpectedly huge native buffer into Dart.
      if (raw.length > 2048) {
        _fillFftBuffer(0.0);
        return _fftBuffer;
      }
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
    if (_systemPlayer != null) {
      try {
        await _systemPlayer!.setSpeed(_speed);
      } catch (e) {
        debugPrint('system speed error: $e');
      }
    }
    if (_soloudReady) {
      for (final handle in _allActiveHandles()) {
        try {
          _soloud.setRelativePlaySpeed(handle, _speed);
        } catch (e) {
          debugPrint('speed error: $e');
        }
      }
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
    _eqActive = active;
    // Don't start SoLoud just to toggle EQ while ExoPlayer owns the device.
    if (!_soloudReady) return;
    try {
      if (active) {
        _soloud.filters.equalizerFilter.activate();
        for (int i = 0; i < 8; i++) {
          _setEqBandInternal(i, _eqBands[i]);
        }
        _setLimiterActive(true);
      } else {
        _soloud.filters.equalizerFilter.deactivate();
        _setLimiterActive(false);
      }
    } catch (e) {
      debugPrint('setEqualizerActive error: $e');
    }
  }

  @override
  Future<void> setEqualizerBand(int band, double gain) async {
    if (band < 1 || band > 8) return;
    _eqBands[band - 1] = gain.clamp(0.0, 4.0);
    if (_eqActive && _soloudReady) {
      try {
        _setEqBandInternal(band - 1, _eqBands[band - 1]);
      } catch (e) {
        debugPrint('setEqualizerBand error: $e');
      }
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

  void _setLimiterActive(bool active) {
    // SoLoud's limiter is marked experimental but is the only clip guard
    // available when EQ boosts a track above unity.
    // ignore: experimental_member_use
    final limiter = _soloud.filters.limiterFilter;
    try {
      if (active && !limiter.isActive) {
        limiter.activate();
        limiter.threshold.value = -3.0;
        limiter.outputCeiling.value = -1.0;
      } else if (!active && limiter.isActive) {
        limiter.deactivate();
      }
    } catch (e) {
      debugPrint('limiter error: $e');
    }
  }

  @override
  Future<void> resetEqualizerBands() async {
    for (int i = 0; i < 8; i++) {
      _eqBands[i] = 1.0;
    }
    if (_eqActive && _soloudReady) {
      try {
        for (int i = 0; i < 8; i++) {
          _setEqBandInternal(i, 1.0);
        }
      } catch (e) {
        debugPrint('resetEqualizerBands error: $e');
      }
    }
  }

  @override
  List<double> getEqualizerBands() => List.unmodifiable(_eqBands);

  Future<void> _playWithSoLoud(Song song, int gen) async {
    if (!AudioFormat.canSafelyDecodeToMemory(
      fileSizeBytes: song.fileSize,
      duration: song.duration,
    )) {
      throw AudioPlaybackException(
        'SoLoud skipped for streamed library track',
        formatLabel: AudioFormat.displayName(song.fileExtension),
      );
    }
    if (!_isReadableFile(song.filePath)) {
      throw AudioPlaybackException(
        'No readable file for "${song.title}"',
        formatLabel: AudioFormat.displayName(song.fileExtension),
      );
    }
    await _stopSystemPlayback();
    _ensureCurrent(gen);
    await _ensureSoLoud();
    _ensureCurrent(gen);
    final nextSource = await _takeOrLoadSource(song);
    _ensureCurrent(gen);
    await _playSoLoudSource(nextSource, metadataDuration: song.duration);
  }

  Future<void> _playSoLoudSource(
    AudioSource nextSource, {
    Duration metadataDuration = Duration.zero,
  }) async {
    final canCrossfade = _shouldCrossfadeCurrentTrack();
    final previousHandle = _currentHandle;
    final previousSource = _currentSource;

    if (canCrossfade) {
      final fadeDuration = _crossfadeDuration;
      final nextHandle = await _soloud.play(nextSource, volume: 0.0);
      _currentHandle = nextHandle;
      _currentSource = nextSource;
      _activeBackend = _Backend.soloud;
      _completionFired = false;
      _lastPosition = Duration.zero;
      _currentDuration = AudioFormat.coalesceDuration(
        _safeSoLoudLength(nextSource),
        metadataDuration,
      );
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
    _activeBackend = _Backend.soloud;
    _completionFired = false;
    _lastPosition = Duration.zero;
    _currentDuration = AudioFormat.coalesceDuration(
      _safeSoLoudLength(nextSource),
      metadataDuration,
    );
    _applyCurrentHandleSpeed();
    _startPositionTracking();
  }

  Future<void> _playWithSystem(Song song, int gen) async {
    _ensureSystemPlayer();
    final player = _systemPlayer!;
    // just_audio forces preload if already playing. Pause first so
    // setAudioSource(preload: false) can return immediately.
    if (player.playing) {
      try {
        await player.pause();
      } catch (e) {
        debugPrint('pause before source swap error: $e');
      }
    }
    _ensureCurrent(gen);
    if (_soloudReady) {
      await _releaseSoLoudEngine();
      _ensureCurrent(gen);
    }

    _activeBackend = _Backend.system;
    _completionFired = false;
    _lastPosition = Duration.zero;
    _currentDuration = song.duration;
    _positionController.add(Duration.zero);

    final duration = await _setSystemSource(player, song);
    _ensureCurrent(gen);
    _currentDuration = AudioFormat.coalesceDuration(
      duration ?? Duration.zero,
      song.duration,
    );
    try {
      await player.setVolume(_volume);
      await player.setSpeed(_speed);
    } catch (e) {
      debugPrint('system volume/speed error: $e');
    }
    _ensureCurrent(gen);
    if (!_wantPlaying) return;
    await player.play();
    unawaited(_systemFft.attach(player.androidAudioSessionId));
  }

  Future<Duration?> _setSystemSource(ja.AudioPlayer player, Song song) async {
    Object? uriError;
    if (song.uri.isNotEmpty) {
      try {
        return await player.setAudioSource(
          ja.AudioSource.uri(Uri.parse(song.uri)),
          preload: false,
        );
      } on ja.PlayerInterruptedException {
        rethrow;
      } catch (e) {
        uriError = e;
        debugPrint('setAudioSource uri failed: $e');
      }
    }
    if (song.filePath.isNotEmpty) {
      return player.setAudioSource(
        ja.AudioSource.file(song.filePath),
        preload: false,
      );
    }
    if (uriError != null) throw uriError;
    throw AudioPlaybackException(
      'No playable path or URI for "${song.title}"',
      formatLabel: AudioFormat.displayName(song.fileExtension),
    );
  }

  void _ensureSystemPlayer() {
    if (_systemPlayer != null) return;
    final player = ja.AudioPlayer();
    _systemPlayer = player;
    _systemPositionSub = player.positionStream.listen((pos) {
      if (_activeBackend != _Backend.system || _disposed) return;
      if (pos != _lastPosition) {
        _lastPosition = pos;
        _positionController.add(pos);
      }
    });
    _systemStateSub = player.playerStateStream.listen((state) {
      if (_activeBackend != _Backend.system || _disposed) return;
      if (state.processingState == ja.ProcessingState.completed &&
          !_completionFired) {
        _completionFired = true;
        _completionController.add(null);
      }
    });
    _systemDurationSub = player.durationStream.listen((duration) {
      if (duration == null || duration <= Duration.zero) return;
      final next = AudioFormat.coalesceDuration(duration, _currentDuration);
      if (next == _currentDuration) return;
      _currentDuration = next;
      _positionController.add(_lastPosition);
    });
    _systemSessionSub = player.androidAudioSessionIdStream.listen((id) {
      if (_disposed || _activeBackend != _Backend.system || !_wantPlaying) {
        return;
      }
      unawaited(_systemFft.attach(id));
    });
  }

  bool _shouldCrossfadeCurrentTrack() {
    if (_activeBackend != _Backend.soloud ||
        !_crossfadeEnabled ||
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

    return _soloud.loadFile(song.filePath, mode: _loadModeFor(song));
  }

  LoadMode _loadModeFor(Song song) {
    // LoadMode.memory runs on a Dart isolate and decompresses the whole
    // file to PCM. That is what aborted the process with malloc(~968 MB).
    if (AudioFormat.canSafelyDecodeToMemory(
      fileSizeBytes: song.fileSize,
      duration: song.duration,
    )) {
      return LoadMode.memory;
    }
    return LoadMode.disk;
  }

  void _startPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_activeBackend != _Backend.soloud) return;
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
        if (length > Duration.zero) {
          _currentDuration = AudioFormat.coalesceDuration(
            length,
            _currentDuration,
          );
        }
        final end = _currentDuration > Duration.zero
            ? _currentDuration
            : length;
        if (position >= end && end > Duration.zero && !_completionFired) {
          _completionFired = true;
          _completionController.add(null);
        }
      } catch (e) {
        debugPrint('position tracking error: $e');
      }
    });
  }

  Duration _safeSoLoudLength(AudioSource source) {
    try {
      final length = _soloud.getLength(source);
      return length > Duration.zero ? length : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  void _applyCurrentHandleSpeed() {
    final currentHandle = _currentHandle;
    if (currentHandle == null || !_soloudReady) return;
    _soloud.setRelativePlaySpeed(currentHandle, _speed);
  }

  Future<void> _cleanupRetiringTrack(
    _RetiringTrack track,
    Duration fadeDuration,
  ) async {
    await Future.delayed(fadeDuration);
    if (_disposed || !_soloudReady || !_retiringTracks.remove(track)) {
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
    await _stopSystemPlayback();

    final retiringTracks = List<_RetiringTrack>.from(_retiringTracks);
    _retiringTracks.clear();
    if (_soloudReady) {
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
    if (_activeBackend != _Backend.none) {
      _activeBackend = _Backend.none;
    }
  }

  Future<void> _stopCurrentTrack() async {
    final currentHandle = _currentHandle;
    final currentSource = _currentSource;
    _currentHandle = null;
    _currentSource = null;
    if (_activeBackend == _Backend.soloud) {
      _activeBackend = _Backend.none;
    }

    if (!_soloudReady) return;
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

  Future<void> _stopSystemPlayback() async {
    final player = _systemPlayer;
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      debugPrint('system stop error: $e');
    }
    if (_activeBackend == _Backend.system) {
      _activeBackend = _Backend.none;
    }
  }

  Future<void> _disposeSystemPlayer() async {
    await _systemFft.detach();
    await _systemPositionSub?.cancel();
    await _systemStateSub?.cancel();
    await _systemDurationSub?.cancel();
    await _systemSessionSub?.cancel();
    _systemPositionSub = null;
    _systemStateSub = null;
    _systemDurationSub = null;
    _systemSessionSub = null;
    try {
      await _systemPlayer?.dispose();
    } catch (e) {
      debugPrint('system dispose error: $e');
    }
    _systemPlayer = null;
  }

  Future<void> _disposePreloadedSource() async {
    final source = _preloadedSource;
    _preloadedSource = null;
    _preloadedFilePath = null;
    if (source == null || !_soloudReady) return;
    try {
      await _soloud.disposeSource(source);
    } catch (e) {
      debugPrint('disposePreloadedSource error: $e');
    }
  }

  bool _isReadableFile(String path) {
    if (path.isEmpty) return false;
    try {
      final file = File(path);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  void _fillFftBuffer(double value) {
    for (var i = 0; i < _fftBuffer.length; i++) {
      _fftBuffer[i] = value;
    }
  }

  void _fillPlayingFallback() {
    final t = DateTime.now().millisecondsSinceEpoch / 240.0;
    for (var i = 0; i < _fftBuffer.length; i++) {
      final band = i / _fftBuffer.length;
      final wave =
          0.5 +
          0.5 * math.sin(t * (1.05 + band * 1.7) + i * 0.13) *
              math.sin(t * 0.37 + band * 4.0);
      _fftBuffer[i] = (0.18 + 0.62 * wave.abs()) * (1.0 - band * 0.35);
    }
  }
}
