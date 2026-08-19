/// Thrown when a newer play/skip request cancelled this load.
class PlaybackSupersededException implements Exception {
  const PlaybackSupersededException();
}

/// Thrown when every available decoder fails to play a track.
class AudioPlaybackException implements Exception {
  final String message;
  final String formatLabel;

  const AudioPlaybackException(this.message, {this.formatLabel = 'audio'});

  factory AudioPlaybackException.unsupported({
    required String title,
    required String formatLabel,
  }) {
    return AudioPlaybackException(
      'Can\'t play "$title" ($formatLabel) on this device. '
      'Try another copy of the track if you have one.',
      formatLabel: formatLabel,
    );
  }

  @override
  String toString() => message;
}
