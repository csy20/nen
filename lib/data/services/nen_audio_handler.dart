import 'dart:async';

import 'package:audio_service/audio_service.dart' as as_lib;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import '../../domain/audio/audio_format.dart';
import '../../domain/audio/audio_playback_exception.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';

class NenAudioHandler extends as_lib.BaseAudioHandler with as_lib.SeekHandler {
  final AudioRepository _audioRepo;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;

  bool _playing = false;
  bool _pausedByInterrupt = false;
  final List<void> _pendingCompletions = [];
  static const int _maxPendingCompletions = 16;

  Future<void> Function()? onCompletion;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  NenAudioHandler(this._audioRepo);

  Stream<as_lib.AudioServiceRepeatMode> get repeatModeStream =>
      playbackState.map((state) => state.repeatMode).distinct();

  Future<void> init() async {
    _completionSub = _audioRepo.completionStream.listen((_) {
      final callback = onCompletion;
      if (callback != null) {
        unawaited(callback());
      } else if (_pendingCompletions.length < _maxPendingCompletions) {
        _pendingCompletions.add(null);
      }
    });

    _positionSub = _audioRepo.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });

    await _audioRepo.initialize();
    await _configureAudioSession();

    while (_pendingCompletions.isNotEmpty) {
      final callback = onCompletion;
      if (callback != null) {
        _pendingCompletions.clear();
        unawaited(callback());
      } else {
        break;
      }
    }
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int queueIndex = 0,
  }) async {
    try {
      await _audioRepo.play(song);
    } on PlaybackSupersededException {
      return;
    }
    _playing = true;

    final duration = AudioFormat.coalesceDuration(
      _audioRepo.currentDuration,
      song.duration,
    );

    mediaItem.add(
      as_lib.MediaItem(
        id: song.filePath.isNotEmpty ? song.filePath : song.uri,
        title: song.title,
        artist: song.artist,
        album: song.album,
        duration: duration,
      ),
    );

    _broadcastState(position: Duration.zero, queueIndex: queueIndex);
  }

  Duration get currentDuration => _audioRepo.currentDuration;

  @override
  Future<void> play() async {
    await _audioRepo.resume();
    _playing = true;
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _audioRepo.pause();
    _playing = false;
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _audioRepo.stop();
    _playing = false;
    _broadcastState(position: Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioRepo.seek(position);
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> setRepeatMode(as_lib.AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> skipToNext() async {
    final callback = onSkipToNext;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onSkipToPrevious;
    if (callback != null) {
      await callback();
      return;
    }
    await seek(Duration.zero);
  }

  Future<void> setVolume(double volume) => _audioRepo.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) async {
    await _audioRepo.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  Future<void> setCrossfadeEnabled(bool enabled) =>
      _audioRepo.setCrossfadeEnabled(enabled);

  Future<void> setCrossfadeDuration(Duration duration) =>
      _audioRepo.setCrossfadeDuration(duration);

  void _broadcastState({Duration? position, int? queueIndex}) {
    final currentState = playbackState.value;
    playbackState.add(
      currentState.copyWith(
        controls: [
          as_lib.MediaControl.skipToPrevious,
          _playing ? as_lib.MediaControl.pause : as_lib.MediaControl.play,
          as_lib.MediaControl.skipToNext,
        ],
        systemActions: const {
          as_lib.MediaAction.seek,
          as_lib.MediaAction.seekForward,
          as_lib.MediaAction.seekBackward,
          as_lib.MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: as_lib.AudioProcessingState.ready,
        playing: _playing,
        updatePosition: position ?? currentState.position,
        queueIndex: queueIndex ?? currentState.queueIndex,
      ),
    );
  }

  AudioRepository get audioRepo => _audioRepo;

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen((event) {
        unawaited(_handleInterruption(event));
      });
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        unawaited(pause());
      });
    } catch (e) {
      debugPrint('audio session configure error: $e');
    }
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        return;
      }
      if (_playing) {
        _pausedByInterrupt = true;
        await pause();
      }
      return;
    }

    if (_pausedByInterrupt && event.type == AudioInterruptionType.pause) {
      _pausedByInterrupt = false;
      await play();
    } else {
      _pausedByInterrupt = false;
    }
  }

  Future<void> teardown() async {
    await _positionSub?.cancel();
    await _completionSub?.cancel();
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await _audioRepo.dispose();
  }
}

Future<NenAudioHandler> initAudioHandler(AudioRepository audioRepo) async {
  final handler = await as_lib.AudioService.init(
    builder: () => NenAudioHandler(audioRepo),
    config: as_lib.AudioServiceConfig(
      androidNotificationChannelId: 'dev.csy20.nen.audio',
      androidNotificationChannelName: 'Nen Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await handler.init();
  return handler;
}
