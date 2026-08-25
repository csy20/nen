import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/fft_processor.dart';
import '../../domain/entities/entities.dart';
import '../providers/di_providers.dart';
import '../providers/library_providers.dart';
import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/nen_theme.dart';
import '../theme/page_transitions.dart';
import '../widgets/neu_playback_button.dart';
import '../widgets/overflow_marquee_text.dart';
import '../widgets/song_actions_sheet.dart';
import 'equalizer_screen.dart';

/// Hero tag shared with any source widget (e.g. mini player bar).
const String _kHeroTag = 'now_playing_art';

/// Number of audio-reactive bars in the inline visualizer.
const int _kBarCount = 20;

/// Lyrics panel visibility toggle (session-scoped).
final lyricsVisibleProvider = StateProvider<bool>((ref) => false);

/// Full-screen now-playing screen.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final song = playback.currentSong;
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
          fit: StackFit.expand,
          children: [
            // UI content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final artSize = (constraints.maxWidth * 0.58).clamp(
                    0.0,
                    280.0,
                  );
                  return Column(
                    children: [
                      _buildTopBar(context, ref, sleepTimer),
                      // Add visualizer exactly as in the mockup
                      SizedBox(
                        height: 50,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: _VisualizerRowWidget(),
                        ),
                      ),
                      const Spacer(),
                      _buildAlbumArtSection(
                        context,
                        ref,
                        song,
                        artSize,
                        playback.isPlaying,
                      ),
                      const SizedBox(height: 32),
                      _buildSongInfo(context, song),
                      const Spacer(),
                      _buildControlPanel(context, ref, playback),
                      const SizedBox(height: 16),
                      _buildBottomActionStrip(context, ref, song, favorites),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    SleepTimerState sleepTimer,
  ) {
    final colors = NenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            color: colors.textPrimary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
          if (sleepTimer.isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatDuration(sleepTimer.remaining ?? Duration.zero),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: colors.textPrimary,
              size: 28,
            ),
            color: colors.surfaceElevated,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'queue', child: Text('View Queue')),
              const PopupMenuItem(value: 'equalizer', child: Text('Equalizer')),
              PopupMenuItem(
                value: 'sleep',
                child: Text(
                  sleepTimer.isActive ? 'Cancel Sleep Timer' : 'Sleep Timer',
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'queue') {
                _showQueueSheet(context);
              } else if (value == 'equalizer') {
                Navigator.push(
                  context,
                  NenSlideRoute(builder: (_) => const EqualizerScreen()),
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
    );
  }

  // ── Album art section ─────────────────────────────────────────────

  Widget _buildAlbumArtSection(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    double artSize,
    bool isPlaying,
  ) {
    final colors = NenTheme.of(context);
    final artAsync = song != null
        ? ref.watch(largeAlbumArtProvider(song.id))
        : null;

    // We increase width slightly to make room for the vinyl sticking out.
    final containerWidth = artSize + (artSize * 0.3);

    return _AnimatedAccentBuilder(
      songId: song?.id,
      builder: (accentColor) {
        final artContent =
            artAsync?.when(
              data: (art) => _buildAlbumArtImage(art, accentColor, colors),
              loading: () => _defaultArtPlaceholder(accentColor),
              error: (e, s) => _defaultArtPlaceholder(accentColor),
            ) ??
            _defaultArtPlaceholder(accentColor);

        return Hero(
          tag: _kHeroTag,
          child: SizedBox(
            width: containerWidth,
            height: artSize,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Vinyl disc layer — rotates independently, offset to the right
                Positioned(
                  right: 0,
                  child: _VinylDisc(
                    size: artSize * 0.96,
                    isPlaying: isPlaying,
                    accentColor: accentColor,
                  ),
                ),
                // Album art — rounded rectangle blocking the left side of the disc
                Positioned(
                  left: 0,
                  child: Container(
                    width: artSize,
                    height: artSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          offset: const Offset(4, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: artContent,
                    ),
                  ),
                ),
              ],
            ),
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
    return _defaultArtPlaceholder(accentColor);
  }

  Widget _defaultArtPlaceholder(Color accentColor) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.4),
            accentColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80,
          color: accentColor.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  // ── Song info ─────────────────────────────────────────────────────

  Widget _buildSongInfo(BuildContext context, Song? song) {
    final colors = NenTheme.of(context);
    final title = _getDisplayTitle(song);
    final artist = _getDisplayArtist(song);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OverflowMarqueeText(
            text: title,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          OverflowMarqueeText(
            text: artist.isEmpty ? '\u200B' : artist,
            textAlign: TextAlign.start,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Control panel ─────────────────────────────────────────────────

  Widget _buildControlPanel(
    BuildContext context,
    WidgetRef ref,
    PlaybackState playback,
  ) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressBar(context, ref, playback),
            const SizedBox(height: 24),
            _buildControls(context, ref, playback),
          ],
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
        : (playback.currentSong?.duration ?? const Duration(seconds: 1));

    final progressFraction = (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Vertical bars representation
          SizedBox(
            height: 32,
            child: CustomPaint(
              size: const Size(double.infinity, 32),
              painter: _DenseProgressBarPainter(
                progress: progressFraction,
                activeColor: colors.textSecondary,
                inactiveColor: colors.textTertiary.withValues(alpha: 0.2),
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: colors.textPrimary,
              inactiveTrackColor: colors.textSecondary.withValues(alpha: 0.2),
              thumbColor: colors.textPrimary,
              trackShape: const RoundedRectSliderTrackShape(),
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
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
    final isShuffleOn = playback.shuffleMode == ShuffleMode.on;
    final isRepeatActive = playback.repeatMode != NenRepeatMode.off;
    final isRepeatOne = playback.repeatMode == NenRepeatMode.one;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              size: 26,
              color: isShuffleOn ? colors.textPrimary : colors.textTertiary,
            ),
            onPressed: () =>
                ref.read(playbackProvider.notifier).toggleShuffle(),
            tooltip: 'Shuffle',
          ),
          IconButton(
            icon: Icon(
              Icons.skip_previous_rounded,
              color: colors.textPrimary,
              size: 36,
            ),
            onPressed: () => ref.read(playbackProvider.notifier).previous(),
            tooltip: 'Previous',
          ),
          // Glowing Play/Pause button
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                playback.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
              onPressed: () =>
                  ref.read(playbackProvider.notifier).togglePlayPause(),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.skip_next_rounded,
              color: colors.textPrimary,
              size: 36,
            ),
            onPressed: () => ref.read(playbackProvider.notifier).next(),
            tooltip: 'Next',
          ),
          IconButton(
            icon: Icon(
              isRepeatOne ? Icons.repeat_one_rounded : Icons.repeat_rounded,
              size: 26,
              color: isRepeatActive ? colors.textPrimary : colors.textTertiary,
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

  // ── Bottom action strip ───────────────────────────────────────────

  Widget _buildBottomActionStrip(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    Set<int> favorites,
  ) {
    final colors = NenTheme.of(context);
    final isFavorite = song != null && favorites.contains(song.id);
    final isLyrics = ref.watch(lyricsVisibleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Heart
            IconButton(
              tooltip: isFavorite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              onPressed: song == null
                  ? null
                  : () => ref.read(favoritesProvider.notifier).toggle(song.id),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                  child: child,
                ),
                child: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  key: ValueKey(isFavorite),
                  color: isFavorite ? Colors.redAccent : Colors.white,
                  size: 24,
                ),
              ),
            ),
            // Add to playlist
            IconButton(
              tooltip: 'Add to playlist',
              onPressed: song == null
                  ? null
                  : () => showSongActionsSheet(context, ref, song),
              icon: Icon(
                Icons.playlist_add_rounded,
                color: colors.textPrimary,
                size: 26,
              ),
            ),
            // Share
            IconButton(
              tooltip: 'Share',
              onPressed: song == null
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sharing "${song.title}"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
              icon: Icon(
                Icons.share_rounded,
                color: colors.textPrimary,
                size: 22,
              ),
            ),
            // Lyrics toggle
            IconButton(
              tooltip: isLyrics ? 'Hide lyrics' : 'Show lyrics',
              onPressed: () =>
                  ref.read(lyricsVisibleProvider.notifier).state = !isLyrics,
              icon: Icon(
                Icons.lyrics_rounded,
                color: isLyrics
                    ? Theme.of(context).colorScheme.primary
                    : colors.textPrimary,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom sheets ─────────────────────────────────────────────────

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
                final queue = ref.watch(
                  playbackProvider.select((s) => s.queue),
                );
                final queueIndex = ref.watch(
                  playbackProvider.select((s) => s.queueIndex),
                );
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
                            '${queue.length} songs',
                            style: TextStyle(
                              color: sheetColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: queue.length <= 1
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
                        itemCount: queue.length,
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(playbackProvider.notifier)
                              .reorderQueue(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final queuedSong = queue[index];
                          final isCurrent = index == queueIndex;
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

  static const _sleepTimerDurations = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

  void _showSleepTimerPicker(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
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
                  ..._sleepTimerDurations.map((duration) {
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
                          message:
                              'Sleep timer set for ${duration.inMinutes} min',
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
                          message:
                              'Sleep timer set for ${duration.inMinutes} min',
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
            ),
          ),
        );
      },
    );
  }

  Future<Duration?> _showCustomSleepDurationDialog(BuildContext context) async {
    final controller = TextEditingController();
    final colors = NenTheme.of(context);

    try {
      return await showDialog<Duration>(
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
    } finally {
      controller.dispose();
    }
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

  // ── Helpers ───────────────────────────────────────────────────────

  static String _getDisplayTitle(Song? song) {
    if (song == null) return 'No Song';
    final t = song.title.trim();
    if (t.isNotEmpty && t != '<unknown>') {
      return _looksLikeFilename(t, song.filePath) ? _parseFilenameTitle(t) : t;
    }
    return _parseFilenameTitle(song.filePath);
  }

  static String _getDisplayArtist(Song? song) {
    if (song == null) return '';
    final a = song.artist.trim();
    if (a.isEmpty || a == '<unknown>') return 'Unknown Artist';
    return a;
  }

  /// Strip extension, replace _ and - with spaces, title-case each word.
  static String _parseFilenameTitle(String filePath) {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final noExt = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    return noExt
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static bool _looksLikeFilename(String value, String filePath) {
    if (value.contains('/') || value.contains('\\')) return true;
    if (value.contains('_')) return true;
    if (RegExp(
      r'\.(mp3|m4a|flac|wav|ogg|aac)$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }

    final basename = filePath.split(RegExp(r'[\\/]')).last;
    return basename.isNotEmpty && value.toLowerCase() == basename.toLowerCase();
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

// ── Animated accent color builder ────────────────────────────────────

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
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, accentColor, _) {
        return builder(accentColor ?? NenTheme.defaultAccent);
      },
    );
  }
}

// ── Active icon button (filled background when active) ────────────────

class _ActiveIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final String tooltip;
  final VoidCallback onPressed;
  const _ActiveIconButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: 22,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}

// ── Pulsing play/pause button ─────────────────────────────────────────

class _PulsingPlayButton extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;
  final VoidCallback onPressed;

  const _PulsingPlayButton({
    required this.isPlaying,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  State<_PulsingPlayButton> createState() => _PulsingPlayButtonState();
}

class _PulsingPlayButtonState extends State<_PulsingPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    if (widget.isPlaying) _pulseCtrl.repeat();
  }

  @override
  void didUpdateWidget(_PulsingPlayButton old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _pulseCtrl.repeat();
      } else {
        _pulseCtrl
          ..stop()
          ..reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing ring — only drawn while playing
        if (widget.isPlaying)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseScale.value,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.accentColor.withValues(
                        alpha: _pulseOpacity.value,
                      ),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        NeuPlaybackButton(
          icon: Icons.play_arrow_rounded,
          size: 68,
          isPrimary: true,
          animatePlayPause: true,
          isPlaying: widget.isPlaying,
          onPressed: widget.onPressed,
        ),
      ],
    );
  }
}

// ── Vinyl disc widget ─────────────────────────────────────────────────

class _VinylDisc extends StatelessWidget {
  final double size;
  final bool isPlaying;
  final Color accentColor;

  const _VinylDisc({
    required this.size,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return _RotatingAlbumArt(
      isPlaying: isPlaying,
      child: CustomPaint(
        size: Size(size, size),
        painter: _VinylPainter(accentColor: accentColor),
      ),
    );
  }
}

// ── Vinyl groove painter ──────────────────────────────────────────────

class _VinylPainter extends CustomPainter {
  final Color accentColor;

  const _VinylPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Base disc — very dark
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF121212));

    // Concentric groove rings (subtle shimmer)
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (int i = 2; i <= 18; i++) {
      final r = radius * (0.92 - i * 0.025);
      if (r < radius * 0.35) break;
      groovePaint.color = Colors.white.withValues(alpha: 0.04 + (i % 3) * 0.01);
      canvas.drawCircle(center, r, groovePaint);
    }

    // Accent ring at the label boundary
    canvas.drawCircle(
      center,
      radius * 0.40,
      Paint()
        ..color = accentColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Label area — slightly lighter dark circle
    canvas.drawCircle(
      center,
      radius * 0.36,
      Paint()..color = const Color(0xFF1E1E1E),
    );

    // Center spindle hole
    canvas.drawCircle(
      center,
      radius * 0.04,
      Paint()..color = const Color(0xFF0A0A0A),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.accentColor != accentColor;
}

// ── Rotating album art ────────────────────────────────────────────────

class _RotatingAlbumArt extends StatefulWidget {
  final bool isPlaying;
  final Widget child;

  const _RotatingAlbumArt({required this.isPlaying, required this.child});

  @override
  State<_RotatingAlbumArt> createState() => _RotatingAlbumArtState();
}

class _RotatingAlbumArtState extends State<_RotatingAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_RotatingAlbumArt old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _ctrl, child: widget.child);
  }
}

// ── Audio-reactive visualizer widget ─────────────────────────────────

class _VisualizerWidget extends ConsumerStatefulWidget {
  final Color color;

  const _VisualizerWidget({required this.color});

  @override
  ConsumerState<_VisualizerWidget> createState() => _VisualizerWidgetState();
}

class _VisualizerWidgetState extends ConsumerState<_VisualizerWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animController;
  final _barHeights = List<double>.filled(_kBarCount, 0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_onFrame);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _animController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (ref.read(playbackProvider).isPlaying) {
        _animController.repeat();
      }
    }
  }

  void _onFrame() {
    if (!mounted) return;
    _driveVisualizerHeights(
      ref: ref,
      currentHeights: _barHeights,
      maxHeight: 20,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(playbackProvider.select((s) => s.isPlaying));
    if (playing) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else if (_animController.isAnimating) {
      _animController.stop();
    }
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _BarPainter(barHeights: _barHeights, color: widget.color),
          ),
        );
      },
    );
  }
}

