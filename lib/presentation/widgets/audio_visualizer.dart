import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// The real-time audio visualizer widget using a custom GLSL fragment shader.
/// Wrapped in a RepaintBoundary to isolate repaints from the rest of the tree.
class AudioVisualizerWidget extends ConsumerStatefulWidget {
  final Color accentColor;

  const AudioVisualizerWidget({
    super.key,
    this.accentColor = NenTheme.defaultAccent,
  });

  @override
  ConsumerState<AudioVisualizerWidget> createState() =>
      _AudioVisualizerWidgetState();
}

class _AudioVisualizerWidgetState extends ConsumerState<AudioVisualizerWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _elapsed = 0.0;
  ui.FragmentShader? _shader;
  bool _shaderLoaded = false;
  FrequencyBands _bands = FrequencyBands.zero;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/visualizer.frag');
      setState(() {
        _shader = program.fragmentShader();
        _shaderLoaded = true;
      });
    } catch (e) {
      debugPrint('Shader load failed: $e');
    }
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed.inMicroseconds / 1000000.0;

    // Poll FFT data from the audio engine
    final audio = ref.read(audioRepositoryProvider);
    if (audio.isInitialized) {
      final fftData = audio.getFFTData();
      _bands = _processBands(fftData);
    }

    // Trigger repaint
    if (mounted) setState(() {});
  }

  FrequencyBands _processBands(List<double> fftData) {
    // Inline processing to avoid provider overhead on every frame
    if (fftData.isEmpty) return FrequencyBands.zero;
    double avg(int from, int to) {
      final end = to.clamp(0, fftData.length);
      final start = from.clamp(0, fftData.length);
      if (start >= end) return 0.0;
      double sum = 0.0;
      for (int i = start; i < end; i++) {
        sum += fftData[i].abs();
      }
      return ((sum / (end - start)) * 2.5).clamp(0.0, 1.0);
    }

    return FrequencyBands(
      subBass: avg(0, 1),
      bass: avg(1, 3),
      lowMid: avg(3, 6),
      mid: avg(6, 24),
      upperMid: avg(24, 47),
      presence: avg(47, 70),
      brilliance: avg(70, fftData.length),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (!_shaderLoaded || _shader == null) {
      // Fallback: simple animated gradient
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              widget.accentColor.withValues(alpha: 0.3),
              NenTheme.trueBlack,
            ],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _VisualizerPainter(
          shader: _shader!,
          elapsed: _elapsed,
          bands: _bands,
          accentColor: widget.accentColor,
          reduceMotion: settings.reduceMotion ? 1.0 : 0.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double elapsed;
  final FrequencyBands bands;
  final Color accentColor;
  final double reduceMotion;

  _VisualizerPainter({
    required this.shader,
    required this.elapsed,
    required this.bands,
    required this.accentColor,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set uniforms
    shader.setFloat(0, size.width);   // uSize.x
    shader.setFloat(1, size.height);  // uSize.y (packed as vec2 at location 0)

    // Note: Flutter's FragmentShader.setFloat uses sequential float indices
    // We remap to match our uniform layout
    shader.setFloat(2, elapsed);       // uTime

    shader.setFloat(3, bands.subBass);    // uSubBass
    shader.setFloat(4, bands.bass);       // uBass
    shader.setFloat(5, bands.lowMid);     // uLowMid
    shader.setFloat(6, bands.mid);        // uMid
    shader.setFloat(7, bands.upperMid);   // uUpperMid
    shader.setFloat(8, bands.presence);   // uPresence
    shader.setFloat(9, bands.brilliance); // uBrilliance

    shader.setFloat(10, accentColor.r); // uAccentColor.r
    shader.setFloat(11, accentColor.g); // uAccentColor.g
    shader.setFloat(12, accentColor.b); // uAccentColor.b

    shader.setFloat(13, reduceMotion);    // uReduceMotion

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_VisualizerPainter oldDelegate) => true;
}
