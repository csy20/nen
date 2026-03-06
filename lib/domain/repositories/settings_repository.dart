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

  // Favorites
  Future<List<int>> getFavoriteIds();
  Future<void> setFavoriteIds(List<int> ids);

  // Recently played
  Future<List<int>> getRecentSongIds();
  Future<void> setRecentSongIds(List<int> ids);
}