// ── Bar CustomPainter ─────────────────────────────────────────────────

class _BarPainter extends CustomPainter {
  final List<double> barHeights;
  final Color color;

  const _BarPainter({required this.barHeights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final n = barHeights.length;
    if (n == 0) return;

    final totalBarWidth = size.width * 0.6;
    final barWidth = totalBarWidth / (n * 2 - 1);
    final gap = barWidth;
    final startX = (size.width - totalBarWidth) / 2;
    final centerY = size.height / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final h = barHeights[i].clamp(0.0, centerY);
      if (h < 1.0) continue;

      final x = startX + i * (barWidth + gap);
      const radius = Radius.circular(4);

      // Top bar (extends upward from center)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - h, barWidth, h),
          radius,
        ),
        paint,
      );

      // Bottom bar (mirror, extends downward from center)
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, centerY, barWidth, h), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}

// ── Dense Progress Bar Painter ────────────────────────────────────────

class _DenseProgressBarPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _DenseProgressBarPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = 2.0;
    final gap = 2.0;
    final totalBars = (size.width / (barWidth + gap)).floor();
    final activeBars = (totalBars * progress).floor();

    for (int i = 0; i < totalBars; i++) {
      final x = i * (barWidth + gap);
      // Optional: slight height variance based on i, but mockup shows flat
      final h = size.height;
      final paint = Paint()
        ..color = i < activeBars ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, barWidth, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DenseProgressBarPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}

