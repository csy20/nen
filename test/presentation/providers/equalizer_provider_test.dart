import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/repositories.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/equalizer_provider.dart';

class _FakeAudioRepository implements AudioRepository {
  bool eqActive = false;
  List<double> bands = List<double>.filled(8, 1.0);

  @override
  bool get isInitialized => true;

  @override
  Duration get currentDuration => Duration.zero;

  @override
  Stream<void> get completionStream => const Stream.empty();

  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  List<double> getFFTData() => const [];

  @override
  List<double> getEqualizerBands() => List<double>.from(bands);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(Song song) async {}

  @override
  Future<void> playPreloaded() async {}

  @override
  Future<void> preload(Song song) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {}

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {}

  @override
  Future<void> setEqualizerActive(bool active) async {
    eqActive = active;
  }

  @override
  Future<void> setEqualizerBand(int band, double gain) async {
    bands[band - 1] = gain;
  }

  @override
  Future<void> resetEqualizerBands() async {
    bands = List<double>.filled(8, 1.0);
  }

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> stop() async {}
}

class _FakeSettingsRepository implements SettingsRepository {
  bool eqActive = false;
  List<double> bands = const [2.5, 2.0, 1.5, 1, 1, 1, 1, 1];

  @override
  Future<int> getAccentColor() async => 0;

  @override
  Future<bool> getCrossfadeEnabled() async => false;

  @override
  Future<int> getCrossfadeDuration() async => 3;

  @override
  Future<List<int>> getFavoriteIds() async => const [];

  @override
  Future<double> getPlaybackSpeed() async => 1.0;

  @override
  Future<List<int>> getRecentSongIds() async => const [];

  @override
  Future<bool> getReduceFlash() async => false;

  @override
  Future<bool> getReduceMotion() async => false;

  @override
  Future<bool> getHighContrast() async => false;

  @override
  Future<int> getThemeMode() async => 0;

  @override
  Future<double> getVolume() async => 1.0;

  @override
  Future<void> setAccentColor(int value) async {}

  @override
  Future<void> setCrossfadeDuration(int seconds) async {}

  @override
  Future<void> setCrossfadeEnabled(bool value) async {}

  @override
  Future<void> setFavoriteIds(List<int> ids) async {}

  @override
  Future<void> setPlaybackSpeed(double value) async {}

  @override
  Future<void> setRecentSongIds(List<int> ids) async {}

  @override
  Future<void> setReduceFlash(bool value) async {}

  @override
  Future<void> setReduceMotion(bool value) async {}

  @override
  Future<void> setHighContrast(bool value) async {}

  @override
  Future<void> setThemeMode(int value) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<bool> getEqualizerActive() async => eqActive;

  @override
  Future<void> setEqualizerActive(bool value) async {
    eqActive = value;
  }

  @override
  Future<List<double>> getEqualizerBands() async => bands;

  @override
  Future<void> setEqualizerBands(List<double> value) async {
    bands = value;
  }
}

void main() {
  test('turning EQ on applies saved bands, not a flat engine default', () async {
    final audio = _FakeAudioRepository();
    final settings = _FakeSettingsRepository();
    final container = ProviderContainer(
      overrides: [
        audioRepositoryProvider.overrideWithValue(audio),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(equalizerProvider.notifier);
    await notifier.load();
    expect(container.read(equalizerProvider).isActive, isFalse);
    expect(audio.eqActive, isFalse);

    await notifier.toggleActive();

    expect(container.read(equalizerProvider).isActive, isTrue);
    expect(audio.eqActive, isTrue);
    expect(audio.bands, settings.bands);
  });
}
