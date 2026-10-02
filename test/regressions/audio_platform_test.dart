import '../support/repositories.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart'
    as platform;
import 'package:nen/data/repositories/audio_repository_impl.dart';
import 'package:nen/domain/audio/audio_playback_exception.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nen/data/services/nen_audio_handler.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/settings_repository.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/playback_provider.dart';

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
  duration: Duration(minutes: 3),
  filePath: '/music/b.mp3',
);

Future<void> _waitUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Native playback request did not arrive');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Platform extends platform.JustAudioPlatform {
  void Function(_Player)? onCreate;
  final players = <_Player>[];
  @override
  Future<platform.AudioPlayerPlatform> init(
    platform.InitRequest request,
  ) async {
    final player = _Player(request.id);
    players.add(player);
    onCreate?.call(player);
    return player;
  }

  @override
  Future<platform.DisposePlayerResponse> disposePlayer(
    platform.DisposePlayerRequest request,
  ) async {
    for (final player in players.where((p) => p.id == request.id)) {
      player.finish();
    }
    return platform.DisposePlayerResponse();
  }
}

class _Player extends platform.AudioPlayerPlatform {
  _Player(super.id);
  final events = StreamController<platform.PlaybackEventMessage>.broadcast();
  final seeks = <Duration>[];
  final loadedUris = <String>[];
  final loadPositions = <Duration>[];
  final playPositions = <Duration>[];
  Duration _position = Duration.zero;
  Completer<platform.PlayResponse>? playing;
  Completer<void>? loadGate;
  int _loadGeneration = 0;
  @override
  Stream<platform.PlaybackEventMessage> get playbackEventMessageStream =>
      events.stream;
  void emit(
    platform.ProcessingStateMessage state, {
    Duration position = Duration.zero,
  }) {
    _position = position;
    events.add(
      platform.PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.now(),
        updatePosition: position,
        bufferedPosition: const Duration(minutes: 3),
        duration: const Duration(minutes: 3),
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: 1,
      ),
    );
  }

  @override
  Future<platform.LoadResponse> load(platform.LoadRequest request) async {
    final child =
        (request.audioSourceMessage as platform.ConcatenatingAudioSourceMessage)
            .children
            .single;
    loadedUris.add((child as platform.UriAudioSourceMessage).uri);
    final position = request.initialPosition ?? Duration.zero;
    loadPositions.add(position);
    final generation = ++_loadGeneration;
    final gate = loadGate;
    loadGate = null;
    if (gate != null) await gate.future;
    if (generation == _loadGeneration) {
      emit(platform.ProcessingStateMessage.ready, position: position);
    }
    return platform.LoadResponse(duration: const Duration(minutes: 3));
  }

  @override
  Future<platform.PlayResponse> play(platform.PlayRequest request) {
    playPositions.add(_position);
    playing ??= Completer<platform.PlayResponse>();
    return playing!.future;
  }

  void finish() {
    final pending = playing;
    playing = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(platform.PlayResponse());
    }
  }

  @override
  Future<platform.PauseResponse> pause(platform.PauseRequest request) async {
    finish();
    return platform.PauseResponse();
  }

  @override
  Future<platform.SeekResponse> seek(platform.SeekRequest request) async {
    seeks.add(request.position!);
    emit(platform.ProcessingStateMessage.ready, position: request.position!);
    return platform.SeekResponse();
  }

  @override
  Future<platform.SetVolumeResponse> setVolume(
    platform.SetVolumeRequest request,
  ) async => platform.SetVolumeResponse();
  @override
  Future<platform.SetSpeedResponse> setSpeed(
    platform.SetSpeedRequest request,
  ) async => platform.SetSpeedResponse();
  @override
  Future<platform.SetLoopModeResponse> setLoopMode(
    platform.SetLoopModeRequest request,
  ) async => platform.SetLoopModeResponse();
  @override
  Future<platform.SetShuffleModeResponse> setShuffleMode(
    platform.SetShuffleModeRequest request,
  ) async => platform.SetShuffleModeResponse();
  @override
  Future<platform.SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    platform.SetAndroidAudioAttributesRequest request,
  ) async => platform.SetAndroidAudioAttributesResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('native playback requests', () {
    late platform.JustAudioPlatform previousPlatform;
    late _Platform backend;
    late AudioRepositoryImpl audio;
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null,
          );
      previousPlatform = platform.JustAudioPlatform.instance;
      backend = _Platform();
      platform.JustAudioPlatform.instance = backend;
      audio = AudioRepositoryImpl();
    });
    tearDown(() async {
      await audio.dispose();
      platform.JustAudioPlatform.instance = previousPlatform;
    });

    test(
      'play and resume complete while native playback remains pending',
      () async {
        await audio
            .play(_songA, initialPosition: const Duration(seconds: 45))
            .timeout(const Duration(seconds: 2));
        await _waitUntil(() => backend.players.last.playPositions.isNotEmpty);
        final native = backend.players.last;
        expect(native.playPositions, [const Duration(seconds: 45)]);
        expect(native.playing!.isCompleted, false);
        await audio.pause();
        await audio.resume().timeout(const Duration(seconds: 2));
        await _waitUntil(() => native.playPositions.length == 2);
        expect(native.playing!.isCompleted, false);
        expect(audio.isPlaying, true);
      },
    );

    test(
      'asynchronous native play failures surface without an unhandled future',
      () async {
        await audio.play(_songA);
        await _waitUntil(() => backend.players.last.playing != null);
        final failure = audio.errorStream.first;
        backend.players.last.playing!.completeError(
          PlatformException(code: 'unsupported', message: 'Decoder failed'),
        );
        final error = await failure.timeout(const Duration(seconds: 2));
        expect(error.message, contains('Can\'t play "A"'));
        await _waitUntil(() => !audio.isPlaying);
      },
    );

    test(
      'replacing an unfinished load never starts the superseded song',
      () async {
        // Source changes run on an already active native player. Initial
        // activation is serialized by just_audio itself.
        await audio.play(_songB);
        await _waitUntil(() => backend.players.last.playPositions.isNotEmpty);
        await audio.pause();
        final native = backend.players.last;
        native.loadedUris.clear();
        native.playPositions.clear();
        final gate = Completer<void>();
        native.loadGate = gate;
        final first = audio.play(_songA);
        final superseded = expectLater(
          first,
          throwsA(isA<PlaybackSupersededException>()),
        );
        await _waitUntil(
          () =>
              backend.players.isNotEmpty &&
              backend.players.last.loadedUris.isNotEmpty,
        );
        await audio
            .play(_songB, initialPosition: const Duration(seconds: 10))
            .timeout(const Duration(seconds: 2));
        await _waitUntil(() => backend.players.last.playPositions.isNotEmpty);
        gate.complete();
        await superseded;
        expect(native.loadedUris.last, endsWith('/b.mp3'));
        expect(native.playPositions, [const Duration(seconds: 10)]);
        expect(audio.isPlaying, true);
      },
    );

    test(
      'pausing an unfinished load preserves its seek and prevents autoplay',
      () async {
        final gate = Completer<void>();
        backend.onCreate = (player) => player.loadGate = gate;
        final loading = audio.play(
          _songA,
          initialPosition: const Duration(seconds: 60),
        );
        await _waitUntil(
          () =>
              backend.players.isNotEmpty &&
              backend.players.last.loadedUris.isNotEmpty,
        );
        await audio.pause();
        expect(audio.currentPosition, const Duration(seconds: 60));
        gate.complete();
        await loading.timeout(const Duration(seconds: 2));
        expect(backend.players.last.playPositions, isEmpty);
        expect(audio.currentPosition, const Duration(seconds: 60));
        expect(audio.isPlaying, false);
        await audio.resume();
        await _waitUntil(() => backend.players.last.playPositions.isNotEmpty);
        expect(backend.players.last.playPositions, [
          const Duration(seconds: 60),
        ]);
      },
    );
  });

  test(
    'real AudioRepository seeks to saved position before playback is paused',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null,
          );
      final oldPlatform = platform.JustAudioPlatform.instance;
      final backend = _Platform();
      platform.JustAudioPlatform.instance = backend;
      final audio = AudioRepositoryImpl();
      final handler = NenAudioHandler(audio);
      await handler.init();
      final settings = FakeSettingsRepository()
        ..lastSession = const LastPlaybackSession(
          queueIds: [1],
          queueIndex: 0,
          positionMs: 60000,
          wasPlaying: false,
        );
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          settingsRepositoryProvider.overrideWithValue(settings),
          musicRepositoryProvider.overrideWithValue(
            FakeMusicRepository(const [_songA]),
          ),
        ],
      );
      container.read(playbackProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(playbackProvider).position,
        const Duration(seconds: 60),
      );
      final cancelledResume = container
          .read(playbackProvider.notifier)
          .resume();
      await container.read(playbackProvider.notifier).pause();
      await cancelledResume;
      expect(container.read(playbackProvider).isPlaying, false);
      expect(
        container.read(playbackProvider).position,
        const Duration(seconds: 60),
      );
      final resume = container.read(playbackProvider.notifier).resume();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(audio.isPlaying, true);
      final beforePause = List<Duration>.from(
        backend.players.last.playPositions,
      );
      await container.read(playbackProvider.notifier).pause();
      await resume;
      final afterPause = List<Duration>.from(
        backend.players.last.loadPositions,
      );
      container.dispose();
      await handler.teardown();
      platform.JustAudioPlatform.instance = oldPlatform;
      expect(afterPause, contains(const Duration(seconds: 60)));
      expect(beforePause, contains(const Duration(seconds: 60)));
    },
  );

  test(
    'repeat one continues through at least three native completions',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null,
          );
      final oldPlatform = platform.JustAudioPlatform.instance;
      final backend = _Platform();
      platform.JustAudioPlatform.instance = backend;
      final audio = AudioRepositoryImpl();
      final handler = NenAudioHandler(audio);
      await handler.init();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
          musicRepositoryProvider.overrideWithValue(
            FakeMusicRepository(const []),
          ),
        ],
      );
      final player = container.read(playbackProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await player.playSong(_songA);
      await player.cycleRepeat();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      backend.players.last.emit(platform.ProcessingStateMessage.completed);
      backend.players.last.finish();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final afterFirst = backend.players.last.loadedUris.length;
      backend.players.last.emit(platform.ProcessingStateMessage.completed);
      backend.players.last.finish();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final afterSecond = backend.players.last.loadedUris.length;
      await handler.pause();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      container.dispose();
      await handler.teardown();
      platform.JustAudioPlatform.instance = oldPlatform;
      expect(afterFirst, 2);
      expect(afterSecond, 3);
    },
  );

  test(
    'pausing a new song preserves the elapsed position in UI and saved session',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.ryanheise.audio_session'),
            (_) async => null,
          );
      final oldPlatform = platform.JustAudioPlatform.instance;
      final backend = _Platform();
      platform.JustAudioPlatform.instance = backend;
      final audio = AudioRepositoryImpl();
      final handler = NenAudioHandler(audio);
      await handler.init();
      final settings = FakeSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          settingsRepositoryProvider.overrideWithValue(settings),
          musicRepositoryProvider.overrideWithValue(
            FakeMusicRepository(const []),
          ),
        ],
      );
      final player = container.read(playbackProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await player.playSong(_songA);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      backend.players.last.emit(
        platform.ProcessingStateMessage.ready,
        position: const Duration(seconds: 30),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final progress = Completer<void>();
      final listener = container.listen(playbackProvider, (_, next) {
        if (next.position >= const Duration(seconds: 30) &&
            !progress.isCompleted) {
          progress.complete();
        }
      }, fireImmediately: true);
      await progress.future.timeout(const Duration(seconds: 2));
      listener.close();
      final duringPlayback = container.read(playbackProvider).position;
      await player.pause();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final afterPause = container.read(playbackProvider).position;
      final savedMs = settings.lastSession?.positionMs;
      container.dispose();
      await handler.teardown();
      platform.JustAudioPlatform.instance = oldPlatform;
      expect(duringPlayback.inSeconds, greaterThanOrEqualTo(30));
      expect(afterPause.inSeconds, greaterThanOrEqualTo(30));
      expect(savedMs, greaterThanOrEqualTo(30000));
    },
  );
}
