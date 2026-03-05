import 'dart:ui';
import 'package:flutter/material.dart';

/// Reusable glassmorphic card with BackdropFilter blur, subtle border,
/// and optional accent glow. Use across library, album detail, and playlist screens.
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final Color? glowColor;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.blurSigma = 20,
    this.opacity = 0.08,
    this.glowColor,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
              boxShadow: glowColor != null
                  ? [
                      BoxShadow(
                        color: glowColor!.withValues(alpha: 0.1),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
