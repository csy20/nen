/// Contract for user settings persistence.
abstract class SettingsRepository {
  Future<bool> getReduceMotion();
  Future<void> setReduceMotion(bool value);
  Future<bool> getReduceFlash();
  Future<void> setReduceFlash(bool value);
  Future<double> getVolume();
  Future<void> setVolume(double value);
  Future<int> getAccentColor();
  Future<void> setAccentColor(int value);
  Future<double> getPlaybackSpeed();
  Future<void> setPlaybackSpeed(double value);
  Future<bool> getCrossfadeEnabled();
  Future<void> setCrossfadeEnabled(bool value);
  Future<int> getCrossfadeDuration();
  Future<void> setCrossfadeDuration(int seconds);

  // Theme mode: 0=dark, 1=light, 2=system
  Future<int> getThemeMode();
  Future<void> setThemeMode(int value);

  // High contrast mode
  Future<bool> getHighContrast();
  Future<void> setHighContrast(bool value);

  // Favorites
  Future<List<int>> getFavoriteIds();
  Future<void> setFavoriteIds(List<int> ids);

  // Recently played
  Future<List<int>> getRecentSongIds();
  Future<void> setRecentSongIds(List<int> ids);

  // Equalizer
  Future<bool> getEqualizerActive();
  Future<void> setEqualizerActive(bool value);
  Future<List<double>> getEqualizerBands();
  Future<void> setEqualizerBands(List<double> bands);

  // First-launch onboarding
  Future<bool> getHasSeenOnboarding();
  Future<void> setHasSeenOnboarding(bool value);

  // Last now-playing session (queue + position) so reopen restores the card
  Future<LastPlaybackSession?> getLastPlaybackSession();
  Future<void> setLastPlaybackSession(LastPlaybackSession? session);
}

/// Persisted now-playing snapshot. Does not include audio bytes.
class LastPlaybackSession {
  final List<int> queueIds;
  final int queueIndex;
  final int positionMs;
  final bool wasPlaying;

  const LastPlaybackSession({
    required this.queueIds,
    required this.queueIndex,
    required this.positionMs,
    required this.wasPlaying,
  });

  Map<String, Object?> toJson() => {
    'queueIds': queueIds,
    'queueIndex': queueIndex,
    'positionMs': positionMs,
    'wasPlaying': wasPlaying,
  };

  static LastPlaybackSession? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawIds = json['queueIds'];
    if (rawIds is! List || rawIds.isEmpty) return null;
    final ids = <int>[
      for (final id in rawIds)
        if (id is int)
          id
        else if (id is num)
          id.toInt()
        else
          int.tryParse('$id') ?? 0,
    ].where((id) => id != 0).toList();
    if (ids.isEmpty) return null;
    return LastPlaybackSession(
      queueIds: ids,
      queueIndex: (json['queueIndex'] as num?)?.toInt() ?? 0,
      positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
      wasPlaying: json['wasPlaying'] == true,
    );
  }
}
