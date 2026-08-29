import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;

import '../../domain/audio/audio_format.dart';
import '../../domain/audio/audio_playback_exception.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';

/// just_audio / ExoPlayer only. No SoLoud, Visualizer, or session Equalizer.
class AudioRepositoryImpl implements AudioRepository {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();
  final StreamController<bool> _playingController =
      StreamController<bool>.broadcast();
  final List<double> _fftBuffer = List<double>.filled(256, 0.0);
  final List<double> _eqBands = List<double>.filled(8, 1.0);

  ja.AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  bool _initialized = false;
  bool _disposed = false;
  bool _completionFired = false;
  int _playGeneration = 0;
  bool _wantPlaying = false;
  bool _isPlaying = false;
  Duration _lastPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  double _volume = 1.0;
  double _speed = 1.0;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isVisualizerLive => false;

  @override
  bool get isEqualizerLive => false;

  @override
  bool get supportsCrossfade => false;

  @override
  Song? get preloadedSong => null;

  @override
  Duration get currentDuration => _currentDuration;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _initialized = false;
    await _disposePlayer();
    await _positionController.close();
    await _completionController.close();
    await _playingController.close();
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
    _ensurePlayer();
    final player = _player!;
    if (player.playing) {
      try {
        await player.pause();
      } catch (e) {
        debugPrint('pause before source swap error: $e');
      }
    }
    _ensureCurrent(gen);

    _completionFired = false;
    _lastPosition = Duration.zero;
    _currentDuration = song.duration;
    _positionController.add(Duration.zero);

    Duration? duration;
    try {
      duration = await _setSource(player, song);
    } on ja.PlayerInterruptedException {
      throw const PlaybackSupersededException();
    } on PlaybackSupersededException {
      rethrow;
    } catch (e) {
      _ensureCurrent(gen);
      debugPrint('setAudioSource failed: $e');
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
    _ensureCurrent(gen);
    _currentDuration = AudioFormat.coalesceDuration(
      duration ?? Duration.zero,
      song.duration,
    );
    try {
      await player.setVolume(_volume);
      await player.setSpeed(_speed);
    } catch (e) {
      debugPrint('volume/speed error: $e');
    }
    _ensureCurrent(gen);
    if (!_wantPlaying) return;
    await player.play();
    _setPlaying(player.playing);
  }

  Future<Duration?> _setSource(ja.AudioPlayer player, Song song) async {
    Object? uriError;
    if (song.uri.isNotEmpty) {
      try {
        return await player.setAudioSource(
          ja.AudioSource.uri(Uri.parse(song.uri), tag: song.id),
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
        ja.AudioSource.file(song.filePath, tag: song.id),
        preload: false,
      );
    }
    if (uriError != null) throw uriError;
    throw AudioPlaybackException(
      'No playable path or URI for "${song.title}"',
      formatLabel: AudioFormat.displayName(song.fileExtension),
    );
  }

  void _ensurePlayer() {
    if (_player != null) return;
    final player = ja.AudioPlayer(
      androidAudioOffloadPreferences: const ja.AndroidAudioOffloadPreferences(
        audioOffloadMode: ja.AndroidAudioOffloadMode.disabled,
      ),
    );
    _player = player;
    _positionSub = player.positionStream.listen((pos) {
      if (_disposed) return;
      if (pos != _lastPosition) {
        _lastPosition = pos;
        _positionController.add(pos);
      }
    });
    _stateSub = player.playerStateStream.listen((state) {
      if (_disposed) return;
      _setPlaying(state.playing);
      if (state.processingState == ja.ProcessingState.completed &&
          !_completionFired) {
        _completionFired = true;
        _setPlaying(false);
        _completionController.add(null);
      }
    });
    _durationSub = player.durationStream.listen((duration) {
      if (duration == null || duration <= Duration.zero) return;
      final next = AudioFormat.coalesceDuration(duration, _currentDuration);
      if (next == _currentDuration) return;
      _currentDuration = next;
      _positionController.add(_lastPosition);
    });
  }

  @override
  Future<void> pause() async {
    _wantPlaying = false;
    final player = _player;
    if (player == null) {
      _setPlaying(false);
      return;
    }
    try {
      await player.pause();
      if (player.playing) {
        await player.pause();
      }
    } catch (e) {
      debugPrint('pause error: $e');
    }
    _setPlaying(player.playing);
  }

  @override
  Future<void> resume() async {
    _wantPlaying = true;
    final player = _player;
    if (player == null) {
      _setPlaying(false);
      return;
    }
    try {
      await player.play();
      if (!player.playing) {
        await player.play();
      }
    } catch (e) {
      debugPrint('resume error: $e');
    }
    _setPlaying(player.playing);
  }

  @override
  Future<void> stop() async {
    _playGeneration++;
    _wantPlaying = false;
    _lastPosition = Duration.zero;
    _completionFired = true;
    _setPlaying(false);
    final player = _player;
    if (player == null) return;
    try {
      await player.pause();
    } catch (e) {
      debugPrint('pause-on-stop error: $e');
    }
    unawaited(player.seek(Duration.zero));
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
    _lastPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _player?.setVolume(_volume);
    } catch (e) {
      debugPrint('volume error: $e');
    }
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  bool get isPlaying => _isPlaying;

  void _setPlaying(bool playing) {
    if (_isPlaying == playing) return;
    _isPlaying = playing;
    if (!_playingController.isClosed) {
      _playingController.add(playing);
    }
  }

  @override
  List<double> getFFTData() => _fftBuffer;

  @override
  Future<void> preload(Song song) async {}

  @override
  Future<bool> playPreloaded() async => false;

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    try {
      await _player?.setSpeed(_speed);
    } catch (e) {
      debugPrint('speed error: $e');
    }
  }

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {}

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {}

  @override
  Future<void> setEqualizerActive(bool active) async {}

  @override
  Future<void> setEqualizerBand(int band, double gain) async {
    if (band < 1 || band > 8) return;
    _eqBands[band - 1] = gain.clamp(0.0, 4.0);
  }

  @override
  Future<void> resetEqualizerBands() async {
    for (var i = 0; i < 8; i++) {
      _eqBands[i] = 1.0;
    }
  }

  @override
  List<double> getEqualizerBands() => List.unmodifiable(_eqBands);

  Future<void> _disposePlayer() async {
    await _positionSub?.cancel();
    await _stateSub?.cancel();
    await _durationSub?.cancel();
    _positionSub = null;
    _stateSub = null;
    _durationSub = null;
    try {
      await _player?.dispose();
    } catch (e) {
      debugPrint('player dispose error: $e');
    }
    _player = null;
  }
}
