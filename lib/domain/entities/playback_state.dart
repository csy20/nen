import 'song.dart';

enum NenRepeatMode { off, one, all }

enum ShuffleMode { off, on }

/// Immutable playback state.
class PlaybackState {
  final Song? currentSong;
  final List<Song> queue;
  final int queueIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double volume;
  final NenRepeatMode repeatMode;
  final ShuffleMode shuffleMode;

  const PlaybackState({
    this.currentSong,
    this.queue = const [],
    this.queueIndex = 0,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.repeatMode = NenRepeatMode.off,
    this.shuffleMode = ShuffleMode.off,
  });

  PlaybackState copyWith({
    Song? currentSong,
    List<Song>? queue,
    int? queueIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? volume,
    NenRepeatMode? repeatMode,
    ShuffleMode? shuffleMode,
  }) {
    return PlaybackState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      queueIndex: queueIndex ?? this.queueIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
    );
  }
}
