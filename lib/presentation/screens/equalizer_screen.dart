import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/equalizer_provider.dart';
import '../theme/nen_theme.dart';

/// 8-band equalizer screen explicitly designed to cleanly match 
/// the premium dark mode mockup, while securely adapting to light theme.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  static const _bandLabels = [
    '60Hz',
    '170Hz',
    '310Hz',
    '600Hz',
    '1kHz',
    '3kHz',
    '6kHz',
    '12kHz',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final eq = ref.watch(equalizerProvider);
    final eqLive = ref.watch(equalizerLiveProvider);

    return Scaffold(
      backgroundColor: colors.background, // Match theme properly
      appBar: AppBar(
        title: const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Switch styled closer to the mockup (pink active track)
          Switch(
            value: eq.isActive,
            activeColor: Colors.white,
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: colors.surfaceElevated,
            onChanged: (val) => ref.read(equalizerProvider.notifier).toggleActive(),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
            tooltip: 'Reset',
            onPressed: () => ref.read(equalizerProvider.notifier).resetBands(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  eq.isActive
                      ? (eqLive
                            ? 'EQ is applied to the current track'
                            : 'EQ applies once a track is playing')
                      : 'Turn on to shape the current track',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              // Preset chips
              SizedBox(
                height: 48, // Taller pill containers
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _presetChip(context, ref, colors, eq.bands, 'Flat', [1, 1, 1, 1, 1, 1, 1, 1]),
                    _presetChip(context, ref, colors, eq.bands, 'Bass Boost', [2.5, 2.0, 1.5, 1, 1, 1, 1, 1]),
                    _presetChip(context, ref, colors, eq.bands, 'Treble Boost', [1, 1, 1, 1, 1.5, 2.0, 2.5, 2.5]),
                    _presetChip(context, ref, colors, eq.bands, 'V-Shape', [2.5, 1.8, 1, 0.8, 0.8, 1, 1.8, 2.5]),
                    _presetChip(context, ref, colors, eq.bands, 'Vocal', [0.8, 1, 1.5, 2.0, 2.0, 1.5, 1, 0.8]),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Band sliders area
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(8, (i) {
                    return Expanded(
                      child: _BandColumn(
                        label: _bandLabels[i],
                        value: eq.bands[i],
                        enabled: eq.isActive,
                        onChanged: (val) => ref.read(equalizerProvider.notifier).setBand(i + 1, val),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetChip(
    BuildContext context,
    WidgetRef ref,
    NenColors colors,
    List<double> currentBands,
    String name,
    List<double> targetBands,
  ) {
    // Determine if this preset is currently active
    bool isMatch = true;
    for (int i = 0; i < 8; i++) {
      if ((currentBands[i] - targetBands[i]).abs() > 0.1) {
        isMatch = false;
        break;
      }
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () async {
        final notifier = ref.read(equalizerProvider.notifier);
        // Turn on EQ automatically if they select a preset
        if (!ref.read(equalizerProvider).isActive) {
          notifier.toggleActive();
        }
        for (int i = 0; i < 8; i++) {
          await notifier.setBand(i + 1, targetBands[i]);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0), // Pill shape
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMatch ? primaryColor : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isMatch
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    spreadRadius: 2,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isMatch ? Colors.white : colors.textPrimary,
            fontSize: 14,
            fontWeight: isMatch ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BandColumn extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandColumn({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  String _formatDb(double multiplier) {
    // 1.0x -> 0dB. 4.0x -> max. We map (value - 1.0) * 12 roughly for UI.
    final db = (multiplier - 1.0) * 12.0;
    if (db.abs() < 1.0) return '0dB';
    if (db > 0) return '+${db.toStringAsFixed(0)}dB';
    return '${db.toStringAsFixed(0)}dB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // dB display above slider
        Text(
          _formatDb(value),
          style: TextStyle(
            color: enabled ? colors.textSecondary : colors.textTertiary.withValues(alpha: 0.3),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 24),

        // Custom stylized vertical slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: primaryColor,
                inactiveTrackColor: colors.surfaceElevated,
                overlayColor: primaryColor.withValues(alpha: 0.1), // subtle interaction glow
                thumbShape: _StrokeThumbShape(
                  radius: 8,
                  strokeColor: primaryColor,
                  fillColor: Colors.white,
                ),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: value,
                min: 0.0,
                max: 4.0,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Frequency label below slider
        Text(
          label,
          style: TextStyle(
            color: enabled ? colors.textSecondary : colors.textTertiary.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Custom Slider Thumb matching the white circle with a colored stroke.
class _StrokeThumbShape extends SliderComponentShape {
  final double radius;
  final Color strokeColor;
  final Color fillColor;

  const _StrokeThumbShape({
    this.radius = 8,
    required this.strokeColor,
    required this.fillColor,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(radius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    
    // Draw solid inner circle
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = fillColor,
    );
    
    // Draw outer colored stroke
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = strokeColor.withValues(alpha: enableAnimation.value) // fade out if disabled
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
