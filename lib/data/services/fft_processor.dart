import '../../domain/entities/entities.dart';

/// Processes raw FFT data into frequency bands for the shader.
class FFTProcessor {
  // Bin ranges (approx 86 Hz per bin at 44100 Hz / 512 FFT size)
  static const int _subBassEnd = 1; // Sub-Bass:   20–60 Hz   → bins 0–0
  static const int _bassEnd = 3; // Bass:       60–250 Hz  → bins 1–2
  static const int _lowMidEnd = 6; // Low Mid:    250–500 Hz → bins 3–5
  static const int _midEnd = 24; // Mid:        500–2kHz   → bins 6–23
  static const int _upperMidEnd = 47; // Upper Mid:  2–4 kHz    → bins 24–46
  static const int _presenceEnd = 70; // Presence:   4–6 kHz    → bins 47–69
  // Brilliance: 6–20 kHz → bins 70–232 (remaining)

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

    double subBass = _avgRange(fftData, 0, _subBassEnd.clamp(0, len));
    double bass = _avgRange(fftData, _subBassEnd, _bassEnd.clamp(0, len));
    double lowMid = _avgRange(fftData, _bassEnd, _lowMidEnd.clamp(0, len));
    double mid = _avgRange(fftData, _lowMidEnd, _midEnd.clamp(0, len));
    double upperMid = _avgRange(fftData, _midEnd, _upperMidEnd.clamp(0, len));
    double presence = _avgRange(
      fftData,
      _upperMidEnd,
      _presenceEnd.clamp(0, len),
    );
    double brilliance = _avgRange(fftData, _presenceEnd, len);

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
    if (value.isNaN || value.isInfinite) return 0.0;
    return (value * 2.5).clamp(0.0, 1.0);
  }
}
