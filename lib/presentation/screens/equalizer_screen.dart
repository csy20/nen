import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/equalizer_provider.dart';
import '../theme/nen_theme.dart';

/// 8-band equalizer screen using SoLoud's built-in EQ filter.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  static const _bandLabels = [
    '60Hz', '170Hz', '310Hz', '600Hz',
    '1kHz', '3kHz', '6kHz', '12kHz',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(equalizerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          Switch(
            value: eq.isActive,
            onChanged: (_) =>
                ref.read(equalizerProvider.notifier).toggleActive(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset',
            onPressed: () =>
                ref.read(equalizerProvider.notifier).resetBands(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            // Preset chips
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _presetChip(ref, 'Flat', [1,1,1,1,1,1,1,1]),
                  _presetChip(ref, 'Bass Boost', [2.5,2.0,1.5,1,1,1,1,1]),
                  _presetChip(ref, 'Treble Boost', [1,1,1,1,1.5,2.0,2.5,3.0]),
                  _presetChip(ref, 'V-Shape', [2.5,1.8,1,0.8,0.8,1,1.8,2.5]),
                  _presetChip(ref, 'Vocal', [0.8,1,1.5,2.0,2.0,1.5,1,0.8]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Band sliders
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(8, (i) {
                  return Expanded(
                    child: _BandSlider(
                      label: _bandLabels[i],
                      value: eq.bands[i],
                      enabled: eq.isActive,
                      onChanged: (val) =>
                          ref.read(equalizerProvider.notifier).setBand(i + 1, val),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(WidgetRef ref, String name, List<double> bands) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(name, style: const TextStyle(fontSize: 12)),
        backgroundColor: NenTheme.surfaceElevated,
        onPressed: () async {
          final notifier = ref.read(equalizerProvider.notifier);
          for (int i = 0; i < 8; i++) {
            await notifier.setBand(i + 1, bands[i]);
          }
        },
      ),
    );
  }
}

class _BandSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value.toStringAsFixed(1)}x',
          style: TextStyle(
            color: enabled ? NenTheme.textSecondary : NenTheme.textTertiary,
            fontSize: 10,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: 0.0,
              max: 4.0,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: enabled ? NenTheme.textSecondary : NenTheme.textTertiary,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}
