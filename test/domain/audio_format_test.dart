import 'package:flutter_test/flutter_test.dart';
import 'package:nen/domain/audio/audio_format.dart';

void main() {
  group('AudioFormat.extensionOf', () {
    test('reads the last extension from a path', () {
      expect(AudioFormat.extensionOf('/music/Song Title.FLAC'), 'flac');
      expect(AudioFormat.extensionOf(r'C:\Music\track.m4a'), 'm4a');
      expect(AudioFormat.extensionOf('no-extension'), '');
    });
  });

  group('AudioFormat.preferredBackend', () {
    test('uses SoLoud for common native formats when the file is readable', () {
      for (final ext in ['mp3', 'wav', 'flac', 'ogg', 'opus']) {
        expect(
          AudioFormat.preferredBackend(
            extension: ext,
            filePath: '/music/track.$ext',
            fileIsReadable: true,
          ),
          AudioBackend.soloud,
          reason: ext,
        );
      }
    });

    test('uses the system decoder for containers SoLoud cannot handle', () {
      for (final ext in ['m4a', 'alac', 'aac', 'wma', 'aiff', 'amr', '3gp']) {
        expect(
          AudioFormat.preferredBackend(
            extension: ext,
            filePath: '/music/track.$ext',
            fileIsReadable: true,
          ),
          AudioBackend.system,
          reason: ext,
        );
      }
    });

    test('uses the system decoder when the filesystem path is unreadable', () {
      expect(
        AudioFormat.preferredBackend(
          extension: 'flac',
          filePath: '',
          fileIsReadable: false,
        ),
        AudioBackend.system,
      );
    });

    test('falls back to the other backend', () {
      expect(
        AudioFormat.fallbackBackend(AudioBackend.soloud),
        AudioBackend.system,
      );
      expect(
        AudioFormat.fallbackBackend(AudioBackend.system),
        AudioBackend.soloud,
      );
    });
  });
}
