import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di_providers.dart';

/// Settings state.
class SettingsState {
  final bool reduceMotion;
  final bool reduceFlash;
  final Color? customAccentColor;
  final bool crossfadeEnabled;
  final int crossfadeDuration;

  const SettingsState({
    this.reduceMotion = false,
    this.reduceFlash = false,
    this.customAccentColor,
    this.crossfadeEnabled = false,
    this.crossfadeDuration = 3,
  });

  SettingsState copyWith({
    bool? reduceMotion,
    bool? reduceFlash,
    Color? customAccentColor,
    bool clearAccentColor = false,
    bool? crossfadeEnabled,
    int? crossfadeDuration,
  }) {
    return SettingsState(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceFlash: reduceFlash ?? this.reduceFlash,
      customAccentColor: clearAccentColor ? null : (customAccentColor ?? this.customAccentColor),
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const SettingsState());

  Future<void> load() async {
    final repo = _ref.read(settingsRepositoryProvider);
    final accentVal = await repo.getAccentColor();
    state = SettingsState(
      reduceMotion: await repo.getReduceMotion(),
      reduceFlash: await repo.getReduceFlash(),
      customAccentColor: accentVal != 0 ? Color(accentVal) : null,
      crossfadeEnabled: await repo.getCrossfadeEnabled(),
      crossfadeDuration: await repo.getCrossfadeDuration(),
    );
  }

  Future<void> toggleReduceMotion() async {
    final newVal = !state.reduceMotion;
    state = state.copyWith(reduceMotion: newVal);
    await _ref.read(settingsRepositoryProvider).setReduceMotion(newVal);
  }

  Future<void> toggleReduceFlash() async {
    final newVal = !state.reduceFlash;
    state = state.copyWith(reduceFlash: newVal);
    await _ref.read(settingsRepositoryProvider).setReduceFlash(newVal);
  }

  Future<void> setAccentColor(Color? color) async {
    if (color == null) {
      state = state.copyWith(clearAccentColor: true);
      await _ref.read(settingsRepositoryProvider).setAccentColor(0);
    } else {
      state = state.copyWith(customAccentColor: color);
      await _ref.read(settingsRepositoryProvider).setAccentColor(color.toARGB32());
    }
  }

  Future<void> toggleCrossfade() async {
    final newVal = !state.crossfadeEnabled;
    state = state.copyWith(crossfadeEnabled: newVal);
    await _ref.read(settingsRepositoryProvider).setCrossfadeEnabled(newVal);
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    state = state.copyWith(crossfadeDuration: seconds);
    await _ref.read(settingsRepositoryProvider).setCrossfadeDuration(seconds);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

// ── Favorites Provider ─────────────────────────────────────────────

class FavoritesNotifier extends StateNotifier<Set<int>> {
  final Ref _ref;

  FavoritesNotifier(this._ref) : super(const {});

  Future<void> load() async {
    final ids = await _ref.read(settingsRepositoryProvider).getFavoriteIds();
    state = ids.toSet();
  }

  Future<void> toggle(int songId) async {
    final newSet = Set<int>.from(state);
    if (newSet.contains(songId)) {
      newSet.remove(songId);
    } else {
      newSet.add(songId);
    }
    state = newSet;
    await _ref.read(settingsRepositoryProvider).setFavoriteIds(newSet.toList());
  }

  bool isFavorite(int songId) => state.contains(songId);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<int>>((ref) {
  return FavoritesNotifier(ref);
});

// ── Recently Played Provider ───────────────────────────────────────

class RecentlyPlayedNotifier extends StateNotifier<List<int>> {
  final Ref _ref;
  static const _maxRecent = 50;

  RecentlyPlayedNotifier(this._ref) : super(const []);

  Future<void> load() async {
    final ids = await _ref.read(settingsRepositoryProvider).getRecentSongIds();
    state = ids;
  }

  Future<void> addSong(int songId) async {
    final newList = [songId, ...state.where((id) => id != songId)];
    if (newList.length > _maxRecent) {
      state = newList.sublist(0, _maxRecent);
    } else {
      state = newList;
    }
    await _ref.read(settingsRepositoryProvider).setRecentSongIds(state);
  }
}

final recentlyPlayedProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<int>>((ref) {
  return RecentlyPlayedNotifier(ref);
});

// ── Sleep Timer Provider ───────────────────────────────────────────

class SleepTimerState {
  final Duration? remaining;
  final bool isActive;

  const SleepTimerState({this.remaining, this.isActive = false});

  SleepTimerState copyWith({Duration? remaining, bool? isActive}) {
    return SleepTimerState(
      remaining: remaining ?? this.remaining,
      isActive: isActive ?? this.isActive,
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  SleepTimerNotifier() : super(const SleepTimerState());

  // ignore: unused_field
  Future<void>? _timerFuture;
  bool _cancelled = false;

  void start(Duration duration, VoidCallback onExpired) {
    cancel();
    _cancelled = false;
    state = SleepTimerState(remaining: duration, isActive: true);

    _timerFuture = _tick(duration, onExpired);
  }

  Future<void> _tick(Duration total, VoidCallback onExpired) async {
    var remaining = total;
    while (remaining > Duration.zero && !_cancelled) {
      await Future.delayed(const Duration(seconds: 1));
      if (_cancelled) return;
      remaining -= const Duration(seconds: 1);
      state = SleepTimerState(remaining: remaining, isActive: true);
    }
    if (!_cancelled) {
      state = const SleepTimerState();
      onExpired();
    }
  }

  void cancel() {
    _cancelled = true;
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier();
});
