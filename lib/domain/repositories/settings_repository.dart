/// Contract for user settings persistence.
abstract class SettingsRepository {
  Future<bool> getReduceMotion();
  Future<void> setReduceMotion(bool value);
  Future<bool> getReduceFlash();
  Future<void> setReduceFlash(bool value);
  Future<double> getVolume();
  Future<void> setVolume(double value);
}
