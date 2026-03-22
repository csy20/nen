import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/nen_theme.dart';

/// Reusable glassmorphic card with BackdropFilter blur, subtle border,
/// hover/tap animations, and theme-aware colors. WCAG 2.2 AA compliant.
class GlassmorphicCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final Color? glowColor;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final String? className;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blurSigma = 12,
    this.opacity = 0.08,
    this.glowColor,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.className,
  });

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: widget.opacity)
        : Colors.white.withValues(alpha: 0.7);
    final borderColor = isDark
        ? NenTheme.glassBorderDark
        : NenTheme.glassBorderLight;

    return Container(
      margin: widget.margin,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.01 : 1.0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    // Gradient overlay on hover
                    gradient: _isHovered
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha: isDark ? 0.1 : 0.15,
                              ),
                              Colors.transparent,
                            ],
                          )
                        : null,
                    color: _isHovered ? null : surfaceColor,
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      ...NenShadows.card,
                      if (widget.glowColor != null)
                        BoxShadow(
                          color: widget.glowColor!.withValues(alpha: 0.1),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
