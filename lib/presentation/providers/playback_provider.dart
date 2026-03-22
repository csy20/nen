import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../data/services/nen_audio_handler.dart';
import 'di_providers.dart';
import 'settings_provider.dart';

NenRepeatMode _toNenRepeatMode(
  audio_svc.AudioServiceRepeatMode repeatMode,
) {
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

  PlaybackNotifier(this._handler, this._ref) : super(const PlaybackState()) {
    _handler.onCompletion = _onSongComplete;

    _pbStateSub = _handler.playbackState.listen((ps) {
      state = state.copyWith(
        position: ps.updatePosition,
        isPlaying: ps.playing,
      );
      _maybeStartCrossfade(ps.updatePosition);
    });

    _repeatModeSub = _handler.repeatModeStream.listen((repeatMode) {
      state = state.copyWith(repeatMode: _toNenRepeatMode(repeatMode));
    });

    Future.microtask(_loadPersistedPlaybackSettings);
  }

  Future<void> initEngine() async {
    // Engine is already initialized via NenAudioHandler.init() in main()
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    final idx = startIndex.clamp(0, songs.length - 1);
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queue: songs,
      queueIndex: idx,
      currentSong: songs[idx],
      isPlaying: true,
    );
    try {
      await _handler.playSong(songs[idx], queue: songs, queueIndex: idx);
      _updateDuration(songs[idx]);
      _trackRecentlyPlayed(songs[idx]);
    } catch (e) {
      _emitError('Failed to play: ${songs[idx].title}');
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> playSong(Song song) async {
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queue: [song],
      queueIndex: 0,
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(song);
      _updateDuration(song);
      _trackRecentlyPlayed(song);
    } catch (e) {
      _emitError('Failed to play: ${song.title}');
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
      nextIndex = _pickRandomQueueIndex();
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

    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queueIndex: nextIndex,
      currentSong: state.queue[nextIndex],
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(
        state.queue[nextIndex],
        queue: state.queue,
        queueIndex: nextIndex,
      );
      _updateDuration(state.queue[nextIndex]);
      _trackRecentlyPlayed(state.queue[nextIndex]);
    } catch (e) {
      _emitError('Failed to play next track');
    }
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    if (state.position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }

    int prevIndex = state.queueIndex - 1;
    if (prevIndex < 0) {
      if (state.repeatMode == NenRepeatMode.all) {
        prevIndex = state.queue.length - 1;
      } else {
        prevIndex = 0;
      }
    }

    _crossfadeTriggeredSongId = null;
    state = state.copyWith(
      queueIndex: prevIndex,
      currentSong: state.queue[prevIndex],
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(
        state.queue[prevIndex],
        queue: state.queue,
        queueIndex: prevIndex,
      );
      _updateDuration(state.queue[prevIndex]);
      _trackRecentlyPlayed(state.queue[prevIndex]);
    } catch (e) {
      _emitError('Failed to play previous track');
    }
  }

  Future<void> stop() async {
    try {
      await _handler.stop();
    } catch (_) {}
    _crossfadeTriggeredSongId = null;
    state = state.copyWith(isPlaying: false, position: Duration.zero);
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
    await _handler.setRepeatMode(_toAudioServiceRepeatMode(modes[nextIdx]));
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    await _handler.setVolume(clamped);
    state = state.copyWith(volume: clamped);
    await _ref.read(settingsRepositoryProvider).setVolume(clamped);
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0).toDouble();
    await _handler.setSpeed(clamped);
    state = state.copyWith(speed: clamped);
    await _ref.read(settingsRepositoryProvider).setPlaybackSpeed(clamped);
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
    state = state.copyWith(duration: song.duration);
    _preloadNextTrack();
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
    _handler.audioRepo.preload(state.queue[nextIndex]);
  }

  void _onSongComplete() {
    if (state.repeatMode == NenRepeatMode.one) {
      _handler.seek(Duration.zero);
      _handler.play();
    } else {
      next();
    }
  }

  void _trackRecentlyPlayed(Song song) {
    try {
      _ref.read(recentlyPlayedProvider.notifier).addSong(song.id);
    } catch (_) {}
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
    unawaited(next());
  }

  void _emitError(String message) {
    _ref.read(playbackFeedbackProvider.notifier).show(message);
  }

  @override
  void dispose() {
    _pbStateSub?.cancel();
    _repeatModeSub?.cancel();
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
      unawaited(notifier.applySettings(next));
    });
    return notifier;
  },
);
