import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Neumorphic playback control button with physics-based spring animations
/// and smooth icon morphing for play/pause.
class NeuPlaybackButton extends ConsumerStatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool isPrimary;

  /// If true, renders an AnimatedIcon for play/pause morphing instead of
  /// a static icon. [isPlaying] must be provided when this is true.
  final bool animatePlayPause;
  final bool isPlaying;

  const NeuPlaybackButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.isPrimary = false,
    this.animatePlayPause = false,
    this.isPlaying = false,
  });

  @override
  ConsumerState<NeuPlaybackButton> createState() => _NeuPlaybackButtonState();
}

class _NeuPlaybackButtonState extends ConsumerState<NeuPlaybackButton>
    with TickerProviderStateMixin {
  bool _isPressed = false;

  // Physics-based spring animation
  late AnimationController _springController;
  late Animation<double> _springScale;

  // Play/pause icon morph controller
  late AnimationController _iconMorphController;

  @override
  void initState() {
    super.initState();

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _springScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _springController,
        curve: const _SpringCurve(),
      ),
    );

    _iconMorphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(NeuPlaybackButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animatePlayPause && widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying
          ? _iconMorphController.forward()
          : _iconMorphController.reverse();
    }
  }

  @override
  void dispose() {
    _springController.dispose();
    _iconMorphController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _springController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _springController.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _springController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final useAnimation = !settings.reduceMotion;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _springScale,
        builder: (context, child) {
          return Transform.scale(
            scale: useAnimation ? _springScale.value : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.size,
              height: widget.size,
              decoration: neumorphicDecoration(
                isPressed: _isPressed,
                baseColor: widget.isPrimary
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.15)
                    : NenTheme.surfaceDark,
              ),
              child: Center(
                child: widget.animatePlayPause
                    ? AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _iconMorphController,
                        color: widget.isPrimary
                            ? Theme.of(context).colorScheme.primary
                            : NenTheme.textPrimary,
                        size: widget.size * 0.5,
                      )
                    : Icon(
                        widget.icon,
                        color: widget.isPrimary
                            ? Theme.of(context).colorScheme.primary
                            : NenTheme.textPrimary,
                        size: widget.size * 0.5,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom spring curve for physics-based button animations.
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 300, damping: 14),
      0, 1, 0,
    );
    return simulation.x(t);
  }
}
