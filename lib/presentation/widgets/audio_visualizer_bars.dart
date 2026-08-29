import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/playback_provider.dart';
import '../providers/settings_provider.dart';

/// Playing meter. Dart-only pulse — never Android Visualizer / FFT JNI.
class AudioVisualizerBars extends ConsumerStatefulWidget {
  const AudioVisualizerBars({
    super.key,
    this.barCount = 40,
    this.maxHeight = 16,
    this.floorHeight = 2,
    this.mirrorFromCenter = true,
    this.strokeWidth = 3,
  });

  final int barCount;
  final double maxHeight;
  final double floorHeight;
  final bool mirrorFromCenter;
  final double strokeWidth;

  @override
  ConsumerState<AudioVisualizerBars> createState() =>
      _AudioVisualizerBarsState();
}

class _AudioVisualizerBarsState extends ConsumerState<AudioVisualizerBars>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  late List<double> _barHeights;
  Duration _lastTick = Duration.zero;
  static const _minFrame = Duration(milliseconds: 33);

  @override
  void initState() {
    super.initState();
    _barHeights = List<double>.filled(widget.barCount, widget.floorHeight);
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(AudioVisualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.barCount != widget.barCount) {
      _barHeights = List<double>.filled(widget.barCount, widget.floorHeight);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed) {
      _syncTicker(ref.read(playbackProvider).isPlaying);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_lastTick != Duration.zero && elapsed - _lastTick < _minFrame) {
      return;
    }
    _lastTick = elapsed;
    _driveVisualizerHeights(
      ref: ref,
      currentHeights: _barHeights,
      maxHeight: widget.maxHeight,
      floorHeight: widget.floorHeight,
      mirrorFromCenter: widget.mirrorFromCenter,
    );
    setState(() {});
  }

  void _syncTicker(bool shouldRun) {
    if (shouldRun) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
      return;
    }
    if (_ticker.isActive) {
      _ticker.stop();
    }
    for (var i = 0; i < _barHeights.length; i++) {
      _barHeights[i] = widget.floorHeight;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ref.watch(playbackProvider.select((s) => s.isPlaying));
    final reduceMotion = ref.watch(
      settingsProvider.select((s) => s.reduceMotion),
    );
    final shouldRun =
        playing &&
        !reduceMotion &&
        !MediaQuery.disableAnimationsOf(context);
    if (shouldRun != _ticker.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncTicker(shouldRun);
      });
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RowBarPainter(
          barHeights: _barHeights,
          color: Theme.of(context).colorScheme.primary,
          strokeWidth: widget.strokeWidth,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RowBarPainter extends CustomPainter {
  final List<double> barHeights;
  final Color color;
  final double strokeWidth;

  const _RowBarPainter({
    required this.barHeights,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = barHeights.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;

    final barWidth = strokeWidth;
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
  bool shouldRepaint(_RowBarPainter old) {
    if (old.color != color || old.strokeWidth != strokeWidth) return true;
    if (old.barHeights.length != barHeights.length) return true;
    for (var i = 0; i < barHeights.length; i++) {
      if ((old.barHeights[i] - barHeights[i]).abs() > 0.15) return true;
    }
    return false;
  }
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
    _decay(currentHeights, floorHeight, 0.22);
    return;
  }

  final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
  final n = currentHeights.length;
  for (int i = 0; i < n; i++) {
    final phase = mirrorFromCenter
        ? _distanceFromCenter(i, n)
        : (n <= 1 ? 0.0 : i / (n - 1));
    final wave =
        0.22 +
        0.78 *
            (0.55 +
                0.45 *
                    math.sin(t * 3.4 + phase * 4.2) *
                    math.sin(t * 1.6 + i * 0.31));
    final target = floorHeight + wave.abs() * maxHeight;
    final current = currentHeights[i];
    final k = target > current ? 0.42 : 0.16;
    currentHeights[i] = lerpDouble(current, target, k)!;
  }
}

void _decay(List<double> heights, double floor, double t) {
  for (int i = 0; i < heights.length; i++) {
    heights[i] = lerpDouble(heights[i], floor, t)!;
  }
}

double _distanceFromCenter(int index, int total) {
  if (total <= 1) return 0;
  final center = (total - 1) / 2;
  if (center == 0) return 0;
  return ((index - center).abs() / center).clamp(0.0, 1.0);
}
