import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/neu_playback_button.dart';
import 'equalizer_screen.dart';

/// Full-screen now-playing screen with visualizer, controls, and album art.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  Color _accentColor = NenTheme.defaultAccent;
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    // Wire error callback for snackbar feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playbackProvider.notifier).onPlaybackError = (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final song = playback.currentSong;
    final size = MediaQuery.of(context).size;
    final favorites = ref.watch(favoritesProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    // Extract accent color from album art when song changes
    if (song != null && song.id != _lastSongId) {
      _lastSongId = song.id;
      _extractAccentColor(song.id);
    }

    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      body: Stack(
        children: [
          // Background: shader visualizer
          Positioned.fill(
            child: AudioVisualizerWidget(accentColor: _accentColor),
          ),

          // Content overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    NenTheme.trueBlack.withValues(alpha: 0.4),
                    NenTheme.trueBlack.withValues(alpha: 0.85),
                    NenTheme.trueBlack,
                  ],
                  stops: const [0.0, 0.45, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // UI controls
          SafeArea(
            child: Column(
              children: [
                // Top bar with glassmorphic blur
                _buildTopBar(context, song, favorites, sleepTimer),

                const Spacer(flex: 3),

                // Album art
                _buildAlbumArt(context, song, size),

                const Spacer(flex: 2),

                // Song info
                _buildSongInfo(song),

                const SizedBox(height: 24),

                // Glassmorphic control panel
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildProgressBar(playback),
                            const SizedBox(height: 12),
                            _buildControls(playback),
                            const SizedBox(height: 8),
                            _buildVolumeBar(playback),
                            const SizedBox(height: 4),
                            _buildSpeedControl(playback),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Song? song, Set<int> favorites,
      SleepTimerState sleepTimer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  color: NenTheme.textPrimary,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
                const Spacer(),
                // Sleep timer indicator
                if (sleepTimer.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatDuration(sleepTimer.remaining ?? Duration.zero),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: NenTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                // Favorite button
                if (song != null)
                  IconButton(
                    icon: Icon(
                      favorites.contains(song.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorites.contains(song.id)
                          ? Colors.redAccent
                          : NenTheme.textPrimary,
                      size: 22,
                    ),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(song.id),
                    tooltip: 'Favorite',
                  ),
                // Options menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: NenTheme.textPrimary),
                  color: NenTheme.surfaceElevated,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'queue', child: Text('View Queue')),
                    const PopupMenuItem(
                        value: 'equalizer', child: Text('Equalizer')),
                    PopupMenuItem(
                      value: 'sleep',
                      child: Text(sleepTimer.isActive
                          ? 'Cancel Sleep Timer'
                          : 'Sleep Timer'),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'queue') _showQueueSheet(context);
                    if (val == 'equalizer') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EqualizerScreen(),
                        ),
                      );
                    }
                    if (val == 'sleep') {
                      if (sleepTimer.isActive) {
                        ref.read(sleepTimerProvider.notifier).cancel();
                      } else {
                        _showSleepTimerPicker(context);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(BuildContext context, Song? song, Size screenSize) {
    final artSize = screenSize.width * 0.55;
    final artAsync = song != null ? ref.watch(albumArtProvider(song.id)) : null;

    return Container(
      width: artSize,
      height: artSize,
      decoration: BoxDecoration(
        color: NenTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: artAsync?.when(
              data: (art) {
                if (art != null && art is Uint8List && art.isNotEmpty) {
                  return Image.memory(art, fit: BoxFit.cover);
                }
                return _defaultArtLarge();
              },
              loading: () => _defaultArtLarge(),
              error: (_, __) => _defaultArtLarge(),
            ) ??
            _defaultArtLarge(),
      ),
    );
  }

  Widget _defaultArtLarge() {
    return Container(
      color: NenTheme.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: _accentColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song? song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            song?.title ?? 'No Song',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NenTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            song?.artist ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NenTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(PlaybackState playback) {
    final position = playback.position;
    final duration =
        playback.duration > Duration.zero ? playback.duration : const Duration(seconds: 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: position.inMilliseconds
                  .toDouble()
                  .clamp(0, duration.inMilliseconds.toDouble()),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (v) {
                ref
                    .read(playbackProvider.notifier)
                    .seek(Duration(milliseconds: v.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(position),
                    style: const TextStyle(
                        color: NenTheme.textTertiary, fontSize: 11)),
                Text(_formatDuration(duration),
                    style: const TextStyle(
                        color: NenTheme.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(PlaybackState playback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: playback.shuffleMode == ShuffleMode.on
                  ? Theme.of(context).colorScheme.primary
                  : NenTheme.textTertiary,
              size: 22,
            ),
            onPressed: () =>
                ref.read(playbackProvider.notifier).toggleShuffle(),
            tooltip: 'Shuffle',
          ),

          // Previous
          NeuPlaybackButton(
            icon: Icons.skip_previous_rounded,
            size: 48,
            onPressed: () => ref.read(playbackProvider.notifier).previous(),
          ),

          // Play/Pause with animated icon morph
          NeuPlaybackButton(
            icon: Icons.play_arrow_rounded,
            size: 68,
            isPrimary: true,
            animatePlayPause: true,
            isPlaying: playback.isPlaying,
            onPressed: () =>
                ref.read(playbackProvider.notifier).togglePlayPause(),
          ),

          // Next
          NeuPlaybackButton(
            icon: Icons.skip_next_rounded,
            size: 48,
            onPressed: () => ref.read(playbackProvider.notifier).next(),
          ),

          // Repeat
          IconButton(
            icon: Icon(
              playback.repeatMode == NenRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: playback.repeatMode != NenRepeatMode.off
                  ? Theme.of(context).colorScheme.primary
                  : NenTheme.textTertiary,
              size: 22,
            ),
            onPressed: () =>
                ref.read(playbackProvider.notifier).cycleRepeat(),
            tooltip: 'Repeat',
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBar(PlaybackState playback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded,
              color: NenTheme.textTertiary, size: 18),
          Expanded(
            child: Slider(
              value: playback.volume,
              onChanged: (v) =>
                  ref.read(playbackProvider.notifier).setVolume(v),
            ),
          ),
          const Icon(Icons.volume_up_rounded,
              color: NenTheme.textTertiary, size: 18),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(PlaybackState playback) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          const Icon(Icons.speed_rounded,
              color: NenTheme.textTertiary, size: 18),
          Expanded(
            child: Slider(
              value: playback.speed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${playback.speed.toStringAsFixed(1)}x',
              onChanged: (v) =>
                  ref.read(playbackProvider.notifier).setSpeed(v),
            ),
          ),
          Text(
            '${playback.speed.toStringAsFixed(1)}x',
            style: const TextStyle(
                color: NenTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NenTheme.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Consumer(builder: (ctx, ref, _) {
            final playback = ref.watch(playbackProvider);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Up Next',
                          style: TextStyle(
                              color: NenTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('${playback.queue.length} songs',
                          style: const TextStyle(
                              color: NenTheme.textTertiary, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scrollController,
                    itemCount: playback.queue.length,
                    onReorder: (oldIdx, newIdx) {
                      ref
                          .read(playbackProvider.notifier)
                          .reorderQueue(oldIdx, newIdx);
                    },
                    itemBuilder: (ctx, index) {
                      final s = playback.queue[index];
                      final isCurrent = index == playback.queueIndex;
                      return ListTile(
                        key: ValueKey('queue_${s.id}_$index'),
                        leading: isCurrent
                            ? Icon(Icons.equalizer_rounded,
                                color: Theme.of(ctx).colorScheme.primary)
                            : Text('${index + 1}',
                                style: const TextStyle(
                                    color: NenTheme.textTertiary)),
                        title: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? Theme.of(ctx).colorScheme.primary
                                  : NenTheme.textPrimary,
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.normal,
                            )),
                        subtitle: Text(s.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: NenTheme.textTertiary, fontSize: 12)),
                        trailing: isCurrent
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: NenTheme.textTertiary, size: 18),
                                onPressed: () => ref
                                    .read(playbackProvider.notifier)
                                    .removeFromQueue(index),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }

  void _showSleepTimerPicker(BuildContext context) {
    final durations = [
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(minutes: 60),
      const Duration(minutes: 90),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: NenTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Timer',
                style: TextStyle(
                    color: NenTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...durations.map((d) => ListTile(
                  title: Text('${d.inMinutes} minutes',
                      style: const TextStyle(color: NenTheme.textPrimary)),
                  onTap: () {
                    ref.read(sleepTimerProvider.notifier).start(
                      d,
                      () => ref.read(playbackProvider.notifier).pause(),
                    );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Sleep timer set for ${d.inMinutes} min')),
                    );
                  },
                )),
            ListTile(
              title: const Text('End of track',
                  style: TextStyle(color: NenTheme.textPrimary)),
              onTap: () {
                final playback = ref.read(playbackProvider);
                final remaining = playback.duration - playback.position;
                if (remaining > Duration.zero) {
                  ref.read(sleepTimerProvider.notifier).start(
                    remaining,
                    () => ref.read(playbackProvider.notifier).pause(),
                  );
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractAccentColor(int songId) async {
    try {
      final art = await ref.read(musicRepositoryProvider).getAlbumArt(songId);
      if (art != null && art.isNotEmpty) {
        final image = MemoryImage(art);
        final palette = await PaletteGenerator.fromImageProvider(
          image,
          maximumColorCount: 8,
        );
        final dominant = palette.dominantColor?.color ??
            palette.vibrantColor?.color ??
            NenTheme.defaultAccent;

        if (mounted) {
          setState(() => _accentColor = dominant);
        }
      }
    } catch (_) {
      // Fall back to default accent
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
