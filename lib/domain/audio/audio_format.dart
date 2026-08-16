/// Detects a track's container/codec and picks a playback backend.
///
/// Nen is format-agnostic: every common on-device audio type should play.
/// SoLoud is used when it can decode natively (low-latency + visualizer).
/// The system decoder (just_audio) covers everything else, including ALAC,
/// AAC/M4A, AIFF, WMA, and unknown extensions.
enum AudioBackend { soloud, system }

class AudioFormat {
  static const int memoryLoadMaxBytes = 40 * 1024 * 1024;

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
  }) {
    final ext = normalizeExtension(extension, fallbackPath: filePath);
    if (!fileIsReadable) {
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
