import '../../domain/entities/entities.dart';

/// Processes raw FFT data into frequency bands for the shader.
class FFTProcessor {
  /// Process raw FFT data (256 bins) into 7 frequency bands.
  ///
  /// FFT bins map to frequencies as:
  ///   frequency = binIndex * sampleRate / fftSize
  ///
  /// Assuming 44100 Hz sample rate and 256-bin FFT:
  ///   each bin ≈ 44100 / 512 ≈ 86 Hz
  static FrequencyBands process(List<double> fftData) {
    if (fftData.isEmpty) return FrequencyBands.zero;

    final len = fftData.length;
    // Bin ranges (approx 86 Hz per bin at 44100 Hz / 512 FFT size)
    // Sub-Bass:   20–60 Hz   → bins 0–0   (clamped to at least 1 bin)
    // Bass:       60–250 Hz  → bins 1–2
    // Low Mid:    250–500 Hz → bins 3–5
    // Mid:        500–2kHz   → bins 6–23
    // Upper Mid:  2–4 kHz    → bins 24–46
    // Presence:   4–6 kHz    → bins 47–69
    // Brilliance: 6–20 kHz   → bins 70–232

    double subBass = _avgRange(fftData, 0, 1.clamp(0, len));
    double bass = _avgRange(fftData, 1, 3.clamp(0, len));
    double lowMid = _avgRange(fftData, 3, 6.clamp(0, len));
    double mid = _avgRange(fftData, 6, 24.clamp(0, len));
    double upperMid = _avgRange(fftData, 24, 47.clamp(0, len));
    double presence = _avgRange(fftData, 47, 70.clamp(0, len));
    double brilliance = _avgRange(fftData, 70, len);

    return FrequencyBands(
      subBass: _smoothClamp(subBass),
      bass: _smoothClamp(bass),
      lowMid: _smoothClamp(lowMid),
      mid: _smoothClamp(mid),
      upperMid: _smoothClamp(upperMid),
      presence: _smoothClamp(presence),
      brilliance: _smoothClamp(brilliance),
    );
  }

  static double _avgRange(List<double> data, int from, int to) {
    if (from >= to || from >= data.length) return 0.0;
    final end = to.clamp(0, data.length);
    final start = from.clamp(0, data.length);
    if (start >= end) return 0.0;

    double sum = 0.0;
    for (int i = start; i < end; i++) {
      sum += data[i].abs();
    }
    return sum / (end - start);
  }

  /// Normalize and clamp to 0.0–1.0.
  /// FFT magnitudes from SoLoud are typically in 0.0–1.0 range already,
  /// but we apply a gentle boost and clamp for safety.
  static double _smoothClamp(double value) {
    return (value * 2.5).clamp(0.0, 1.0);
  }
}
