import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

/// Implementation of [SettingsRepository] using SharedPreferences.
class SettingsRepositoryImpl implements SettingsRepository {
  static const _reduceMotionKey = 'reduce_motion';
  static const _reduceFlashKey = 'reduce_flash';
  static const _volumeKey = 'volume';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<bool> getReduceMotion() async {
    final prefs = await _prefs;
    return prefs.getBool(_reduceMotionKey) ?? false;
  }

  @override
  Future<void> setReduceMotion(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_reduceMotionKey, value);
  }

  @override
  Future<bool> getReduceFlash() async {
    final prefs = await _prefs;
    return prefs.getBool(_reduceFlashKey) ?? false;
  }

  @override
  Future<void> setReduceFlash(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_reduceFlashKey, value);
  }

  @override
  Future<double> getVolume() async {
    final prefs = await _prefs;
    return prefs.getDouble(_volumeKey) ?? 1.0;
  }

  @override
  Future<void> setVolume(double value) async {
    final prefs = await _prefs;
    await prefs.setDouble(_volumeKey, value);
  }
}
