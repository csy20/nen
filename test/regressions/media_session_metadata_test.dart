import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/nen_audio_handler.dart';
import 'package:nen/domain/entities/entities.dart';

import '../support/repositories.dart';

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

class _DelayedArtwork extends FakeMusicRepository {
  _DelayedArtwork() : super(const [_songA, _songB]);
  final artwork = {1: Completer<Uint8List?>(), 2: Completer<Uint8List?>()};

  @override
  Future<Uint8List?> getAlbumArt(int songId, {int size = 96}) =>
      artwork[songId]!.future;
}

class _DecodedAudio extends FakeAudioRepository {
  @override
  Duration get currentDuration => const Duration(minutes: 3, seconds: 21);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late _DelayedArtwork library;
  late NenAudioHandler handler;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('nen-metadata-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temporary.path,
        );
    library = _DelayedArtwork();
    handler = NenAudioHandler(_DecodedAudio(), musicRepo: library);
  });
  tearDown(() async {
    await handler.teardown();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temporary.delete(recursive: true);
  });

  test(
    'late artwork still attaches after pause and preserves decoded duration',
    () async {
      await handler.playSong(
        _songA,
        queue: const [_songA, _songA],
        queueIndex: 1,
      );
      await handler.pause();
      final attached = handler.mediaItem.firstWhere(
        (item) => item?.artUri != null,
      );
      library.artwork[1]!.complete(Uint8List.fromList([1, 2, 3]));
      final item = await attached.timeout(const Duration(seconds: 2));
      expect(item!.duration, const Duration(minutes: 3, seconds: 21));
      expect(item.artUri!.scheme, 'file');
      expect(handler.queue.value[1].artUri, item.artUri);
      expect(handler.queue.value[1].duration, item.duration);
      expect(handler.queue.value[0].artUri, isNull);
      expect(handler.playbackState.value.playing, false);
    },
  );

  test(
    'superseded artwork cannot overwrite the selected queue occurrence',
    () async {
      await handler.playSong(_songA, queue: const [_songA, _songB]);
      await handler.playSong(
        _songB,
        queue: const [_songA, _songB],
        queueIndex: 1,
      );
      final attached = handler.mediaItem.firstWhere(
        (item) => item?.artUri != null,
      );
      library.artwork[2]!.complete(Uint8List.fromList([4, 5, 6]));
      final current = await attached.timeout(const Duration(seconds: 2));
      library.artwork[1]!.complete(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value, current);
      expect(handler.queue.value[1].extras?['songId'], 2);
      expect(handler.queue.value[1].artUri, current!.artUri);
      expect(handler.queue.value[0].artUri, isNull);
      expect(
        await File('${temporary.path}/nen_notif_art_1.jpg').exists(),
        false,
      );
    },
  );
}
