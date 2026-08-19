import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nen/data/services/nen_audio_handler.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/repositories.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/playback_provider.dart';

class _FakeAudioRepository implements AudioRepository {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  bool _initialized = false;
  double volume = 1.0;
  double speed = 1.0;
  bool crossfadeEnabled = false;
  Duration crossfadeDuration = const Duration(seconds: 3);
  final List<Song> playedSongs = [];

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isVisualizerLive => false;

  @override
  Duration get currentDuration =>
      playedSongs.isEmpty ? Duration.zero : playedSongs.last.duration;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _completionController.close();
    _initialized = false;
  }

  @override
  List<double> getFFTData() => const [];

  @override
  List<double> getEqualizerBands() => List<double>.filled(8, 1.0);

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> play(Song song) async {
    playedSongs.add(song);
  }

  @override
  Future<void> playPreloaded() async {}

  @override
  Future<void> preload(Song song) async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {
    crossfadeDuration = duration;
  }

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {
    crossfadeEnabled = enabled;
  }

  @override
  Future<void> setEqualizerActive(bool active) async {}

  @override
  Future<void> setEqualizerBand(int band, double gain) async {}

  @override
  Future<void> resetEqualizerBands() async {}

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> stop() async {}

  void emitCompletion() {
    _completionController.add(null);
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  bool reduceMotion = false;
  bool reduceFlash = false;
  double volume = 1.0;
  int accentColor = 0;
  double playbackSpeed = 1.0;
  bool crossfadeEnabled = false;
  int crossfadeDuration = 3;
  int themeMode = 0;
  bool highContrast = false;
  List<int> favoriteIds = const [];
  List<int> recentSongIds = const [];

  @override
  Future<int> getAccentColor() async => accentColor;

  @override
  Future<bool> getCrossfadeEnabled() async => crossfadeEnabled;

  @override
  Future<int> getCrossfadeDuration() async => crossfadeDuration;

  @override
  Future<List<int>> getFavoriteIds() async => favoriteIds;

  @override
  Future<double> getPlaybackSpeed() async => playbackSpeed;

  @override
  Future<List<int>> getRecentSongIds() async => recentSongIds;

  @override
  Future<bool> getReduceFlash() async => reduceFlash;

  @override
  Future<bool> getReduceMotion() async => reduceMotion;

  @override
  Future<bool> getHighContrast() async => highContrast;

  @override
  Future<int> getThemeMode() async => themeMode;

  @override
  Future<double> getVolume() async => volume;

  @override
  Future<void> setAccentColor(int value) async {
    accentColor = value;
  }

  @override
  Future<void> setCrossfadeDuration(int seconds) async {
    crossfadeDuration = seconds;
  }

  @override
  Future<void> setCrossfadeEnabled(bool value) async {
    crossfadeEnabled = value;
  }

  @override
  Future<void> setFavoriteIds(List<int> ids) async {
    favoriteIds = ids;
  }

  @override
  Future<void> setPlaybackSpeed(double value) async {
    playbackSpeed = value;
  }

  @override
  Future<void> setRecentSongIds(List<int> ids) async {
    recentSongIds = ids;
  }

  @override
  Future<void> setReduceFlash(bool value) async {
    reduceFlash = value;
  }

  @override
  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
  }

  @override
  Future<void> setHighContrast(bool value) async {
    highContrast = value;
  }

  @override
  Future<void> setThemeMode(int value) async {
    themeMode = value;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<bool> getEqualizerActive() async => false;

  @override
  Future<void> setEqualizerActive(bool value) async {}

  @override
  Future<List<double>> getEqualizerBands() async => List.filled(8, 1.0);

  @override
  Future<void> setEqualizerBands(List<double> bands) async {}

  @override
  Future<bool> getHasSeenOnboarding() async => false;

  @override
  Future<void> setHasSeenOnboarding(bool value) async {}
}

const _songA = Song(
  id: 1,
  title: 'A',
  artist: 'Artist',
  album: 'Album',
  albumId: 1,
  duration: Duration(minutes: 3),
  filePath: '/music/a.mp3',
);

const _songB = Song(
  id: 2,
  title: 'B',
  artist: 'Artist',
  album: 'Album',
  albumId: 1,
  duration: Duration(minutes: 4),
  filePath: '/music/b.mp3',
);

