import 'dart:async';

import 'package:audio_service/audio_service.dart' as as_lib;
import 'package:flutter/foundation.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';

/// Background audio handler that bridges audio_service (lock screen / notification
/// controls) with the flutter_soloud AudioRepository.
class NenAudioHandler extends as_lib.BaseAudioHandler with as_lib.SeekHandler {
  final AudioRepository _audioRepo;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completionSub;

  bool _playing = false;

  /// Callback fired when completion happens so PlaybackNotifier can call next().
  VoidCallback? onCompletion;

  NenAudioHandler(this._audioRepo);

  /// Initialize and wire up the audio engine's streams.
  Future<void> init() async {
    await _audioRepo.initialize();

    _positionSub = _audioRepo.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: pos,
      ));
    });

    _completionSub = _audioRepo.completionStream.listen((_) {
      onCompletion?.call();
    });
  }

  /// Start playing a song and update media session metadata.
  Future<void> playSong(Song song, {List<Song>? queue, int queueIndex = 0}) async {
    _playing = true;

    await _audioRepo.play(song);

    // Update media item for lock screen
    mediaItem.add(as_lib.MediaItem(
      id: song.filePath,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
    ));

    _broadcastState();
  }

  @override
  Future<void> play() async {
    _playing = true;
    await _audioRepo.resume();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    await _audioRepo.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    await _audioRepo.stop();
    _broadcastState();
    // Don't call super.stop() — keep service alive
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioRepo.seek(position);
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
    ));
  }

  @override
  Future<void> skipToNext() async {
    // Delegate to PlaybackNotifier via callback
    onCompletion?.call();
  }

  @override
  Future<void> skipToPrevious() async {
    // Re-seek to start if within 3s, otherwise handled by notifier
    await seek(Duration.zero);
  }

  void _broadcastState() {
    playbackState.add(as_lib.PlaybackState(
      controls: [
        as_lib.MediaControl.skipToPrevious,
        _playing ? as_lib.MediaControl.pause : as_lib.MediaControl.play,
        as_lib.MediaControl.skipToNext,
      ],
      systemActions: const {
        as_lib.MediaAction.seek,
        as_lib.MediaAction.seekForward,
        as_lib.MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: as_lib.AudioProcessingState.ready,
      playing: _playing,
    ));
  }

  /// Expose for FFT access.
  AudioRepository get audioRepo => _audioRepo;

  Future<void> teardown() async {
    await _positionSub?.cancel();
    await _completionSub?.cancel();
    await _audioRepo.dispose();
  }
}

/// Initialize the audio handler as a singleton.
Future<NenAudioHandler> initAudioHandler(AudioRepository audioRepo) async {
  final handler = await as_lib.AudioService.init(
    builder: () => NenAudioHandler(audioRepo),
    config: as_lib.AudioServiceConfig(
      androidNotificationChannelId: 'com.nen.audio',
      androidNotificationChannelName: 'Nen Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await handler.init();
  return handler;
}
