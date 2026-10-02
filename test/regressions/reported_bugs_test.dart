import '../support/repositories.dart';
import 'package:nen/domain/audio/audio_playback_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nen/data/repositories/music_repository_impl.dart';
import 'package:nen/data/services/library_media_store.dart';
import 'package:nen/data/services/permission_service.dart';
import 'package:nen/presentation/providers/library_providers.dart';
import 'package:nen/presentation/providers/settings_provider.dart';
import 'package:nen/presentation/screens/home_screen.dart';
import 'package:nen/presentation/screens/library_screen.dart';
import 'package:nen/presentation/screens/now_playing_screen.dart';
import 'package:nen/presentation/screens/permission_screen.dart';
import 'package:nen/presentation/screens/settings_screen.dart';
import 'package:nen/presentation/screens/equalizer_screen.dart';
import 'package:nen/presentation/theme/nen_theme.dart';
import 'package:nen/presentation/widgets/audio_visualizer_bars.dart';
import 'package:nen/presentation/widgets/song_actions_sheet.dart';
import 'package:nen/presentation/widgets/song_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nen/data/services/nen_audio_handler.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/repositories.dart';
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
  duration: Duration(minutes: 4),
  filePath: '/music/b.mp3',
);

class _ToggleMusic extends FakeMusicRepository {
  _ToggleMusic() : super(const [_songA, _songB]);
  bool denied = true;
  int queries = 0;
  @override
  Future<List<Song>> getSongs() async {
    queries++;
    if (denied) {
      throw const LibraryAccessException('Denied', permissionDenied: true);
    }
    return songs;
  }
}

class _GrantedPermission extends PermissionService {
  @override
  Future<bool> hasAudioPermission() async => true;
}

class _AlbumLibrary extends LibraryMediaStore {
  _AlbumLibrary({this.tracks = const [3, 1, 2]});
  final List<int> tracks;
  @override
  Future<int> sdkInt() async => 34;
  @override
  Future<List<Map<String, dynamic>>> querySongs() async => [
    for (final (index, track) in tracks.indexed)
      {
        'id': index + 1,
        'title': 'Title $index',
        'artist': 'Artist',
        'album': 'Album',
        'albumId': 10,
        'artistId': 20,
        'duration': 180000,
        'filePath': '/music/${index + 1}.mp3',
        'uri': 'content://media/external/audio/media/${index + 1}',
        'trackNumber': track,
      },
  ];
}

