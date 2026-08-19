import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _reduceMotionKey = 'reduce_motion';
  static const _reduceFlashKey = 'reduce_flash';
  static const _volumeKey = 'volume';
  static const _accentColorKey = 'accent_color';
  static const _playbackSpeedKey = 'playback_speed';
  static const _crossfadeEnabledKey = 'crossfade_enabled';
  static const _crossfadeDurationKey = 'crossfade_duration';
  static const _themeModeKey = 'theme_mode';
  static const _highContrastKey = 'high_contrast';
  static const _favoriteIdsKey = 'favorite_ids';
  static const _recentSongIdsKey = 'recent_song_ids';
  static const _eqActiveKey = 'eq_active';
  static const _eqBandsKey = 'eq_bands';
  static const _hasSeenOnboardingKey = 'has_seen_onboarding';

  SharedPreferences? _cachedPrefs;

  Future<SharedPreferences> get _prefs async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

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
    return list.map((e) => int.tryParse(e) ?? 0).toList();
  }

  @override
  Future<void> setFavoriteIds(List<int> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _favoriteIdsKey,
      ids.map((e) => e.toString()).toList(),
    );
  }

  @override
  Future<List<int>> getRecentSongIds() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_recentSongIdsKey) ?? [];
    return list.map((e) => int.tryParse(e) ?? 0).toList();
  }

  @override
  Future<void> setRecentSongIds(List<int> ids) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _recentSongIdsKey,
      ids.map((e) => e.toString()).toList(),
    );
  }

  @override
  Future<int> getThemeMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_themeModeKey) ?? 0;
  }

  @override
  Future<void> setThemeMode(int value) async {
    final prefs = await _prefs;
    await prefs.setInt(_themeModeKey, value);
  }

  @override
  Future<bool> getHighContrast() async {
    final prefs = await _prefs;
    return prefs.getBool(_highContrastKey) ?? false;
  }

  @override
  Future<void> setHighContrast(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_highContrastKey, value);
  }

  @override
  Future<bool> getEqualizerActive() async {
    final prefs = await _prefs;
    return prefs.getBool(_eqActiveKey) ?? false;
  }

  @override
  Future<void> setEqualizerActive(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_eqActiveKey, value);
  }

  @override
  Future<List<double>> getEqualizerBands() async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_eqBandsKey);
    if (list == null) {
      return List.filled(8, 1.0);
    }
    final parsed = list.map((e) => double.tryParse(e) ?? 1.0).toList();
    if (parsed.length < 8) {
      parsed.addAll(List.filled(8 - parsed.length, 1.0));
    }
    return parsed.take(8).map((gain) => gain.clamp(0.0, 4.0)).toList();
  }

  @override
  Future<void> setEqualizerBands(List<double> bands) async {
    final prefs = await _prefs;
    await prefs.setStringList(
      _eqBandsKey,
      bands.map((e) => e.toString()).toList(),
    );
  }

  @override
  Future<bool> getHasSeenOnboarding() async {
    final prefs = await _prefs;
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  @override
  Future<void> setHasSeenOnboarding(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_hasSeenOnboardingKey, value);
  }
}
