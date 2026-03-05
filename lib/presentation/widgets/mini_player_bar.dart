import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Persistent mini-player bar with glassmorphic blur, animated icon morphs,
/// and physics-based micro-interactions.
class MiniPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;

  const MiniPlayerBar({super.key, required this.onTap});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar>
    with TickerProviderStateMixin {
  late final AnimationController _slideIn;
  late final Animation<Offset> _slideAnimation;
  late final AnimationController _tapBounce;
  late final Animation<double> _bounceScale;

  @override
  void initState() {
    super.initState();

    // Slide-in animation
    _slideIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideIn,
      curve: Curves.easeOutCubic,
    ));
    _slideIn.forward();

    // Physics-based tap bounce
    _tapBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _bounceScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _tapBounce, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _slideIn.dispose();
    _tapBounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final song = playback.currentSong;

    if (song == null) return const SizedBox.shrink();

    final progress = playback.duration > Duration.zero
        ? playback.position.inMilliseconds / playback.duration.inMilliseconds
        : 0.0;

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _bounceScale,
        builder: (context, child) => Transform.scale(
          scale: _bounceScale.value,
          child: child,
        ),
        child: GestureDetector(
          onTapDown: (_) => _tapBounce.forward(),
          onTapUp: (_) {
            _tapBounce.reverse();
            widget.onTap();
          },
          onTapCancel: () => _tapBounce.reverse(),
          child: Container(
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Progress indicator at top of bar
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            // Album art thumbnail
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: NenTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Song info
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NenTheme.textPrimary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: NenTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Play/pause with animated icon morph
                            _AnimatedPlayPauseButton(
                              isPlaying: playback.isPlaying,
                              onPressed: () =>
                                  ref.read(playbackProvider.notifier).togglePlayPause(),
                            ),
                            // Next
                            IconButton(
                              icon: const Icon(
                                Icons.skip_next_rounded,
                                color: NenTheme.textSecondary,
                                size: 24,
                              ),
                              onPressed: () =>
                                  ref.read(playbackProvider.notifier).next(),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated play/pause button with smooth icon morphing.
class _AnimatedPlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _AnimatedPlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<_AnimatedPlayPauseButton> createState() =>
      _AnimatedPlayPauseButtonState();
}

class _AnimatedPlayPauseButtonState extends State<_AnimatedPlayPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_AnimatedPlayPauseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 30,
      onPressed: widget.onPressed,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: _controller,
        color: NenTheme.textPrimary,
        size: 30,
      ),
    );
  }
}