List<Playlist> _playlists(int count) => List.generate(
  count,
  (i) => Playlist(
    id: '$i',
    name: 'Playlist $i',
    songs: const [],
    createdAt: DateTime(2026),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cleanups = <FutureOr<void> Function()>[];
  void regressionWidgets(String description, WidgetTesterCallback callback) {
    testWidgets(description, (tester) async {
      try {
        await callback(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final cleanup in cleanups.reversed) {
          await tester.runAsync(() async {
            await cleanup();
          });
        }
        cleanups.clear();
      }
    });
  }

  setUp(() {
    cleanups.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
  });

  ProviderContainer setupPlayback({
    FakeAudioRepository? audio,
    FakeSettingsRepository? settings,
    MusicRepository? music,
    PlaylistRepository? playlists,
  }) {
    final handler = NenAudioHandler(audio ?? FakeAudioRepository());
    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        settingsRepositoryProvider.overrideWithValue(
          settings ?? FakeSettingsRepository(),
        ),
        musicRepositoryProvider.overrideWithValue(
          music ?? FakeMusicRepository(const [_songA, _songB]),
        ),
        if (playlists != null)
          playlistRepositoryProvider.overrideWithValue(playlists),
      ],
    );
    cleanups.add(() async {
      container.dispose();
      await handler.teardown();
    });
    container.read(playbackProvider);
    return container;
  }

  Future<void> mount(
    WidgetTester tester,
    ProviderContainer container,
    Widget widget, {
    Size size = const Size(400, 900),
    double textScale = 1,
    EdgeInsets safeArea = EdgeInsets.zero,
    Brightness brightness = Brightness.dark,
  }) async {
    await tester.binding.setSurfaceSize(size);
    cleanups.add(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: brightness == Brightness.dark
              ? NenTheme.buildDark()
              : NenTheme.buildLight(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: safeArea,
            ),
            child: child!,
          ),
          home: widget,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  regressionWidgets('sleep timer replacement cannot fire the old callback', (
    tester,
  ) async {
    final timer = SleepTimerNotifier();
    cleanups.add(timer.dispose);
    var oldExpired = 0;
    timer.start(const Duration(seconds: 2), () => oldExpired++);
    await tester.pump(const Duration(milliseconds: 100));
    timer.cancel();
    timer.start(const Duration(seconds: 20), () {});
    await tester.pump(const Duration(seconds: 2));
    expect(
      oldExpired,
      0,
      reason: 'The cancelled countdown must stay cancelled',
    );
    expect(timer.state.isActive, true);
  });

  test('album playback respects tagged track order', () async {
    final repo = MusicRepositoryImpl(
      deviceLibrary: _AlbumLibrary(),
      useNativeLibrary: true,
    );
    final songs = await repo.getSongsByAlbum(10);
    expect(songs.map((s) => s.trackNumber).toList(), [1, 2, 3]);
  });

  regressionWidgets('queue edits made while paused are persisted', (
    tester,
  ) async {
    final settings = FakeSettingsRepository();
    final container = setupPlayback(settings: settings);
    await tester.pump();
    final player = container.read(playbackProvider.notifier);
    await player.playQueue(const [_songA, _songB]);
    await tester.pump();
    await player.pause();
    await tester.pump(const Duration(milliseconds: 500));
    expect(settings.lastSession!.queueIds, [1, 2]);
    player.clearQueue();
    await tester.pump(const Duration(seconds: 1));
    expect(settings.lastSession!.queueIds, [
      1,
    ], reason: 'Clear must survive a cold restart');
  });

  regressionWidgets('duplicate queue entries restore the selected occurrence', (
    tester,
  ) async {
    final settings = FakeSettingsRepository()
      ..lastSession = const LastPlaybackSession(
        queueIds: [1, 2, 1],
        queueIndex: 2,
        positionMs: 30000,
        wasPlaying: false,
      );
    final container = setupPlayback(settings: settings);
    await tester.pump();
    expect(container.read(playbackProvider).queue.length, 3);
    expect(container.read(playbackProvider).queueIndex, 2);
  });

  regressionWidgets(
    'shuffle with repeat off eventually exhausts a two-song queue',
    (tester) async {
      final audio = FakeAudioRepository();
      final container = setupPlayback(audio: audio);
      await tester.pump();
      final player = container.read(playbackProvider.notifier);
      await player.playQueue(const [_songA, _songB]);
      player.toggleShuffle();
      await tester.pump(const Duration(milliseconds: 50));
      await player.next();
      await tester.pump(const Duration(milliseconds: 50));
      await player.next();
      await tester.pump(const Duration(milliseconds: 50));
      expect(audio.playedSongs, [_songA, _songB]);
      expect(container.read(playbackProvider).isPlaying, false);
    },
  );

  regressionWidgets(
    'MediaSession queue includes all items for a nonzero queueIndex',
    (tester) async {
      final container = setupPlayback();
      await tester.pump();
      await container.read(playbackProvider.notifier).playQueue(const [
        _songA,
        _songB,
      ], startIndex: 1);
      await tester.pump(const Duration(milliseconds: 50));
      final handler = container.read(audioHandlerProvider);
      expect(handler.playbackState.value.queueIndex, 1);
      expect(handler.queue.value.length, 2);
    },
  );

  regressionWidgets('volume and speed saves do not cancel each other', (
    tester,
  ) async {
    final settings = FakeSettingsRepository();
    final container = setupPlayback(settings: settings);
    await tester.pump();
    final player = container.read(playbackProvider.notifier);
    await player.setVolume(0.4);
    await player.setSpeed(1.5);
    await tester.pump(const Duration(milliseconds: 500));
    expect(settings.playbackSpeed, 1.5);
    expect(settings.volume, 0.4);
  });

  regressionWidgets('visualizer requests repaint after its heights change', (
    tester,
  ) async {
    final container = setupPlayback();
    await container.read(playbackProvider.notifier).playSong(_songA);
    await mount(
      tester,
      container,
      const SizedBox(height: 60, child: AudioVisualizerBars()),
    );
    final finder = find.descendant(
      of: find.byType(AudioVisualizerBars),
      matching: find.byType(CustomPaint),
    );
    final before = tester.widget<CustomPaint>(finder).painter!;
    final previousHeights = List<double>.from((before as dynamic).barHeights);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.widget<CustomPaint>(finder).painter!;
    expect(
      List<double>.from((after as dynamic).barHeights),
      isNot(previousHeights),
    );
    expect(after.shouldRepaint(before), true);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  regressionWidgets('Home navigation fits a 360dp wide phone', (tester) async {
    final container = setupPlayback(music: FakeMusicRepository(const []));
    await mount(
      tester,
      container,
      const HomeScreen(),
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });

  regressionWidgets('Now Playing fits a 360 by 640 phone', (tester) async {
    final container = setupPlayback();
    await container.read(playbackProvider.notifier).playSong(_songA);
    await mount(
      tester,
      container,
      const NowPlayingScreen(),
      size: const Size(360, 640),
    );
    expect(tester.takeException(), isNull);
  });

  regressionWidgets(
    'the last favorite can be tapped above the floating navigation',
    (tester) async {
      final songs = List.generate(
        20,
        (i) => _songA.copyWith(id: i + 1, title: 'Track ${i + 1}'),
      );
      final settings = FakeSettingsRepository()
        ..favoriteIds = songs.map((s) => s.id).toList();
      final container = setupPlayback(
        settings: settings,
        music: FakeMusicRepository(songs),
      );
      await container.read(favoritesProvider.notifier).load();
      await mount(tester, container, const HomeScreen());
      await tester.tap(find.byIcon(Icons.favorite_border_rounded).last);
      await tester.pumpAndSettle();
      final list = find.descendant(
        of: find.byType(FavoritesTab),
        matching: find.byType(ListView),
      );
      await tester.drag(list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final last = find.widgetWithText(SongTile, 'Track 20');
      expect(last.hitTestable(), findsOneWidget);
    },
  );

  regressionWidgets('Settings theme selector fits a 400dp phone', (
    tester,
  ) async {
    final container = setupPlayback();
    await mount(tester, container, const SettingsScreen());
    expect(tester.takeException(), isNull);
  });

  regressionWidgets('Now Playing exposes the playback speed slider', (
    tester,
  ) async {
    final container = setupPlayback();
    await container.read(playbackProvider.notifier).playSong(_songA);
    await mount(tester, container, const NowPlayingScreen());
    final sliders = tester.widgetList<Slider>(find.byType(Slider));
    expect(sliders.where((s) => s.min == 0.5 && s.max == 2.0), hasLength(1));
  });

  regressionWidgets('high contrast removes Settings glass blur', (
    tester,
  ) async {
    final container = setupPlayback();
    await mount(
      tester,
      container,
      const SettingsScreen(),
      size: const Size(500, 900),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    await container.read(settingsProvider.notifier).toggleHighContrast();
    await tester.pump();
    expect(container.read(settingsProvider).highContrast, true);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  regressionWidgets(
    'permission recovery invalidates the cached library error',
    (tester) async {
      final music = _ToggleMusic();
      final handler = NenAudioHandler(FakeAudioRepository());
      final container = ProviderContainer(
        overrides: [
          musicRepositoryProvider.overrideWithValue(music),
          audioHandlerProvider.overrideWithValue(handler),
          permissionServiceProvider.overrideWithValue(_GrantedPermission()),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
      );
      cleanups.add(() async {
        container.dispose();
        await handler.teardown();
      });
      await expectLater(
        container.read(songsProvider.future),
        throwsA(isA<LibraryAccessException>()),
      );
      music.denied = false;
      await mount(tester, container, const PermissionScreen());
      expect(container.read(hasAudioPermissionProvider), true);
      expect(await container.read(songsProvider.future), [_songA, _songB]);
      expect(container.read(songsProvider).hasError, false);
    },
  );

  regressionWidgets('song action sheet with 12 playlists remains scrollable', (
    tester,
  ) async {
    final handler = NenAudioHandler(FakeAudioRepository());
    final container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(handler),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        musicRepositoryProvider.overrideWithValue(
          FakeMusicRepository(const []),
        ),
        playlistRepositoryProvider.overrideWithValue(
          FakePlaylistRepository(_playlists(12)),
        ),
      ],
    );
    cleanups.add(() async {
      container.dispose();
      await handler.teardown();
    });
    await mount(
      tester,
      container,
      Consumer(
        builder: (context, ref, _) => Scaffold(
          body: TextButton(
            onPressed: () => showSongActionsSheet(context, ref, _songA),
            child: const Text('Actions'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Playlist 11'));
    await tester.pumpAndSettle();
    expect(find.text('Playlist 11').hitTestable(), findsOneWidget);
  });

  for (final mutation in [
    'append',
    'append batch',
    'remove',
    'reorder',
    'clear',
  ]) {
    regressionWidgets('paused queue $mutation survives provider recreation', (
      tester,
    ) async {
      final c = _songA.copyWith(id: 3, title: 'C');
      final d = _songA.copyWith(id: 4, title: 'D');
      final music = FakeMusicRepository([_songA, _songB, c, d]);
      final settings = FakeSettingsRepository();
      final container = setupPlayback(settings: settings, music: music);
      await tester.pump();
      final player = container.read(playbackProvider.notifier);
      await player.playQueue([_songA, _songB, c], startIndex: 1);
      await tester.pump(const Duration(milliseconds: 50));
      await player.seek(const Duration(seconds: 30));
      await player.pause();
      switch (mutation) {
        case 'append':
          player.addToQueue(d);
        case 'append batch':
          player.addAllToQueue([d, _songA]);
        case 'remove':
          player.removeFromQueue(0);
        case 'reorder':
          player.reorderQueue(1, 3);
        case 'clear':
          player.clearQueue();
      }
      await tester.pump(const Duration(milliseconds: 500));
      final expected = container.read(playbackProvider);
      expect(settings.lastSession!.queueIds, expected.queue.map((s) => s.id));
      expect(settings.lastSession!.queueIndex, expected.queueIndex);
      final handler = container.read(audioHandlerProvider);
      expect(
        handler.queue.value.map((item) => item.extras!['songId']),
        settings.lastSession!.queueIds,
      );
      expect(handler.playbackState.value.queueIndex, expected.queueIndex);
      final restarted = setupPlayback(settings: settings, music: music);
      await tester.pump();
      final restored = restarted.read(playbackProvider);
      expect(restored.queue, expected.queue);
      expect(restored.queueIndex, expected.queueIndex);
      expect(restored.currentSong, _songB);
      expect(restored.position, const Duration(seconds: 30));
      expect(restored.isPlaying, false);
    });
  }

  regressionWidgets(
    'clearing every queue item clears the saved session and MediaSession',
    (tester) async {
      final settings = FakeSettingsRepository();
      final audio = FakeAudioRepository();
      final container = setupPlayback(settings: settings, audio: audio);
      await tester.pump();
      final player = container.read(playbackProvider.notifier);
      await player.playQueue(const [_songA, _songB]);
      await tester.pump(const Duration(milliseconds: 50));
      player.clearQueue(keepCurrent: false);
      await tester.pump(const Duration(milliseconds: 500));
      await player.resume();
      expect(settings.lastSession, isNull);
      expect(container.read(playbackProvider).currentSong, isNull);
      expect(container.read(audioHandlerProvider).queue.value, isEmpty);
      expect(
        container.read(audioHandlerProvider).playbackState.value.queueIndex,
        isNull,
      );
      expect(audio.isPlaying, false);
    },
  );

  for (final missingSelected in [false, true]) {
    regressionWidgets(
      'restoration maps saved occurrences with missingSelected=$missingSelected',
      (tester) async {
        final settings = FakeSettingsRepository()
          ..lastSession = LastPlaybackSession(
            queueIds: missingSelected ? [1, 99, 2] : [99, 1, 2, 1],
            queueIndex: missingSelected ? 1 : 3,
            positionMs: 30000,
            wasPlaying: true,
          );
        final container = setupPlayback(settings: settings);
        await tester.pump();
        final state = container.read(playbackProvider);
        expect(state.queueIndex, missingSelected ? 0 : 2);
        expect(
          state.position,
          missingSelected ? Duration.zero : const Duration(seconds: 30),
        );
        expect(state.isPlaying, false);
      },
    );
  }

  regressionWidgets(
    'shuffle visits every duplicate occurrence once on natural completion',
    (tester) async {
      final audio = FakeAudioRepository();
      final container = setupPlayback(audio: audio);
      unawaited(container.read(audioHandlerProvider).init());
      await tester.pump();
      final player = container.read(playbackProvider.notifier);
      final c = _songA.copyWith(id: 3, title: 'C');
      await player.playQueue([_songA, _songB, _songA, c]);
      player.toggleShuffle();
      await tester.pump(const Duration(milliseconds: 50));
      final visited = [container.read(playbackProvider).queueIndex];
      for (var i = 0; i < 3; i++) {
        audio.emitCompletion();
        await tester.pump(const Duration(milliseconds: 50));
        visited.add(container.read(playbackProvider).queueIndex);
      }
      audio.emitCompletion();
      await tester.pump(const Duration(milliseconds: 50));
      expect(visited.toSet(), {0, 1, 2, 3});
      expect(audio.playedSongs, hasLength(4));
      expect(container.read(playbackProvider).isPlaying, false);
    },
  );

  regressionWidgets('shuffle repeat all starts another complete pass', (
    tester,
  ) async {
    final audio = FakeAudioRepository();
    final container = setupPlayback(audio: audio);
    await tester.pump();
    final player = container.read(playbackProvider.notifier);
    await player.playQueue([_songA, _songB, _songA.copyWith(id: 3)]);
    player.toggleShuffle();
    await player.cycleRepeat();
    await player.cycleRepeat();
    await tester.pump(const Duration(milliseconds: 50));
    final visited = [container.read(playbackProvider).queueIndex];
    for (var i = 0; i < 5; i++) {
      await player.next();
      await tester.pump(const Duration(milliseconds: 50));
      visited.add(container.read(playbackProvider).queueIndex);
    }
    expect(visited.take(3).toSet(), {0, 1, 2});
    expect(visited.skip(3).toSet(), {0, 1, 2});
    expect(visited[2], isNot(visited[3]));
    expect(container.read(playbackProvider).isPlaying, true);
  });

  regressionWidgets(
    'queue changes during shuffle preserve visited occurrence identity',
    (tester) async {
      final audio = FakeAudioRepository();
      final container = setupPlayback(audio: audio);
      await tester.pump();
      final player = container.read(playbackProvider.notifier);
      final c = _songA.copyWith(id: 3);
      final d = _songA.copyWith(id: 4);
      await player.playQueue([_songA, _songB, c]);
      player.toggleShuffle();
      await tester.pump(const Duration(milliseconds: 50));
      player.reorderQueue(0, 3);
      player.addToQueue(d);
      player.removeFromQueue(
        container
            .read(playbackProvider)
            .queue
            .indexWhere((song) => song.id == 2),
      );
      for (var i = 0; i < 3; i++) {
        await player.next();
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(audio.playedSongs.map((song) => song.id).toList()..sort(), [
        1,
        3,
        4,
      ]);
      expect(container.read(playbackProvider).isPlaying, false);
    },
  );

  regressionWidgets('shuffle Previous follows the traversal history', (
    tester,
  ) async {
    final container = setupPlayback();
    await tester.pump();
    final player = container.read(playbackProvider.notifier);
    await player.playQueue([_songA, _songB, _songA.copyWith(id: 3)]);
    player.toggleShuffle();
    await tester.pump(const Duration(milliseconds: 50));
    await player.next();
    await tester.pump(const Duration(milliseconds: 50));
    final middle = container.read(playbackProvider).queueIndex;
    await player.next();
    await tester.pump(const Duration(milliseconds: 50));
    await player.previous();
    await tester.pump(const Duration(milliseconds: 50));
    expect(container.read(playbackProvider).queueIndex, middle);
  });

  regressionWidgets('rapid track selection discards the superseded request', (
    tester,
  ) async {
    final audio = FakeAudioRepository();
    final settings = FakeSettingsRepository();
    final container = setupPlayback(audio: audio, settings: settings);
    await tester.pump();
    final player = container.read(playbackProvider.notifier);
    await player.playSong(_songA);
    await player.playSong(_songB);
    await tester.pump(const Duration(milliseconds: 500));
    expect(audio.playedSongs, [_songB]);
    expect(container.read(playbackProvider).currentSong, _songB);
    expect(settings.recentSongIds.first, 2);
  });

  regressionWidgets(
    'asynchronous playback errors reach the foreground and MediaSession',
    (tester) async {
      final audio = FakeAudioRepository();
      final container = setupPlayback(audio: audio);
      unawaited(container.read(audioHandlerProvider).init());
      await tester.pump();
      await container.read(playbackProvider.notifier).playSong(_songA);
      await tester.pump(const Duration(milliseconds: 50));
      audio.emitError(const AudioPlaybackException('Playback failed'));
      await tester.pump();
      expect(
        container.read(playbackFeedbackProvider)!.message,
        'Playback failed',
      );
      expect(container.read(playbackProvider).isPlaying, false);
      expect(
        container.read(audioHandlerProvider).playbackState.value.playing,
        false,
      );
    },
  );

  for (final speedFirst in [false, true]) {
    regressionWidgets(
      'independent setting debounces save both values speedFirst=$speedFirst',
      (tester) async {
        final settings = FakeSettingsRepository();
        final container = setupPlayback(settings: settings);
        await tester.pump();
        final player = container.read(playbackProvider.notifier);
        if (speedFirst) {
          await player.setSpeed(1.25);
          await player.setVolume(0.2);
        } else {
          await player.setVolume(0.2);
          await player.setSpeed(1.25);
        }
        await player.setSpeed(1.5);
        await player.setVolume(0.4);
        await tester.pump(const Duration(milliseconds: 500));
        expect(settings.playbackSpeed, 1.5);
        expect(settings.volume, 0.4);
      },
    );
  }

  for (final width in [320.0, 360.0, 393.0, 400.0]) {
    regressionWidgets(
      'home and theme controls fit ${width.toInt()}dp at large text',
      (tester) async {
        final container = setupPlayback(playlists: FakePlaylistRepository());
        await mount(
          tester,
          container,
          const HomeScreen(),
          size: Size(width, 900),
          textScale: 1.8,
        );
        expect(tester.takeException(), isNull);
        await mount(
          tester,
          container,
          const SettingsScreen(),
          size: Size(width, 900),
          textScale: 1.8,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Theme'),
          200,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump();
        expect(find.text('Auto').hitTestable(), findsOneWidget);
      },
    );
  }

  regressionWidgets(
    'compact Now Playing scrolls to controls with large text and safe areas',
    (tester) async {
      final container = setupPlayback();
      await container.read(playbackProvider.notifier).playSong(_songA);
      await mount(
        tester,
        container,
        const NowPlayingScreen(),
        size: const Size(320, 568),
        textScale: 2,
        safeArea: const EdgeInsets.only(top: 24, bottom: 34),
      );
      expect(tester.takeException(), isNull);
      final speed = find.byKey(const Key('playback_speed'));
      await tester.ensureVisible(speed);
      await tester.pump();
      expect(speed.hitTestable(), findsOneWidget);
      final favorite = find.byTooltip('Add to favourites');
      await tester.ensureVisible(favorite);
      await tester.pump();
      expect(favorite.hitTestable(), findsOneWidget);
    },
  );

  regressionWidgets(
    'restored muted volume and fast speed can both be reset from Now Playing',
    (tester) async {
      final settings = FakeSettingsRepository()
        ..volume = 0
        ..playbackSpeed = 1.5;
      final audio = FakeAudioRepository();
      final container = setupPlayback(settings: settings, audio: audio);
      await tester.pump();
      await container.read(playbackProvider.notifier).playSong(_songA);
      await mount(tester, container, const NowPlayingScreen());
      final volume = find.byKey(const Key('playback_volume'));
      final speed = find.byKey(const Key('playback_speed'));
      expect(tester.widget<Slider>(volume).value, 0);
      expect(tester.widget<Slider>(speed).value, 1.5);
      tester.widget<Slider>(volume).onChanged!(1);
      tester.widget<Slider>(speed).onChanged!(1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(audio.volume, 1);
      expect(audio.speed, 1);
      expect(settings.volume, 1);
      expect(settings.playbackSpeed, 1);
    },
  );

  regressionWidgets(
    'visualizer retains immutable frames and returns to its paused baseline',
    (tester) async {
      final container = setupPlayback();
      await container.read(playbackProvider.notifier).playSong(_songA);
      await mount(
        tester,
        container,
        const SizedBox(height: 60, child: AudioVisualizerBars()),
      );
      final finder = find.descendant(
        of: find.byType(AudioVisualizerBars),
        matching: find.byType(CustomPaint),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final before = tester.widget<CustomPaint>(finder).painter!;
      final snapshot = List<double>.from((before as dynamic).barHeights);
      expect(snapshot, isNot(everyElement(2.0)));
      await tester.pump(const Duration(milliseconds: 100));
      expect((before as dynamic).barHeights, snapshot);
      await container.read(playbackProvider.notifier).pause();
      await tester.pump();
      await tester.pump();
      final paused = tester.widget<CustomPaint>(finder).painter!;
      expect((paused as dynamic).barHeights, everyElement(2.0));
      expect(paused.shouldRepaint(before), true);
    },
  );

  regressionWidgets(
    'sleep timer repeated starts, cancel, and disposal never fire stale callbacks',
    (tester) async {
      final timer = SleepTimerNotifier();
      var expired = 0;
      timer.start(const Duration(seconds: 1), () => expired++);
      timer.start(const Duration(seconds: 3), () => expired += 10);
      await tester.pump(const Duration(seconds: 1));
      expect(expired, 0);
      timer.cancel();
      await tester.pump(const Duration(seconds: 4));
      expect(expired, 0);
      timer.start(const Duration(milliseconds: 500), () => expired++);
      await tester.pump(const Duration(milliseconds: 500));
      expect(expired, 1);
      expect(timer.state.isActive, false);
      timer.start(const Duration(seconds: 1), () => expired++);
      timer.dispose();
      await tester.pump(const Duration(seconds: 2));
      expect(expired, 1);
    },
  );

  for (final count in [0, 1, 100]) {
    regressionWidgets(
      'song actions reach the last destination among $count playlists',
      (tester) async {
        final playlists = FakePlaylistRepository(_playlists(count));
        final container = setupPlayback(playlists: playlists);
        await mount(
          tester,
          container,
          Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showSongActionsSheet(context, ref, _songA),
                child: const Text('Actions'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Actions'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (count == 0) {
          expect(find.text('Create playlist').hitTestable(), findsOneWidget);
        } else {
          final destination = find.text('Playlist ${count - 1}');
          await tester.ensureVisible(destination);
          await tester.pumpAndSettle();
          expect(destination.hitTestable(), findsOneWidget);
          await tester.tap(destination);
          await tester.pumpAndSettle();
          expect(playlists.entries.last.songs, [_songA]);
        }
      },
    );
  }

  for (final brightness in Brightness.values) {
    regressionWidgets(
      'saved High Contrast removes all home glass in $brightness',
      (tester) async {
        final settings = FakeSettingsRepository()..highContrast = true;
        final container = setupPlayback(settings: settings);
        await container.read(settingsProvider.notifier).load();
        await mount(
          tester,
          container,
          const HomeScreen(),
          brightness: brightness,
        );
        expect(find.byType(BackdropFilter), findsNothing);
        await container.read(settingsProvider.notifier).toggleHighContrast();
        await tester.pump();
        expect(find.byType(BackdropFilter), findsWidgets);
      },
    );
  }

  regressionWidgets(
    'unsupported effects and placeholder actions are unavailable',
    (tester) async {
      final settings = FakeSettingsRepository()..crossfadeEnabled = true;
      final container = setupPlayback(settings: settings);
      await container.read(settingsProvider.notifier).load();
      await mount(tester, container, const SettingsScreen());
      expect(
        find.text('Unavailable with the current audio engine'),
        findsOneWidget,
      );
      expect(find.text('Crossfade Tracks'), findsNothing);
      await mount(tester, container, const EqualizerScreen());
      expect(
        find.text('Equalizer is unavailable with the current audio engine.'),
        findsOneWidget,
      );
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(Switch), findsNothing);
      await mount(tester, container, const NowPlayingScreen());
      expect(find.byIcon(Icons.share_rounded), findsNothing);
      expect(find.byIcon(Icons.lyrics_rounded), findsNothing);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Equalizer'), findsNothing);
    },
  );

  test(
    'multi-disc and untagged album tracks sort without changing the songs library',
    () async {
      final repo = MusicRepositoryImpl(
        deviceLibrary: _AlbumLibrary(tracks: [2002, 0, 1002, 2001, 1001, -1]),
        useNativeLibrary: true,
      );
      final before = await repo.getSongs();
      final tracks = await repo.getSongsByAlbum(10);
      expect(tracks.map((song) => song.trackNumber), [
        1001,
        1002,
        2001,
        2002,
        0,
        -1,
      ]);
      expect(await repo.getSongs(), before);
    },
  );
}
