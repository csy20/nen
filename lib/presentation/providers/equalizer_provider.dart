import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di_providers.dart';

class EqualizerState {
  final bool isActive;
  final List<double> bands;

  const EqualizerState({
    this.isActive = false,
    this.bands = const [1, 1, 1, 1, 1, 1, 1, 1],
  });

  EqualizerState copyWith({bool? isActive, List<double>? bands}) {
    return EqualizerState(
      isActive: isActive ?? this.isActive,
      bands: bands ?? this.bands,
    );
  }
}

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  final Ref _ref;

  EqualizerNotifier(this._ref) : super(const EqualizerState());

  Future<void> load() async {
    final repo = _ref.read(settingsRepositoryProvider);
    final active = await repo.getEqualizerActive();
    final bands = await repo.getEqualizerBands();
    state = EqualizerState(isActive: active, bands: bands);
    if (active) {
      await _ref.read(audioRepositoryProvider).setEqualizerActive(true);
      await Future.wait([
        for (int i = 1; i <= 8; i++)
          _ref.read(audioRepositoryProvider).setEqualizerBand(i, bands[i - 1]),
      ]);
    }
  }

  Future<void> toggleActive() async {
    final newActive = !state.isActive;
    state = state.copyWith(isActive: newActive);
    final audio = _ref.read(audioRepositoryProvider);
    await audio.setEqualizerActive(newActive);
    if (newActive) {
      await Future.wait([
        for (int i = 1; i <= 8; i++) audio.setEqualizerBand(i, state.bands[i - 1]),
      ]);
    }
    await _ref.read(settingsRepositoryProvider).setEqualizerActive(newActive);
  }

  Future<void> setBand(int band, double gain) async {
    if (band < 1 || band > 8) return;
    final newBands = List<double>.from(state.bands);
    newBands[band - 1] = gain.clamp(0.0, 4.0);
    state = state.copyWith(bands: newBands);
    await _ref.read(audioRepositoryProvider).setEqualizerBand(band, gain);
    await _ref.read(settingsRepositoryProvider).setEqualizerBands(newBands);
  }

  Future<void> resetBands() async {
    final defaults = List.filled(8, 1.0);
    state = state.copyWith(bands: defaults);
    await _ref.read(audioRepositoryProvider).resetEqualizerBands();
    await _ref.read(settingsRepositoryProvider).setEqualizerBands(defaults);
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
      return EqualizerNotifier(ref);
    });
