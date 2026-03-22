import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../theme/page_transitions.dart';
import '../widgets/audio_visualizer.dart';
import '../widgets/neu_playback_button.dart';
import '../widgets/overflow_marquee_text.dart';
import 'equalizer_screen.dart';

/// Full-screen now-playing screen with visualizer, controls, and album art.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final song = playback.currentSong;
    final size = MediaQuery.of(context).size;
    final favorites = ref.watch(favoritesProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);
    final colors = NenTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 900) {
            Navigator.maybePop(context);
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: _AnimatedAccentBuilder(
                songId: song?.id,
                builder: (accentColor) {
                  return AudioVisualizerWidget(accentColor: accentColor);
                },
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      colors.background.withValues(alpha: 0.4),
                      colors.background.withValues(alpha: 0.85),
                      colors.background,
                    ],
                    stops: const [0.0, 0.45, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context, ref, song, favorites, sleepTimer),
                  const Spacer(flex: 3),
                  _buildAlbumArt(context, ref, song, size),
                  const Spacer(flex: 2),
                  _buildSongInfo(context, song),
                  const SizedBox(height: 24),
                  _buildControlPanel(context, ref, playback),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    Set<int> favorites,
    SleepTimerState sleepTimer,
  ) {
    final colors = NenTheme.of(context);
    final isFavorite = song != null && favorites.contains(song.id);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: colors.glassSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.glassBorder, width: 0.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        'NOW PLAYING',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                        ),
                        color: colors.textPrimary,
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                      const Spacer(),
                      if (sleepTimer.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _formatDuration(
                              sleepTimer.remaining ?? Duration.zero,
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (song != null)
                        IconButton(
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite
                                ? Colors.redAccent
                                : colors.textPrimary,
                            size: 22,
                          ),
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(song.id),
                          tooltip: 'Favorite',
                        ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colors.textPrimary,
                        ),
                        color: colors.surfaceElevated,
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'queue',
                            child: Text('View Queue'),
                          ),
                          const PopupMenuItem(
                            value: 'equalizer',
                            child: Text('Equalizer'),
                          ),
                          PopupMenuItem(
                            value: 'sleep',
                            child: Text(
                              sleepTimer.isActive
                                  ? 'Cancel Sleep Timer'
                                  : 'Sleep Timer',
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'queue') {
                            _showQueueSheet(context);
                          } else if (value == 'equalizer') {
                            Navigator.push(
                              context,
                              NenSlideRoute(
                                builder: (_) => const EqualizerScreen(),
                              ),
                            );
                          } else if (value == 'sleep') {
                            if (sleepTimer.isActive) {
                              ref.read(sleepTimerProvider.notifier).cancel();
                            } else {
                              _showSleepTimerPicker(context, ref);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArt(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    Size screenSize,
  ) {
    final artSize = screenSize.width * 0.55;
    final colors = NenTheme.of(context);
    final artAsync = song != null ? ref.watch(albumArtProvider(song.id)) : null;

    return _AnimatedAccentBuilder(
      songId: song?.id,
      builder: (accentColor) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: artSize,
          height: artSize,
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.22),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child:
                artAsync?.when(
                  data: (art) => _buildAlbumArtImage(art, accentColor, colors),
                  loading: () => _defaultArtLarge(accentColor, colors),
                  error: (error, stackTrace) =>
                      _defaultArtLarge(accentColor, colors),
                ) ??
                _defaultArtLarge(accentColor, colors),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArtImage(
    Uint8List? art,
    Color accentColor,
    NenColors colors,
  ) {
    if (art != null && art.isNotEmpty) {
      return Image.memory(art, fit: BoxFit.cover);
    }
    return _defaultArtLarge(accentColor, colors);
  }

  Widget _defaultArtLarge(Color accentColor, NenColors colors) {
    return Container(
      color: colors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: accentColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSongInfo(BuildContext context, Song? song) {
    final colors = NenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          SizedBox(
            height: 28,
            child: OverflowMarqueeText(
              text: song?.title ?? 'No Song',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 20,
            child: OverflowMarqueeText(
              text: song?.artist ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    return RepaintBoundary(
      child: Container(
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
                  _buildProgressBar(context, ref, playback),
                  const SizedBox(height: 12),
                  _buildControls(context, ref, playback),
                  const SizedBox(height: 8),
                  _buildVolumeBar(context, ref, playback),
                  const SizedBox(height: 4),
                  _buildSpeedControl(context, ref, playback),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    final colors = NenTheme.of(context);
    final position = playback.position;
    final duration = playback.duration > Duration.zero
        ? playback.duration
        : const Duration(seconds: 1);

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
              value: position.inMilliseconds.toDouble().clamp(
                0,
                duration.inMilliseconds.toDouble(),
              ),
              max: duration.inMilliseconds.toDouble(),
              onChanged: (value) {
                ref
                    .read(playbackProvider.notifier)
                    .seek(Duration(milliseconds: value.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    final colors = NenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: playback.shuffleMode == ShuffleMode.on
                  ? Theme.of(context).colorScheme.primary
                  : colors.textTertiary,
              size: 22,
            ),
            onPressed: () =>
                ref.read(playbackProvider.notifier).toggleShuffle(),
            tooltip: 'Shuffle',
          ),
          Semantics(
            label: 'Previous track',
            button: true,
            child: NeuPlaybackButton(
              icon: Icons.skip_previous_rounded,
              size: 48,
              onPressed: () => ref.read(playbackProvider.notifier).previous(),
            ),
          ),
          Semantics(
            label: playback.isPlaying ? 'Pause' : 'Play',
            button: true,
            child: NeuPlaybackButton(
              icon: Icons.play_arrow_rounded,
              size: 68,
              isPrimary: true,
              animatePlayPause: true,
              isPlaying: playback.isPlaying,
              onPressed: () =>
                  ref.read(playbackProvider.notifier).togglePlayPause(),
            ),
          ),
          Semantics(
            label: 'Next track',
            button: true,
            child: NeuPlaybackButton(
              icon: Icons.skip_next_rounded,
              size: 48,
              onPressed: () => ref.read(playbackProvider.notifier).next(),
            ),
          ),
          IconButton(
            icon: Icon(
              playback.repeatMode == NenRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: playback.repeatMode != NenRepeatMode.off
                  ? Theme.of(context).colorScheme.primary
                  : colors.textTertiary,
              size: 22,
            ),
            onPressed: () => ref.read(playbackProvider.notifier).cycleRepeat(),
            tooltip: 'Repeat',
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeBar(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    final colors = NenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Icon(Icons.volume_down_rounded, color: colors.textTertiary, size: 18),
          Expanded(
            child: Slider(
              value: playback.volume,
              onChanged: (value) =>
                  ref.read(playbackProvider.notifier).setVolume(value),
            ),
          ),
          Icon(Icons.volume_up_rounded, color: colors.textTertiary, size: 18),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    final colors = NenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, color: colors.textTertiary, size: 18),
          Expanded(
            child: Slider(
              value: playback.speed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              onChanged: (value) =>
                  ref.read(playbackProvider.notifier).setSpeed(value),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _formatSpeed(playback.speed),
              textAlign: TextAlign.right,
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    final colors = NenTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Consumer(
              builder: (sheetContext, ref, _) {
                final playback = ref.watch(playbackProvider);
                final sheetColors = NenTheme.of(sheetContext);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Up Next',
                            style: TextStyle(
                              color: sheetColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${playback.queue.length} songs',
                            style: TextStyle(
                              color: sheetColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: playback.queue.length <= 1
                                ? null
                                : () => ref
                                      .read(playbackProvider.notifier)
                                      .clearQueue(),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: scrollController,
                        itemCount: playback.queue.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(playbackProvider.notifier)
                              .reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final queuedSong = playback.queue[index];
                          final isCurrent = index == playback.queueIndex;
                          return ListTile(
                            key: ValueKey('queue_${queuedSong.id}_$index'),
                            leading: isCurrent
                                ? Icon(
                                    Icons.equalizer_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: sheetColors.textTertiary,
                                    ),
                                  ),
                            title: Text(
                              queuedSong.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.primary
                                    : sheetColors.textPrimary,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              queuedSong.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: sheetColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isCurrent
                                ? null
                                : IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: sheetColors.textTertiary,
                                      size: 18,
                                    ),
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
              },
            );
          },
        );
      },
    );
  }

  void _showSleepTimerPicker(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final durations = [
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(minutes: 45),
      const Duration(minutes: 60),
      const Duration(minutes: 90),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sleep Timer',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ...durations.map((duration) {
                return ListTile(
                  title: Text(
                    '${duration.inMinutes} minutes',
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  onTap: () {
                    _startSleepTimer(
                      context,
                      ref,
                      duration,
                      message: 'Sleep timer set for ${duration.inMinutes} min',
                    );
                    Navigator.pop(sheetContext);
                  },
                );
              }),
              ListTile(
                title: Text(
                  'Custom minutes',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final duration = await _showCustomSleepDurationDialog(
                    context,
                  );
                  if (duration != null && context.mounted) {
                    _startSleepTimer(
                      context,
                      ref,
                      duration,
                      message: 'Sleep timer set for ${duration.inMinutes} min',
                    );
                  }
                },
              ),
              ListTile(
                title: Text(
                  'End of track',
                  style: TextStyle(color: colors.textPrimary),
                ),
                onTap: () {
                  final playback = ref.read(playbackProvider);
                  final remaining = playback.duration - playback.position;
                  if (remaining > Duration.zero) {
                    _startSleepTimer(
                      context,
                      ref,
                      remaining,
                      message: 'Sleep timer set for end of track',
                    );
                  }
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Duration?> _showCustomSleepDurationDialog(BuildContext context) async {
    final controller = TextEditingController();
    final colors = NenTheme.of(context);

    return showDialog<Duration>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: const Text('Custom Sleep Timer'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Minutes'),
            style: TextStyle(color: colors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text.trim());
                if (minutes == null || minutes <= 0) {
                  Navigator.pop(dialogContext);
                  return;
                }
                Navigator.pop(dialogContext, Duration(minutes: minutes));
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void _startSleepTimer(
    BuildContext context,
    WidgetRef ref,
    Duration duration, {
    required String message,
  }) {
    ref
        .read(sleepTimerProvider.notifier)
        .start(duration, () => ref.read(playbackProvider.notifier).pause());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _formatSpeed(double speed) {
    final fixed = speed.toStringAsFixed(2);
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return '${trimmed}x';
  }
}

class _AnimatedAccentBuilder extends ConsumerWidget {
  final int? songId;
  final Widget Function(Color accentColor) builder;

  const _AnimatedAccentBuilder({required this.songId, required this.builder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetColor = songId == null
        ? NenTheme.defaultAccent
        : ref
              .watch(songAccentColorProvider(songId!))
              .maybeWhen(
                data: (color) => color,
                orElse: () => NenTheme.defaultAccent,
              );

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: targetColor),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, accentColor, _) {
        return builder(accentColor ?? NenTheme.defaultAccent);
      },
    );
  }
}
