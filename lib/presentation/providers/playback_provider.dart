import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/audio/audio_format.dart';
import '../../domain/audio/audio_playback_exception.dart';
import '../../domain/entities/entities.dart';
import '../../data/services/nen_audio_handler.dart';
import 'di_providers.dart';
import 'settings_provider.dart';

NenRepeatMode _toNenRepeatMode(audio_svc.AudioServiceRepeatMode repeatMode) {
  switch (repeatMode) {
    case audio_svc.AudioServiceRepeatMode.none:
      return NenRepeatMode.off;
    case audio_svc.AudioServiceRepeatMode.one:
      return NenRepeatMode.one;
    case audio_svc.AudioServiceRepeatMode.all:
    case audio_svc.AudioServiceRepeatMode.group:
      return NenRepeatMode.all;
  }
}

audio_svc.AudioServiceRepeatMode _toAudioServiceRepeatMode(
  NenRepeatMode repeatMode,
) {
  switch (repeatMode) {
    case NenRepeatMode.off:
      return audio_svc.AudioServiceRepeatMode.none;
    case NenRepeatMode.one:
      return audio_svc.AudioServiceRepeatMode.one;
    case NenRepeatMode.all:
      return audio_svc.AudioServiceRepeatMode.all;
  }
}

/// Manages playback state: play, pause, seek, queue, shuffle, repeat.
/// Now delegates to NenAudioHandler for background/lock-screen integration.
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final NenAudioHandler _handler;
  final Ref _ref;
  final Random _random = Random();
  StreamSubscription<audio_svc.PlaybackState>? _pbStateSub;
  StreamSubscription<audio_svc.AudioServiceRepeatMode>? _repeatModeSub;
  int? _crossfadeTriggeredSongId;
  bool _completionTransitionInFlight = false;
  Timer? _persistDebounce;
  int _playRequestId = 0;

  PlaybackNotifier(this._handler, this._ref) : super(const PlaybackState()) {
    _handler.onCompletion = _handleSongCompletion;
    _handler.onSkipToNext = next;
    _handler.onSkipToPrevious = previous;

    _pbStateSub = _handler.playbackState.listen((ps) {
      final decoded = _handler.currentDuration;
      final metadata = state.currentSong?.duration ?? Duration.zero;
      state = state.copyWith(
        position: ps.updatePosition,
        isPlaying: ps.playing,
        duration: AudioFormat.coalesceDuration(decoded, metadata),
      );
      _maybeStartCrossfade(ps.updatePosition);
    });

    _repeatModeSub = _handler.repeatModeStream.listen((repeatMode) {
      state = state.copyWith(repeatMode: _toNenRepeatMode(repeatMode));
    });

    Future.microtask(_loadPersistedPlaybackSettings);
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    final idx = startIndex.clamp(0, songs.length - 1);
    final song = songs[idx];
    final requestId = ++_playRequestId;
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queue: songs,
      queueIndex: idx,
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
      duration: song.duration,
    );
    unawaited(_runPlay(requestId, song, queue: songs, queueIndex: idx));
  }

  Future<void> playSong(Song song) async {
    final requestId = ++_playRequestId;
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queue: [song],
      queueIndex: 0,
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
      duration: song.duration,
    );
    unawaited(_runPlay(requestId, song));
  }

  Future<void> _runPlay(
    int requestId,
    Song song, {
    List<Song>? queue,
    int queueIndex = 0,
  }) async {
    try {
      await _handler.playSong(song, queue: queue, queueIndex: queueIndex);
      if (requestId != _playRequestId) return;
      _updateDuration(song);
      _trackRecentlyPlayed(song);
    } on PlaybackSupersededException {
      return;
    } catch (e) {
      if (requestId != _playRequestId) return;
      _emitError(_playErrorMessage(e, song.title));
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> pause() async {
    try {
      await _handler.pause();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      _emitError('Failed to pause');
    }
  }

  Future<void> resume() async {
    try {
      await _handler.play();
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      _emitError('Failed to resume');
    }
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    _crossfadeTriggeredSongId = null;
    await _handler.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;

    int nextIndex;
    if (state.shuffleMode == ShuffleMode.on) {
      if (state.queue.length <= 1) {
        if (state.repeatMode == NenRepeatMode.all && state.queue.isNotEmpty) {
          nextIndex = 0;
        } else {
          await stop();
          return;
        }
      } else {
        nextIndex = _pickRandomQueueIndex();
      }
    } else {
      nextIndex = state.queueIndex + 1;
    }

    if (nextIndex >= state.queue.length) {
      if (state.repeatMode == NenRepeatMode.all) {
        nextIndex = 0;
      } else {
        await stop();
        return;
      }
    }

    final song = state.queue[nextIndex];
    final requestId = ++_playRequestId;
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queueIndex: nextIndex,
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
      duration: song.duration,
    );
    unawaited(_runPlay(requestId, song, queue: state.queue, queueIndex: nextIndex));
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = state.queueIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == NenRepeatMode.all && state.queue.isNotEmpty) {
        prevIndex = state.queue.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    final song = state.queue[prevIndex];
    final requestId = ++_playRequestId;
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queueIndex: prevIndex,
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
      duration: song.duration,
    );
    unawaited(_runPlay(requestId, song, queue: state.queue, queueIndex: prevIndex));
  }

  Future<void> stop() async {
    _playRequestId++;
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(isPlaying: false, position: Duration.zero);
    unawaited(() async {
      try {
        await _handler.stop();
      } catch (_) {}
    }());
  }

  void toggleShuffle() {
    state = state.copyWith(
      shuffleMode: state.shuffleMode == ShuffleMode.off
          ? ShuffleMode.on
          : ShuffleMode.off,
    );
  }

  Future<void> cycleRepeat() async {
    final modes = NenRepeatMode.values;
    final nextIdx = (state.repeatMode.index + 1) % modes.length;
    final nextMode = modes[nextIdx];
    state = state.copyWith(repeatMode: nextMode);
    await _handler.setRepeatMode(_toAudioServiceRepeatMode(nextMode));
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _handler.setVolume(clamped);
    state = state.copyWith(volume: clamped);
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        _ref
            .read(settingsRepositoryProvider)
            .setVolume(clamped)
            .catchError((_) {}),
      );
    });
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    await _handler.setSpeed(clamped);
    state = state.copyWith(speed: clamped);
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        _ref
            .read(settingsRepositoryProvider)
            .setPlaybackSpeed(clamped)
            .catchError((_) {}),
      );
    });
  }

  // ── Queue Management ──────────────────────────────────────────────

  void addToQueue(Song song) {
    if (state.queue.isEmpty) {
      unawaited(playQueue([song]));
      return;
    }
    final queue = List<Song>.from(state.queue)..add(song);
    state = state.copyWith(queue: queue);
    _preloadNextTrack();
  }

  void addAllToQueue(List<Song> songs) {
    if (songs.isEmpty) return;
    if (state.queue.isEmpty) {
      unawaited(playQueue(songs));
      return;
    }
    final queue = List<Song>.from(state.queue)..addAll(songs);
    state = state.copyWith(queue: queue);
    _preloadNextTrack();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final queue = List<Song>.from(state.queue);
    final item = queue.removeAt(oldIndex);
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    queue.insert(adjustedNew, item);

    // Adjust current queueIndex
    int newQueueIndex = state.queueIndex;
    if (oldIndex == state.queueIndex) {
      newQueueIndex = adjustedNew;
    } else if (oldIndex < state.queueIndex && adjustedNew >= state.queueIndex) {
      newQueueIndex--;
    } else if (oldIndex > state.queueIndex && adjustedNew <= state.queueIndex) {
      newQueueIndex++;
    }

    state = state.copyWith(queue: queue, queueIndex: newQueueIndex);
  }

  void removeFromQueue(int index) {
    if (index == state.queueIndex) return; // Can't remove currently playing
    final queue = List<Song>.from(state.queue);
    queue.removeAt(index);
    int newIdx = state.queueIndex;
    if (index < state.queueIndex) newIdx--;
    state = state.copyWith(queue: queue, queueIndex: newIdx);
  }

  void clearQueue({bool keepCurrent = true}) {
    if (!keepCurrent || state.currentSong == null) {
      state = state.copyWith(queue: const [], queueIndex: 0);
      return;
    }

    state = state.copyWith(queue: [state.currentSong!], queueIndex: 0);
  }

  Future<void> applySettings(SettingsState settings) async {
    state = state.copyWith(
      crossfadeEnabled: settings.crossfadeEnabled,
      crossfadeDuration: settings.crossfadeDuration,
    );
    await _handler.setCrossfadeEnabled(settings.crossfadeEnabled);
    await _handler.setCrossfadeDuration(
      Duration(seconds: settings.crossfadeDuration),
    );
  }

  void _updateDuration(Song song) {
    final decoded = _handler.currentDuration;
    state = state.copyWith(
      duration: AudioFormat.coalesceDuration(decoded, song.duration),
    );
    _preloadNextTrack();
  }

  String _playErrorMessage(Object error, String title) {
    if (error is AudioPlaybackException) {
      return error.message;
    }
    return 'Failed to play: $title';
  }

  void _preloadNextTrack() {
    if (state.queue.isEmpty) return;
    int nextIndex;
    if (state.shuffleMode == ShuffleMode.on) {
      // Can't predict shuffle, skip preload
      return;
    }
    nextIndex = state.queueIndex + 1;
    if (nextIndex >= state.queue.length) {
      if (state.repeatMode == NenRepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    // Pre-load next track in background
    unawaited(
      _handler.audioRepo.preload(state.queue[nextIndex]).catchError((_) {}),
    );
  }

  Future<void> _handleSongCompletion() async {
    if (_completionTransitionInFlight) return;
    _completionTransitionInFlight = true;

    try {
      final currentSong = state.currentSong;
      if (state.repeatMode == NenRepeatMode.one) {
        if (currentSong != null) {
          _crossfadeTriggeredSongId = null;
          state = state.copyWith(position: Duration.zero, isPlaying: true);
          try {
            await _handler.playSong(
              currentSong,
              queue: state.queue,
              queueIndex: state.queueIndex,
            );
            _updateDuration(currentSong);
          } catch (e) {
            _emitError('Failed to repeat track');
            state = state.copyWith(isPlaying: false);
          }
          return;
        }

        await _handler.seek(Duration.zero);
        await _handler.play();
        state = state.copyWith(position: Duration.zero, isPlaying: true);
        return;
      }

      await next();
    } finally {
      _completionTransitionInFlight = false;
    }
  }

  void _trackRecentlyPlayed(Song song) {
    try {
      _ref.read(recentlyPlayedProvider.notifier).addSong(song.id);
    } catch (e) {
      debugPrint('trackRecentlyPlayed error: $e');
    }
  }

  Future<void> _loadPersistedPlaybackSettings() async {
    final settingsRepo = _ref.read(settingsRepositoryProvider);
    final volume = await settingsRepo.getVolume();
    final speed = await settingsRepo.getPlaybackSpeed();
    final crossfadeEnabled = await settingsRepo.getCrossfadeEnabled();
    final crossfadeDuration = await settingsRepo.getCrossfadeDuration();

    state = state.copyWith(
      volume: volume,
      speed: speed,
      crossfadeEnabled: crossfadeEnabled,
      crossfadeDuration: crossfadeDuration,
    );

    await _handler.setVolume(volume);
    await _handler.setSpeed(speed);
    await _handler.setCrossfadeEnabled(crossfadeEnabled);
    await _handler.setCrossfadeDuration(Duration(seconds: crossfadeDuration));

    final recentIds = await settingsRepo.getRecentSongIds();
    if (recentIds.isNotEmpty) {
      final lastId = recentIds.first;
      final songs = await _ref.read(getSongsUseCaseProvider)();
      final lastSong = songs.where((s) => s.id == lastId).firstOrNull;

      if (lastSong != null && state.currentSong == null && !state.isPlaying) {
        state = state.copyWith(
          currentSong: lastSong,
          queue: [lastSong],
          queueIndex: 0,
        );
      }
    }
  }

  int _pickRandomQueueIndex() {
    if (state.queue.length <= 1) return state.queueIndex;

    var nextIndex = state.queueIndex;
    while (nextIndex == state.queueIndex) {
      nextIndex = _random.nextInt(state.queue.length);
    }
    return nextIndex;
  }

  void _maybeStartCrossfade(Duration position) {
    if (_completionTransitionInFlight) return;
    final currentSong = state.currentSong;
    if (!state.crossfadeEnabled ||
        !state.isPlaying ||
        currentSong == null ||
        state.duration <= Duration.zero ||
        state.repeatMode == NenRepeatMode.one) {
      return;
    }

    final remaining = state.duration - position;
    final threshold = Duration(seconds: state.crossfadeDuration);
    if (remaining > threshold) {
      _crossfadeTriggeredSongId = null;
      return;
    }

    if (_crossfadeTriggeredSongId == currentSong.id) {
      return;
    }

    final hasNext =
        state.queueIndex < state.queue.length - 1 ||
        state.repeatMode == NenRepeatMode.all ||
        (state.shuffleMode == ShuffleMode.on && state.queue.length > 1);
    if (!hasNext) return;

    _crossfadeTriggeredSongId = currentSong.id;
    unawaited(next().catchError((_) {}));
  }

  void _emitError(String message) {
    _ref.read(playbackFeedbackProvider.notifier).show(message);
  }

  @override
  void dispose() {
    _handler.onCompletion = null;
    _handler.onSkipToNext = null;
    _handler.onSkipToPrevious = null;
    _pbStateSub?.cancel();
    _repeatModeSub?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }
}

class PlaybackFeedbackMessage {
  final int id;
  final String message;

  const PlaybackFeedbackMessage({required this.id, required this.message});
}

class PlaybackFeedbackNotifier extends StateNotifier<PlaybackFeedbackMessage?> {
  PlaybackFeedbackNotifier() : super(null);

  int _nextId = 0;

  void show(String message) {
    state = PlaybackFeedbackMessage(id: ++_nextId, message: message);
  }

  void clear(int id) {
    if (state?.id == id) {
      state = null;
    }
  }
}

final playbackFeedbackProvider =
    StateNotifierProvider<PlaybackFeedbackNotifier, PlaybackFeedbackMessage?>(
      (_) => PlaybackFeedbackNotifier(),
    );

final playbackProvider = StateNotifierProvider<PlaybackNotifier, PlaybackState>(
  (ref) {
    final handler = ref.watch(audioHandlerProvider);
    final notifier = PlaybackNotifier(handler, ref);
    ref.listen<SettingsState>(settingsProvider, (_, next) {
      unawaited(notifier.applySettings(next).catchError((_) {}));
    });
    return notifier;
  },
);
