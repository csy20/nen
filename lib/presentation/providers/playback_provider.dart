import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../data/services/nen_audio_handler.dart';
import 'di_providers.dart';
import 'settings_provider.dart';

/// Manages playback state: play, pause, seek, queue, shuffle, repeat.
/// Now delegates to NenAudioHandler for background/lock-screen integration.
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final NenAudioHandler _handler;
  final Ref _ref;
  StreamSubscription<audio_svc.PlaybackState>? _pbStateSub;

  /// Callback for showing error messages in the UI.
  void Function(String message)? onPlaybackError;

  PlaybackNotifier(this._handler, this._ref) : super(const PlaybackState()) {
    _handler.onCompletion = _onSongComplete;

    _pbStateSub = _handler.playbackState.listen((ps) {
      state = state.copyWith(
        position: ps.updatePosition,
      );
    });
  }

  Future<void> initEngine() async {
    // Engine is already initialized via NenAudioHandler.init() in main()
  }

  Future<void> playQueue(List<Song> songs, {int startIndex = 0}) async {
    if (songs.isEmpty) return;
    final idx = startIndex.clamp(0, songs.length - 1);
    state = state.copyWith(
      queue: songs,
      queueIndex: idx,
      currentSong: songs[idx],
      isPlaying: true,
    );
    try {
      await _handler.playSong(songs[idx], queue: songs, queueIndex: idx);
      _updateDuration(songs[idx]);
      _applySpeed();
      _trackRecentlyPlayed(songs[idx]);
    } catch (e) {
      onPlaybackError?.call('Failed to play: ${songs[idx].title}');
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> playSong(Song song) async {
    state = state.copyWith(
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(song);
      _updateDuration(song);
      _applySpeed();
      _trackRecentlyPlayed(song);
    } catch (e) {
      onPlaybackError?.call('Failed to play: ${song.title}');
      state = state.copyWith(isPlaying: false);
    }
  }

  Future<void> pause() async {
    try {
      await _handler.pause();
      state = state.copyWith(isPlaying: false);
    } catch (e) {
      onPlaybackError?.call('Failed to pause');
    }
  }

  Future<void> resume() async {
    try {
      await _handler.play();
      state = state.copyWith(isPlaying: true);
    } catch (e) {
      onPlaybackError?.call('Failed to resume');
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
    await _handler.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> next() async {
    if (state.queue.isEmpty) return;

    int nextIndex;
    if (state.shuffleMode == ShuffleMode.on) {
      nextIndex = (DateTime.now().millisecondsSinceEpoch % state.queue.length);
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

    state = state.copyWith(
      queueIndex: nextIndex,
      currentSong: state.queue[nextIndex],
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(state.queue[nextIndex],
          queue: state.queue, queueIndex: nextIndex);
      _updateDuration(state.queue[nextIndex]);
      _applySpeed();
      _trackRecentlyPlayed(state.queue[nextIndex]);
    } catch (e) {
      onPlaybackError?.call('Failed to play next track');
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

    state = state.copyWith(
      queueIndex: prevIndex,
      currentSong: state.queue[prevIndex],
      isPlaying: true,
      position: Duration.zero,
    );
    try {
      await _handler.playSong(state.queue[prevIndex],
          queue: state.queue, queueIndex: prevIndex);
      _updateDuration(state.queue[prevIndex]);
      _applySpeed();
      _trackRecentlyPlayed(state.queue[prevIndex]);
    } catch (e) {
      onPlaybackError?.call('Failed to play previous track');
    }
  }

  Future<void> stop() async {
    try {
      await _handler.stop();
    } catch (_) {}
    state = state.copyWith(
      isPlaying: false,
      position: Duration.zero,
    );
  }

  void toggleShuffle() {
    state = state.copyWith(
      shuffleMode: state.shuffleMode == ShuffleMode.off
          ? ShuffleMode.on
          : ShuffleMode.off,
    );
  }

  void cycleRepeat() {
    final modes = NenRepeatMode.values;
    final nextIdx = (state.repeatMode.index + 1) % modes.length;
    state = state.copyWith(repeatMode: modes[nextIdx]);
  }

  Future<void> setVolume(double volume) async {
    await _handler.audioRepo.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    state = state.copyWith(speed: clamped);
    await _handler.audioRepo.setSpeed(clamped);
  }

  void _applySpeed() {
    if (state.speed != 1.0) {
      _handler.audioRepo.setSpeed(state.speed);
    }
  }

  // ── Queue Management ──────────────────────────────────────────────

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

  @override
  void dispose() {
    _pbStateSub?.cancel();
    super.dispose();
  }
}

final playbackProvider =
    StateNotifierProvider<PlaybackNotifier, PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlaybackNotifier(handler, ref);
});
