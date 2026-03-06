import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

/// Implementation of [SettingsRepository] using SharedPreferences.
class SettingsRepositoryImpl implements SettingsRepository {
  static const _reduceMotionKey = 'reduce_motion';
  static const _reduceFlashKey = 'reduce_flash';
  static const _volumeKey = 'volume';
  static const _accentColorKey = 'accent_color';
  static const _playbackSpeedKey = 'playback_speed';
  static const _crossfadeEnabledKey = 'crossfade_enabled';
  static const _crossfadeDurationKey = 'crossfade_duration';
  static const _favoriteIdsKey = 'favorite_ids';
  static const _recentSongIdsKey = 'recent_song_ids';

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

  @override
  Future<int> getAccentColor() async {
    final prefs = await _prefs;
    return prefs.getInt(_accentColorKey) ?? 0;
  }

  @override
  Future<void> setAccentColor(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_accentColorKey, value);
  }

  @override
  Future<double> getPlaybackSpeed() async {
    final prefs = await _prefs;
    return prefs.getDouble(_playbackSpeedKey) ?? 1.0;
  }

  @override
  Future<void> setPlaybackSpeed(double value) async {
    final prefs = await _prefs;
    await prefs.setDouble(_playbackSpeedKey, value);
  }

  @override
  Future<bool> getCrossfadeEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_crossfadeEnabledKey) ?? false;
  }

  @override
  Future<void> setCrossfadeEnabled(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_crossfadeEnabledKey, value);
  }

  @override
  Future<int> getCrossfadeDuration() async {
    final prefs = await _prefs;
    return prefs.getInt(_crossfadeDurationKey) ?? 3;
  }

  @override
  Future<void> setCrossfadeDuration(int seconds) async {
    final prefs = await _prefs;
    await prefs.setInt(_crossfadeDurationKey, seconds);
  }

  @override
  Future<List<int>> getFavoriteIds() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_favoriteIdsKey) ?? [];
    return list.map((e) => int.parse(e)).toList();
  }

  @override
  Future<void> setFavoriteIds(List<int> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(_favoriteIdsKey, ids.map((e) => e.toString()).toList());
  }

  @override
  Future<List<int>> getRecentSongIds() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_recentSongIdsKey) ?? [];
    return list.map((e) => int.parse(e)).toList();
  }

  @override
  Future<void> setRecentSongIds(List<int> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(_recentSongIdsKey, ids.map((e) => e.toString()).toList());
  }
}
