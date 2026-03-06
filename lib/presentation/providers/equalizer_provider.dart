import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di_providers.dart';

/// EQ state: active flag + 8 band gains (0.0–4.0, default 1.0).
class EqualizerState {
  final bool isActive;
  final List<double> bands; // 8 bands

  const EqualizerState({this.isActive = false, this.bands = const [1,1,1,1,1,1,1,1]});

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

  Future<void> toggleActive() async {
    final newActive = !state.isActive;
    state = state.copyWith(isActive: newActive);
    await _ref.read(audioRepositoryProvider).setEqualizerActive(newActive);
  }

  Future<void> setBand(int band, double gain) async {
    final newBands = List<double>.from(state.bands);
    newBands[band - 1] = gain.clamp(0.0, 4.0);
    state = state.copyWith(bands: newBands);
    await _ref.read(audioRepositoryProvider).setEqualizerBand(band, gain);
  }

  Future<void> resetBands() async {
    final defaults = List.filled(8, 1.0);
    state = state.copyWith(bands: defaults);
    final repo = _ref.read(audioRepositoryProvider);
    for (int i = 1; i <= 8; i++) {
      await repo.setEqualizerBand(i, 1.0);
    }
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
  return EqualizerNotifier(ref);
});