void main() {
  group('PlaybackNotifier repeat mode', () {
    late _FakeAudioRepository audioRepository;
    late NenAudioHandler audioHandler;
    late ProviderContainer container;

    setUp(() async {
      audioRepository = _FakeAudioRepository();
      audioHandler = NenAudioHandler(audioRepository);
      await audioHandler.init();

      container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(audioHandler),
          settingsRepositoryProvider.overrideWithValue(
            _FakeSettingsRepository(),
          ),
        ],
      );

      container.read(playbackProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() async {
      container.dispose();
      await audioHandler.teardown();
    });

    test('cycleRepeat syncs state through the audio handler', () async {
      final notifier = container.read(playbackProvider.notifier);

      expect(audioRepository.isInitialized, isTrue);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.off);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.none,
      );

      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.one);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.one,
      );

      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.all);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.all,
      );

      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.off);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.none,
      );
    });

    test('repeat mode survives track changes', () async {
      final notifier = container.read(playbackProvider.notifier);

      await notifier.cycleRepeat();
      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.all);

      await notifier.playQueue(const [_songA, _songB]);
      await Future<void>.delayed(Duration.zero);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.all,
      );

      await notifier.next();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playbackProvider).repeatMode, NenRepeatMode.all);
      expect(
        audioHandler.playbackState.value.repeatMode,
        audio_svc.AudioServiceRepeatMode.all,
      );
      expect(audioHandler.playbackState.value.queueIndex, 1);
    });

    test('repeat one restarts the current track on completion', () async {
      final notifier = container.read(playbackProvider.notifier);

      await notifier.playQueue(const [_songA, _songB]);
      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);

      audioRepository.emitCompletion();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final playback = container.read(playbackProvider);
      expect(playback.repeatMode, NenRepeatMode.one);
      expect(playback.queueIndex, 0);
      expect(playback.currentSong, _songA);
      expect(playback.position, Duration.zero);
      expect(audioRepository.playedSongs, [_songA, _songA]);
      expect(audioHandler.playbackState.value.queueIndex, 0);
    });

    test('repeat all wraps to the start of the queue on completion', () async {
      final notifier = container.read(playbackProvider.notifier);

      await notifier.playQueue(const [_songA, _songB], startIndex: 1);
      await notifier.cycleRepeat();
      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);

      audioRepository.emitCompletion();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final playback = container.read(playbackProvider);
      expect(playback.repeatMode, NenRepeatMode.all);
      expect(playback.queueIndex, 0);
      expect(playback.currentSong, _songA);
      expect(audioRepository.playedSongs, [_songB, _songA]);
      expect(audioHandler.playbackState.value.queueIndex, 0);
    });

    test('shuffle next from last index still plays another track', () async {
      final notifier = container.read(playbackProvider.notifier);

      await notifier.playQueue(const [_songA, _songB], startIndex: 1);
      notifier.toggleShuffle();
      await notifier.next();
      await Future<void>.delayed(Duration.zero);

      final playback = container.read(playbackProvider);
      expect(playback.isPlaying, isTrue);
      expect(playback.currentSong, _songA);
      expect(audioRepository.playedSongs, [_songB, _songA]);
    });

    test('skipToNext bypasses repeat-one completion behavior', () async {
      final notifier = container.read(playbackProvider.notifier);

      await notifier.playQueue(const [_songA, _songB]);
      await notifier.cycleRepeat();
      await Future<void>.delayed(Duration.zero);

      await audioHandler.skipToNext();
      await Future<void>.delayed(Duration.zero);

      final playback = container.read(playbackProvider);
      expect(playback.repeatMode, NenRepeatMode.one);
      expect(playback.queueIndex, 1);
      expect(playback.currentSong, _songB);
      expect(audioRepository.playedSongs, [_songA, _songB]);
      expect(audioHandler.playbackState.value.queueIndex, 1);
    });
  });

  group('PlaybackFeedbackNotifier', () {
    test('show publishes a message and clear removes the matching event', () {
      final notifier = PlaybackFeedbackNotifier();
      addTearDown(notifier.dispose);

      notifier.show('Failed to play track');
      final firstMessage = notifier.state;

      expect(firstMessage, isNotNull);
      expect(firstMessage!.message, 'Failed to play track');

      notifier.clear(firstMessage.id + 1);
      expect(notifier.state, isNotNull);

      notifier.clear(firstMessage.id);
      expect(notifier.state, isNull);
    });

    test('new messages get unique ids', () {
      final notifier = PlaybackFeedbackNotifier();
      addTearDown(notifier.dispose);

      notifier.show('First');
      final firstId = notifier.state!.id;
      notifier.show('Second');

      expect(notifier.state!.id, isNot(firstId));
      expect(notifier.state!.message, 'Second');
    });
  });
}
