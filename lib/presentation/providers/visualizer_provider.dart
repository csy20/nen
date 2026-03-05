import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/fft_processor.dart';
import '../../domain/entities/entities.dart';
import 'di_providers.dart';

/// Provides real-time frequency band data for the visualizer.
/// Polled by the shader widget on each frame.
final frequencyBandsProvider = Provider<FrequencyBands>((ref) {
  final audio = ref.watch(audioRepositoryProvider);
  if (!audio.isInitialized) return FrequencyBands.zero;
  final fftData = audio.getFFTData();
  return FFTProcessor.process(fftData);
});
