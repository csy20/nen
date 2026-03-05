/// Frequency band magnitudes extracted from FFT data.
/// Values are normalized 0.0–1.0.
class FrequencyBands {
  final double subBass;   // 20–60 Hz
  final double bass;      // 60–250 Hz
  final double lowMid;    // 250–500 Hz
  final double mid;       // 500–2000 Hz
  final double upperMid;  // 2000–4000 Hz
  final double presence;  // 4000–6000 Hz
  final double brilliance; // 6000–20000 Hz

  const FrequencyBands({
    this.subBass = 0.0,
    this.bass = 0.0,
    this.lowMid = 0.0,
    this.mid = 0.0,
    this.upperMid = 0.0,
    this.presence = 0.0,
    this.brilliance = 0.0,
  });

  /// Encode as a list of floats for texture upload.
  List<double> toList() =>
      [subBass, bass, lowMid, mid, upperMid, presence, brilliance];

  static const FrequencyBands zero = FrequencyBands();
}
