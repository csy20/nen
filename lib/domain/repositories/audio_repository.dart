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

  /// Whether the engine is currently initialized.
  bool get isInitialized;
}
