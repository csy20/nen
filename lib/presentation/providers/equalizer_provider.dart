import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di_providers.dart';
import 'playback_provider.dart';

class EqualizerState {
  final bool isActive;
  final List<double> bands;
  final bool isLive;

  const EqualizerState({
    this.isActive = false,
    this.bands = const [1, 1, 1, 1, 1, 1, 1, 1],
    this.isLive = false,
  });

  EqualizerState copyWith({bool? isActive, List<double>? bands, bool? isLive}) {
    return EqualizerState(
      isActive: isActive ?? this.isActive,
      bands: bands ?? this.bands,
      isLive: isLive ?? this.isLive,
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
    _syncLive();
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
    _syncLive();
  }

  Future<void> setBand(int band, double gain) async {
    if (band < 1 || band > 8) return;
    final newBands = List<double>.from(state.bands);
    newBands[band - 1] = gain.clamp(0.0, 4.0);
    state = state.copyWith(bands: newBands);
    await _ref.read(audioRepositoryProvider).setEqualizerBand(band, gain);
    await _ref.read(settingsRepositoryProvider).setEqualizerBands(newBands);
    _syncLive();
  }

  Future<void> resetBands() async {
    final defaults = List.filled(8, 1.0);
    state = state.copyWith(bands: defaults);
    await _ref.read(audioRepositoryProvider).resetEqualizerBands();
    await _ref.read(settingsRepositoryProvider).setEqualizerBands(defaults);
    _syncLive();
  }

  void _syncLive() {
    final live = _ref.read(audioRepositoryProvider).isEqualizerLive;
    if (state.isLive != live) {
      state = state.copyWith(isLive: live);
    }
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
      return EqualizerNotifier(ref);
    });

/// Re-reads the engine after play/pause so the EQ screen can show whether
/// bands are actually attached to the current session.
final equalizerLiveProvider = Provider<bool>((ref) {
  ref.watch(equalizerProvider.select((s) => s.isActive));
  ref.watch(playbackProvider.select((s) => s.isPlaying));
  ref.watch(playbackProvider.select((s) => s.currentSong?.id));
  return ref.read(audioRepositoryProvider).isEqualizerLive;
});
