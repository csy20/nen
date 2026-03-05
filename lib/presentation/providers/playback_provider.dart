import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../data/services/nen_audio_handler.dart';
import 'di_providers.dart';

/// Manages playback state: play, pause, seek, queue, shuffle, repeat.
/// Now delegates to NenAudioHandler for background/lock-screen integration.
class PlaybackNotifier extends StateNotifier<PlaybackState> {
  final NenAudioHandler _handler;
  StreamSubscription<audio_svc.PlaybackState>? _pbStateSub;

  PlaybackNotifier(this._handler) : super(const PlaybackState()) {
    // Wire completion callback for auto-next
    _handler.onCompletion = _onSongComplete;

    // Listen to audio_service playback state for position updates
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
    await _handler.playSong(songs[idx], queue: songs, queueIndex: idx);
    _updateDuration(songs[idx]);
  }

  Future<void> playSong(Song song) async {
    state = state.copyWith(
      currentSong: song,
      isPlaying: true,
      position: Duration.zero,
    );
    await _handler.playSong(song);
    _updateDuration(song);
  }

  Future<void> pause() async {
    await _handler.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _handler.play();
    state = state.copyWith(isPlaying: true);
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
    await _handler.playSong(state.queue[nextIndex],
        queue: state.queue, queueIndex: nextIndex);
    _updateDuration(state.queue[nextIndex]);
  }

  Future<void> previous() async {
    if (state.queue.isEmpty) return;

    // If past 3 seconds, restart current song
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
    await _handler.playSong(state.queue[prevIndex],
        queue: state.queue, queueIndex: prevIndex);
    _updateDuration(state.queue[prevIndex]);
  }

  Future<void> stop() async {
    await _handler.stop();
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

  void _updateDuration(Song song) {
    state = state.copyWith(duration: song.duration);
  }

  void _onSongComplete() {
    if (state.repeatMode == NenRepeatMode.one) {
      _handler.seek(Duration.zero);
      _handler.play();
    } else {
      next();
    }
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
  return PlaybackNotifier(handler);
});
