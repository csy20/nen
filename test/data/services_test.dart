import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/fft_processor.dart';
import 'package:nen/presentation/providers/settings_provider.dart';

void main() {
  group('FFTProcessor', () {
    test('empty data returns zero bands', () {
      final bands = FFTProcessor.process([]);
      expect(bands.subBass, 0.0);
      expect(bands.bass, 0.0);
      expect(bands.mid, 0.0);
      expect(bands.brilliance, 0.0);
    });

    test('non-empty data produces valid bands', () {
      // Create synthetic FFT data with 256 bins
      final fftData = List<double>.generate(256, (i) => (i / 256.0) * 0.8);
      final bands = FFTProcessor.process(fftData);

      // All values should be between 0 and 1
      expect(bands.subBass, greaterThanOrEqualTo(0.0));
      expect(bands.subBass, lessThanOrEqualTo(1.0));
      expect(bands.bass, greaterThanOrEqualTo(0.0));
      expect(bands.bass, lessThanOrEqualTo(1.0));
      expect(bands.mid, greaterThanOrEqualTo(0.0));
      expect(bands.mid, lessThanOrEqualTo(1.0));
      expect(bands.brilliance, greaterThanOrEqualTo(0.0));
      expect(bands.brilliance, lessThanOrEqualTo(1.0));
    });

    test('high energy input clamps to 1.0', () {
      // All bins at max energy
      final fftData = List<double>.filled(256, 10.0);
      final bands = FFTProcessor.process(fftData);

      // Clamped to 1.0
      expect(bands.subBass, lessThanOrEqualTo(1.0));
      expect(bands.bass, lessThanOrEqualTo(1.0));
    });
  });

  group('SettingsState', () {
    test('defaults are false', () {
      const state = SettingsState();
      expect(state.reduceMotion, false);
      expect(state.reduceFlash, false);
    });

    test('copyWith modifies specific fields', () {
      const state = SettingsState();
      final modified = state.copyWith(reduceMotion: true);
      expect(modified.reduceMotion, true);
      expect(modified.reduceFlash, false);
    });

    test('copyWith preserves unmodified fields', () {
      const state = SettingsState(reduceMotion: true, reduceFlash: true);
      final modified = state.copyWith(reduceFlash: false);
      expect(modified.reduceMotion, true);
      expect(modified.reduceFlash, false);
    });
  });
}
