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
    test('uses SoLoud only for short clips that fit in memory', () {
      for (final ext in ['mp3', 'wav', 'flac', 'ogg', 'opus']) {
        expect(
          AudioFormat.preferredBackend(
            extension: ext,
            filePath: '/music/track.$ext',
            fileIsReadable: true,
            fileSize: 512 * 1024,
            duration: const Duration(seconds: 8),
          ),
          AudioBackend.soloud,
          reason: ext,
        );
      }
    });

    test('uses ExoPlayer for library-length MP3/FLAC talks', () {
      expect(
        AudioFormat.preferredBackend(
          extension: 'mp3',
          filePath: '/music/osho-maha-geeta-11.mp3',
          fileIsReadable: true,
          fileSize: 25 * 1024 * 1024,
          duration: const Duration(minutes: 90),
        ),
        AudioBackend.system,
      );
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

    test('routes huge files to the system decoder', () {
      expect(
        AudioFormat.preferredBackend(
          extension: 'flac',
          filePath: '/music/live.flac',
          fileIsReadable: true,
          fileSize: AudioFormat.soloudMaxFileBytes + 1,
        ),
        AudioBackend.system,
      );
    });
  });

  group('AudioFormat memory safety', () {
    test('refuses to fully decode library-length tracks into PCM', () {
      expect(
        AudioFormat.canSafelyDecodeToMemory(
          fileSizeBytes: 30 * 1024 * 1024,
          duration: const Duration(minutes: 4),
        ),
        isFalse,
      );
      expect(
        AudioFormat.canSafelyDecodeToMemory(
          fileSizeBytes: 512 * 1024,
          duration: const Duration(seconds: 8),
        ),
        isTrue,
      );
      expect(
        AudioFormat.canSafelyDecodeToMemory(
          fileSizeBytes: 0,
          duration: const Duration(seconds: 5),
        ),
        isFalse,
      );
    });

    test('estimated PCM for a 90-minute track is around 1 GB', () {
      final bytes = AudioFormat.estimatedPcmBytes(const Duration(minutes: 90));
      expect(bytes, greaterThan(900 * 1024 * 1024));
      expect(bytes, lessThan(1100 * 1024 * 1024));
    });

    test('coalesceDuration keeps metadata when decoder reports ~1s', () {
      expect(
        AudioFormat.coalesceDuration(
          const Duration(seconds: 1),
          const Duration(minutes: 90),
        ),
        const Duration(minutes: 90),
      );
      expect(
        AudioFormat.coalesceDuration(
          const Duration(minutes: 4),
          const Duration(minutes: 4, seconds: 2),
        ),
        const Duration(minutes: 4),
      );
    });
  });
}
