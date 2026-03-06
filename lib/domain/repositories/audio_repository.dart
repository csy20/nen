import '../entities/entities.dart';

/// Contract for the audio playback engine.
abstract class AudioRepository {
  /// Initialize the engine. Must be called once before playback.
  Future<void> initialize();

  /// Tear down the engine, releasing native resources.
  Future<void> dispose();

  /// Load and play a song from disk.
  Future<void> play(Song song);

  /// Pause playback.
  Future<void> pause();

  /// Resume playback.
  Future<void> resume();

  /// Stop playback entirely.
  Future<void> stop();

  /// Seek to [position].
  Future<void> seek(Duration position);

  /// Set volume from 0.0 to 1.0.
  Future<void> setVolume(double volume);

  /// Stream of position updates.
  Stream<Duration> get positionStream;

  /// Stream of playback completion events.
  Stream<void> get completionStream;

  /// Get raw FFT data for the visualizer.
  List<double> getFFTData();

  /// Pre-load a song for gapless transition (optional, for next-track).
  Future<void> preload(Song song);

  /// Play the pre-loaded song immediately (gapless transition).
  Future<void> playPreloaded();

  /// Set playback speed (0.5–2.0).
  Future<void> setSpeed(double speed);

  /// Enable or disable the 8-band equalizer.
  Future<void> setEqualizerActive(bool active);

  /// Set a single EQ band gain (band 1-8, value 0.0–4.0, default 1.0).
  Future<void> setEqualizerBand(int band, double gain);

  /// Get all 8 EQ band gains.
  List<double> getEqualizerBands();

  /// Whether the engine is currently initialized.
  bool get isInitialized;
}