// ── Mini Row Visualizer for Top Header ────────────────────────────────
class _VisualizerRowWidget extends ConsumerStatefulWidget {
  const _VisualizerRowWidget();

  @override
  ConsumerState<_VisualizerRowWidget> createState() =>
      _VisualizerRowWidgetState();
}

class _VisualizerRowWidgetState extends ConsumerState<_VisualizerRowWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animController;
  final _barHeights = List<double>.filled(40, 0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_onFrame);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _animController.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (ref.read(playbackProvider).isPlaying) {
        _animController.repeat();
      }
    }
  }

  void _onFrame() {
    if (!mounted) return;
    _driveVisualizerHeights(
      ref: ref,
      currentHeights: _barHeights,
      maxHeight: 16,
      floorHeight: 2,
      mirrorFromCenter: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(playbackProvider.select((s) => s.isPlaying));
    if (playing) {
      if (!_animController.isAnimating) {
        _animController.repeat();
      }
    } else if (_animController.isAnimating) {
      _animController.stop();
    }
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _RowBarPainter(
              barHeights: _barHeights,
              color: Theme.of(
                context,
              ).colorScheme.primary, // Dynamic theme color
            ),
          ),
        );
      },
    );
  }
}

class _RowBarPainter extends CustomPainter {
  final List<double> barHeights;
  final Color color;

