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
  final double speed;
  final bool crossfadeEnabled;
  final int crossfadeDuration; // seconds

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
    this.speed = 1.0,
    this.crossfadeEnabled = false,
    this.crossfadeDuration = 3,
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
    double? speed,
    bool? crossfadeEnabled,
    int? crossfadeDuration,
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
      speed: speed ?? this.speed,
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }
}
