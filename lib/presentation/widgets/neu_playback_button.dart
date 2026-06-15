import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

class NeuPlaybackButton extends ConsumerStatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;
  final bool isPrimary;

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

  late AnimationController _springController;
  late Animation<double> _springScale;
  late AnimationController _iconMorphController;

  @override
  void initState() {
    super.initState();

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _springScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _springController, curve: const _SpringCurve()),
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
    final colors = NenTheme.of(context);
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

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
                    ? primaryColor.withValues(alpha: 0.15)
                    : colors.surface,
              ),
              child: Center(
                child: widget.animatePlayPause
                    ? AnimatedIcon(
                        icon: AnimatedIcons.play_pause,
                        progress: _iconMorphController,
                        color: widget.isPrimary
                            ? primaryColor
                            : colors.textPrimary,
                        size: widget.size * 0.5,
                      )
                    : Icon(
                        widget.icon,
                        color: widget.isPrimary
                            ? primaryColor
                            : colors.textPrimary,
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

class _SpringCurve extends Curve {
  const _SpringCurve();

  static final _simulation = SpringSimulation(
    const SpringDescription(mass: 1, stiffness: 300, damping: 14),
    0,
    1,
    0,
  );

  @override
  double transformInternal(double t) => _simulation.x(t);
}