  const _RowBarPainter({required this.barHeights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final n = barHeights.length;
    if (n == 0) return;

    final barWidth = 3.0;
    final gap = ((size.width - (n * barWidth)) / (n > 1 ? n - 1 : 1))
        .clamp(0.0, double.infinity)
        .toDouble();
    final centerY = size.height / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (int i = 0; i < n; i++) {
      final h = barHeights[i].clamp(2.0, size.height).toDouble();
      final x = i * (barWidth + gap) + (barWidth / 2);

      canvas.drawLine(
        Offset(x, centerY - (h / 2)),
        Offset(x, centerY + (h / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RowBarPainter old) => true;
}

void _driveVisualizerHeights({
  required WidgetRef ref,
  required List<double> currentHeights,
  required double maxHeight,
  double floorHeight = 0,
  bool mirrorFromCenter = false,
}) {
  final isPlaying = ref.read(playbackProvider).isPlaying;
  if (!isPlaying) {
    for (int i = 0; i < currentHeights.length; i++) {
      currentHeights[i] = lerpDouble(currentHeights[i], floorHeight, 0.18)!;
    }
    return;
  }

  final audio = ref.read(audioRepositoryProvider);
  if (!audio.isInitialized) {
    for (int i = 0; i < currentHeights.length; i++) {
      currentHeights[i] = lerpDouble(currentHeights[i], floorHeight, 0.18)!;
    }
    return;
  }

  final values = FFTProcessor.process(audio.getFFTData()).toList();
  if (values.every((value) => value <= 0.001)) {
    for (int i = 0; i < currentHeights.length; i++) {
      currentHeights[i] = lerpDouble(currentHeights[i], floorHeight, 0.18)!;
    }
    return;
  }

  for (int i = 0; i < currentHeights.length; i++) {
    final sample = _sampleBandValue(
      values,
      index: i,
      total: currentHeights.length,
      mirrorFromCenter: mirrorFromCenter,
    );
    final target = floorHeight + (sample * maxHeight);
    currentHeights[i] = lerpDouble(currentHeights[i], target, 0.32)!;
  }
}

double _sampleBandValue(
  List<double> values, {
  required int index,
  required int total,
  required bool mirrorFromCenter,
}) {
  if (values.isEmpty) return 0;
  if (values.length == 1 || total <= 1) return values.first;

  final t = mirrorFromCenter
      ? _distanceFromCenter(index, total)
      : index / (total - 1);
  final rawIndex = t * (values.length - 1);
  final lower = rawIndex.floor().clamp(0, values.length - 1);
  final upper = rawIndex.ceil().clamp(0, values.length - 1);
  final fraction = rawIndex - lower;

  return (values[lower] * (1 - fraction)) + (values[upper] * fraction);
}

double _distanceFromCenter(int index, int total) {
  if (total <= 1) return 0;
  final center = (total - 1) / 2;
  if (center == 0) return 0;
  return ((index - center).abs() / center).clamp(0.0, 1.0);
}
