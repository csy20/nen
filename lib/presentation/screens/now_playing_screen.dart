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
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final song = playback.currentSong;
    final size = MediaQuery.of(context).size;

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
                _buildTopBar(context),

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

  Widget _buildTopBar(BuildContext context) {
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
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  color: NenTheme.textPrimary,
                  onPressed: () {},
                  tooltip: 'Options',
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
