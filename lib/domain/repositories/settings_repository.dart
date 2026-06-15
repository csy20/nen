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
}
