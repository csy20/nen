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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final style = defaultTextStyle.merge(widget.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();

        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : textPainter.width;

        if (textPainter.width <= maxWidth) {
          _controller.stop();
          _controller.value = 0;
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: style,
          );
        }

        if (!_controller.isAnimating) {
          _controller.repeat();
        }

        final travel = textPainter.width + widget.gap;
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = -travel * _controller.value;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.text, maxLines: 1, style: style),
                SizedBox(width: widget.gap),
                Text(widget.text, maxLines: 1, style: style),
              ],
            ),
          ),
        );
      },
    );
  }
}
