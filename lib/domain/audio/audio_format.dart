/// Detects a track's container/codec and picks a playback backend.
///
/// Nen is format-agnostic: every common on-device audio type should play.
/// SoLoud is used when it can decode natively (low-latency + visualizer).
/// The system decoder (just_audio) covers everything else, including ALAC,
/// AAC/M4A, AIFF, WMA, and unknown extensions.
enum AudioBackend { soloud, system }

class AudioFormat {
  /// SoLoud `LoadMode.memory` expands compressed audio to uncompressed PCM.
  /// A 40 MB MP3/FLAC can become ~1 GB and abort the process (std::bad_alloc).
  /// Only tiny clips are safe to fully decode in RAM.
  static const int memoryLoadMaxBytes = 2 * 1024 * 1024;
  static const int memoryLoadMaxDurationMs = 15000;

  /// Skip SoLoud for giant files; ExoPlayer (just_audio) streams them.
  static const int soloudMaxFileBytes = 80 * 1024 * 1024;

  static const _soloudExtensions = {
    'mp3',
    'wav',
    'wave',
    'flac',
    'ogg',
    'oga',
    'opus',
  };

  /// Extensions the system decoder is more likely to handle than SoLoud.
  static const _systemFirstExtensions = {
    'm4a',
    'm4b',
    'aac',
    'alac',
    'caf',
    'aiff',
    'aif',
    'aifc',
    'wma',
    'asf',
    'amr',
    'awb',
    '3gp',
    '3g2',
    'mp4',
    'mov',
    'webm',
    'mkv',
    'ape',
    'wv',
    'mpc',
    'ac3',
    'dts',
    'mid',
    'midi',
    'xmf',
    'rtttl',
    'rtx',
    'ota',
    'imy',
  };

  const AudioFormat._();

  static String extensionOf(String pathOrName) {
    final normalized = pathOrName.trim().toLowerCase().replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    final name = slash >= 0 ? normalized.substring(slash + 1) : normalized;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  static String normalizeExtension(String? raw, {String fallbackPath = ''}) {
    var ext = (raw ?? '').trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    if (ext.isNotEmpty) return ext;
    return extensionOf(fallbackPath);
  }

  static AudioBackend preferredBackend({
    required String extension,
    required String filePath,
    required bool fileIsReadable,
    int fileSize = 0,
    Duration duration = Duration.zero,
  }) {
    final ext = normalizeExtension(extension, fallbackPath: filePath);
    if (!fileIsReadable) {
      return AudioBackend.system;
    }
    if (!isSoLoudSafe(fileSizeBytes: fileSize, duration: duration)) {
      return AudioBackend.system;
    }
    if (_systemFirstExtensions.contains(ext)) {
      return AudioBackend.system;
    }
    if (_soloudExtensions.contains(ext) || ext.isEmpty) {
      return AudioBackend.soloud;
    }
    return AudioBackend.system;
  }

  /// Whether SoLoud may fully decode this file into PCM.
  ///
  /// Music-library tracks fail this check on purpose — they must stream.
  static bool canSafelyDecodeToMemory({
    required int fileSizeBytes,
    required Duration duration,
  }) {
    if (fileSizeBytes <= 0 || fileSizeBytes > memoryLoadMaxBytes) {
      return false;
    }
    if (duration > const Duration(milliseconds: memoryLoadMaxDurationMs)) {
      return false;
    }
    return true;
  }

  /// Whether SoLoud should even try this file. Huge WAVs / multi-hour
  /// recordings belong on the system decoder.
  static bool isSoLoudSafe({
    required int fileSizeBytes,
    required Duration duration,
  }) {
    if (fileSizeBytes > soloudMaxFileBytes) return false;
    if (duration >= const Duration(hours: 4)) return false;
    return true;
  }

  /// Rough 48 kHz stereo 16-bit PCM size for [duration].
  static int estimatedPcmBytes(Duration duration) {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return 0;
    return ms * 48 * 2 * 2;
  }

  static AudioBackend fallbackBackend(AudioBackend preferred) {
    return preferred == AudioBackend.soloud
        ? AudioBackend.system
        : AudioBackend.soloud;
  }

  static String displayName(String extension) {
    final ext = extension.trim().toLowerCase();
    if (ext.isEmpty) return 'audio';
    return ext.toUpperCase();
  }
}
