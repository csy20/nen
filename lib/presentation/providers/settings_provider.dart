import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di_providers.dart';

/// Settings state.
class SettingsState {
  final bool reduceMotion;
  final bool reduceFlash;

  const SettingsState({
    this.reduceMotion = false,
    this.reduceFlash = false,
  });

  SettingsState copyWith({bool? reduceMotion, bool? reduceFlash}) {
    return SettingsState(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      reduceFlash: reduceFlash ?? this.reduceFlash,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const SettingsState());

  Future<void> load() async {
    final repo = _ref.read(settingsRepositoryProvider);
    state = SettingsState(
      reduceMotion: await repo.getReduceMotion(),
      reduceFlash: await repo.getReduceFlash(),
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
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});
