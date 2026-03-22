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
    final isVisualizerMode = ref.watch(isVisualizerModeProvider);

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
            // 1. Animated palette gradient background (transitions on song change)
            Positioned.fill(
              child: _AnimatedAccentBuilder(
                songId: song?.id,
                builder: (accentColor) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor.withValues(alpha: 0.55),
                        accentColor.withValues(alpha: 0.2),
                        colors.background,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 2. Full-screen FFT shader visualizer (on top of palette gradient)
            Positioned.fill(
              child: _AnimatedAccentBuilder(
                songId: song?.id,
                builder: (accentColor) =>
                    AudioVisualizerWidget(accentColor: accentColor),
              ),
            ),
            // 3. Dark overlay for readability
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
            ),
            // 4. Bottom gradient fade to background color
            Positioned.fill(
              child: DecoratedBox(
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
            // 5. UI content — LayoutBuilder distributes space without fragile Spacer math
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final artSize =
                      (constraints.maxWidth * 0.58).clamp(0.0, 280.0);
                  return Column(
                    children: [
                      _buildTopBar(
                        context,
                        ref,
                        song,
                        favorites,
                        sleepTimer,
                        isVisualizerMode: isVisualizerMode,
                      ),
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: _buildAlbumArtSection(
                            context,
                            ref,
                            song,
                            artSize,
                            playback.isPlaying,
                            isVisualizerMode,
                          ),
                        ),
                      ),
                      _buildSongInfo(context, song),
                      const SizedBox(height: 16),
                      _buildControlPanel(context, ref, playback),
                      const SizedBox(height: 8),
                      _buildBottomActionStrip(context, ref, song, favorites),
                      const SizedBox(height: 12),
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
    Song? song,
    Set<int> favorites,
    SleepTimerState sleepTimer, {
    bool isVisualizerMode = false,
  }) {
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
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.16),
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
                          tooltip: 'Favorite',
                          onPressed: () => ref
                              .read(favoritesProvider.notifier)
                              .toggle(song.id),
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
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
                              color: isFavorite
                                  ? Colors.redAccent
                                  : colors.textPrimary,
                              size: 22,
                            ),
                          ),
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
                          PopupMenuItem(
                            value: 'visualizer',
                            child: Text(
                              isVisualizerMode
                                  ? 'Normal View'
                                  : 'Visualizer Bars',
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
                          } else if (value == 'visualizer') {
                            ref.read(isVisualizerModeProvider.notifier).state =
                                !isVisualizerMode;
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

  // ── Album art section ─────────────────────────────────────────────

  Widget _buildAlbumArtSection(
    BuildContext context,
    WidgetRef ref,
    Song? song,
    double artSize,
    bool isPlaying,
    bool isVisualizerMode,
  ) {
    final colors = NenTheme.of(context);
    final artAsync = song != null ? ref.watch(albumArtProvider(song.id)) : null;

    return _AnimatedAccentBuilder(
      songId: song?.id,
      builder: (accentColor) {
        final artContent = artAsync?.when(
              data: (art) => _buildAlbumArtImage(art, accentColor, colors),
              loading: () => _defaultArtPlaceholder(accentColor),
              error: (e, s) => _defaultArtPlaceholder(accentColor),
            ) ??
            _defaultArtPlaceholder(accentColor);

        return Hero(
          tag: _kHeroTag,
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vinyl disc layer — rotates independently beneath the art
                _VinylDisc(
                  size: artSize,
                  isPlaying: isPlaying,
                  accentColor: accentColor,
                ),
                // Album art — static circle inset over the disc
                Container(
                  width: artSize * 0.78,
                  height: artSize * 0.78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: artContent),
                ),
                // Visualizer bars overlay (optional mode)
                if (isVisualizerMode)
                  Positioned.fill(
                    child: ClipOval(
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 400),
                        child: _VisualizerWidget(color: accentColor),
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
    final isUnknownArtist = artist == 'Unknown Artist';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 28,
            child: OverflowMarqueeText(
              text: title,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 20,
            child: OverflowMarqueeText(
              text: artist.isEmpty ? '\u200B' : artist,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: isUnknownArtist
                    ? colors.textSecondary
                    : colors.textPrimary.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
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
          _AnimatedAccentBuilder(
            songId: playback.currentSong?.id,
            builder: (accentColor) => SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.2),
                // Larger tap target so the user can seek by tapping anywhere
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0, duration.inMilliseconds.toDouble()),
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  ref
                      .read(playbackProvider.notifier)
                      .seek(Duration(milliseconds: value.toInt()));
                },
              ),
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
    final accent = Theme.of(context).colorScheme.primary;
    final isShuffleOn = playback.shuffleMode == ShuffleMode.on;
    final isRepeatActive = playback.repeatMode != NenRepeatMode.off;
    final isRepeatOne = playback.repeatMode == NenRepeatMode.one;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          _ActiveIconButton(
            icon: Icons.shuffle_rounded,
            isActive: isShuffleOn,
            activeColor: accent,
            inactiveColor: colors.textTertiary,
            tooltip: 'Shuffle',
            onPressed: () =>
                ref.read(playbackProvider.notifier).toggleShuffle(),
          ),
          // Previous — plain IconButton (fast to scan, focus stays on primary)
          Semantics(
            label: 'Previous track',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.skip_previous_rounded,
                color: colors.textPrimary,
                size: 36,
              ),
              onPressed: () => ref.read(playbackProvider.notifier).previous(),
              tooltip: 'Previous',
            ),
          ),
          // Play / Pause — primary button with pulsing ring while playing
          _AnimatedAccentBuilder(
            songId: playback.currentSong?.id,
            builder: (accentColor) => _PulsingPlayButton(
              isPlaying: playback.isPlaying,
              accentColor: accentColor,
              onPressed: () =>
                  ref.read(playbackProvider.notifier).togglePlayPause(),
            ),
          ),
          // Next — plain IconButton
          Semantics(
            label: 'Next track',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.skip_next_rounded,
                color: colors.textPrimary,
                size: 36,
              ),
              onPressed: () => ref.read(playbackProvider.notifier).next(),
              tooltip: 'Next',
            ),
          ),
          // Repeat
          _ActiveIconButton(
            icon: isRepeatOne
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            isActive: isRepeatActive,
            activeColor: accent,
            inactiveColor: colors.textTertiary,
            tooltip: 'Repeat',
            onPressed: () => ref.read(playbackProvider.notifier).cycleRepeat(),
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
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Heart
          IconButton(
            tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
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
                color: isFavorite ? Colors.redAccent : colors.textSecondary,
                size: 22,
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
              color: colors.textSecondary,
              size: 22,
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
              color: colors.textSecondary,
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
                  : colors.textSecondary,
              size: 22,
            ),
          ),
        ],
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
    const durations = [
      Duration(minutes: 15),
      Duration(minutes: 30),
      Duration(minutes: 45),
      Duration(minutes: 60),
      Duration(minutes: 90),
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

  // ── Helpers ───────────────────────────────────────────────────────

  static String _getDisplayTitle(Song? song) {
    if (song == null) return 'No Song';
    final t = song.title.trim();
    if (t.isNotEmpty && t != '<unknown>') return t;
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
    final filename = filePath.split('/').last;
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
        icon: Icon(icon, color: isActive ? activeColor : inactiveColor, size: 22),
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
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
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
                      color: widget.accentColor
                          .withValues(alpha: _pulseOpacity.value),
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
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF121212),
    );

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  final _barHeights = List<double>.filled(_kBarCount, 0.0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )
      ..addListener(_onFrame)
      ..repeat();
  }

  void _onFrame() {
    if (!mounted) return;

    final isPlaying = ref.read(playbackProvider).isPlaying;

    if (!isPlaying) {
      // Decay bars to zero when paused
      for (int i = 0; i < _barHeights.length; i++) {
        _barHeights[i] = lerpDouble(_barHeights[i], 0.0, 0.15)!;
      }
      return;
    }

    // Feed real FFT frequency band data into the bar heights
    final bands = ref.read(frequencyBandsProvider);
    final vals = bands.toList(); // 7 normalized band values [0.0..1.0]

    for (int i = 0; i < _barHeights.length; i++) {
      // Interpolate across the 7 bands to fill _kBarCount bars
      final t = i / (_barHeights.length - 1);
      final rawIdx = t * (vals.length - 1);
      final lo = rawIdx.floor().clamp(0, vals.length - 1);
      final hi = rawIdx.ceil().clamp(0, vals.length - 1);
      final frac = rawIdx - lo;
      final bandValue = vals[lo] * (1 - frac) + vals[hi] * frac;

      final target = bandValue * 72.0; // scale normalized value → pixel height
      _barHeights[i] = lerpDouble(_barHeights[i], target, 0.3)!;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _BarPainter(
              barHeights: _barHeights,
              color: widget.color,
            ),
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
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, barWidth, h),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => true;
}
