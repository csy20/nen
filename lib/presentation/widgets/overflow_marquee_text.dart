import 'package:flutter/material.dart';

class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration duration;
  final double gap;

  const OverflowMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.duration = const Duration(seconds: 8),
    this.gap = 36,
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Cache to avoid recreating TextPainter on every build.
  String? _cachedText;
  TextStyle? _cachedStyle;
  double _cachedNaturalWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.text != widget.text || oldWidget.gap != widget.gap) {
      _cachedText = null; // Invalidate cache on text change.
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _measureText(String text, TextStyle style, TextDirection direction) {
    if (text == _cachedText && style == _cachedStyle) {
      return _cachedNaturalWidth;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    _cachedText = text;
    _cachedStyle = style;
    _cachedNaturalWidth = painter.width;
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final style = defaultTextStyle.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite) {
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            textAlign: widget.textAlign,
            style: style,
          );
        }

        final naturalWidth = _measureText(
          widget.text,
          style,
          Directionality.of(context),
        );
        final maxWidth = constraints.maxWidth;
        final shouldMarquee = naturalWidth > maxWidth + 0.5;

        if (!shouldMarquee) {
          // Defer controller mutation out of the build phase.
          if (_controller.isAnimating || _controller.value != 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _controller
                  ..stop()
                  ..value = 0;
              }
            });
          }
          return SizedBox(
            width: maxWidth,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: widget.textAlign,
              style: style,
            ),
          );
        }

        if (!_controller.isAnimating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_controller.isAnimating) {
              _controller.repeat();
            }
          });
        }

        final travel = naturalWidth + widget.gap;
        return SizedBox(
          width: maxWidth,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = -travel * _controller.value;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: style,
                    ),
                    SizedBox(width: widget.gap),
                    Text(
                      widget.text,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: style,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
