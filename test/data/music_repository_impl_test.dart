import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/repositories/music_repository_impl.dart';
import 'package:nen/data/services/library_media_store.dart';

class _FakeLibraryMediaStore extends LibraryMediaStore {
  _FakeLibraryMediaStore()
    : super(channel: const MethodChannel('dev.csy20.nen/library.test'));

  List<Map<String, dynamic>> rows = const [];
  Object? error;
  int queryCount = 0;
  int artworkCount = 0;

  @override
  Future<int> sdkInt() async => 33;

  @override
  Future<bool> probe() async => true;

  @override
  Future<List<Map<String, dynamic>>> querySongs() async {
    queryCount++;
    final thrown = error;
    if (thrown != null) throw thrown;
    return rows;
  }

  @override
  Future<Uint8List?> queryArtwork(
    int songId, {
    int size = 96,
    int albumId = 0,
  }) async {
    artworkCount++;
    return Uint8List.fromList(const [1, 2, 3]);
  }
}

Map<String, dynamic> _row({
  int id = 1,
  String title = 'Track',
  String artist = 'Artist',
  String album = 'Album',
  int albumId = 10,
  int artistId = 20,
  int duration = 180000,
  String filePath = '/storage/emulated/0/Music/track.mp3',
  String relativePath = 'Music/',
  String uri = 'content://media/external/audio/media/1',
}) {
  return {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'albumId': albumId,
    'artistId': artistId,
    'duration': duration,
    'filePath': filePath,
    'relativePath': relativePath,
    'uri': uri,
    'fileExtension': 'mp3',
    'fileSize': 1234,
    'trackNumber': 1,
    'year': 2024,
  };
}

void main() {
  group('songFromNativeRow', () {
    test('maps MediaStore rows into Song entities', () {
      final song = songFromNativeRow(_row());
      expect(song.id, 1);
      expect(song.title, 'Track');
      expect(song.artist, 'Artist');
      expect(song.albumId, 10);
      expect(song.artistId, 20);
      expect(song.duration, const Duration(milliseconds: 180000));
      expect(song.fileExtension, 'mp3');
      expect(song.uri, startsWith('content://'));
    });

    test('keeps filePath empty when MediaStore DATA is missing', () {
      final song = songFromNativeRow(
        _row(
          artist: '<unknown>',
          album: '',
          filePath: '',
          relativePath: 'Music/Album/',
          uri: 'content://media/external/audio/media/9',
        ),
      );
      expect(song.artist, 'Unknown Artist');
      expect(song.album, 'Unknown Album');
      expect(song.filePath, isEmpty);
      expect(song.uri, 'content://media/external/audio/media/9');
    });
  });

  group('libraryErrorMessage', () {
    test('hides the Play Store on_audio_query stack', () {
      const crash =
          'PlatformException(error, lateinit property context has not been initialized, null, C1.b: lateinit property context has not been initialized at com.lucasjosino.on_audio_query.PluginProvider.context)';
      expect(libraryErrorMessage(crash), contains('music library'));
      expect(libraryErrorMessage(crash), isNot(contains('lateinit')));
    });

    test('keeps LibraryAccessException text', () {
      const error = LibraryAccessException('Grant audio permission.');
      expect(libraryErrorMessage(error), 'Grant audio permission.');
    });
  });

  group('MusicRepositoryImpl', () {
    test('loads songs from MediaStore and skips ringtones and clips', () async {
      final store = _FakeLibraryMediaStore()
        ..rows = [
          _row(id: 1, title: 'Keep'),
          _row(
            id: 2,
            title: 'Ringtone',
            filePath: '/storage/emulated/0/Ringtones/tone.mp3',
            relativePath: 'Ringtones/',
          ),
          _row(
            id: 3,
            title: 'Short',
            duration: 8000,
            filePath: '/storage/emulated/0/Music/short.mp3',
          ),
        ];
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );

      final songs = await repo.getSongs();
      expect(songs.map((s) => s.title), ['Keep']);
    });

    test('derives albums and artists from the filtered song list', () async {
      final store = _FakeLibraryMediaStore()
        ..rows = [
          _row(id: 1, album: 'A', albumId: 5, artist: 'One', artistId: 8),
          _row(id: 2, album: 'A', albumId: 5, artist: 'One', artistId: 8),
          _row(id: 3, album: 'B', albumId: 6, artist: 'Two', artistId: 9),
        ];
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );

      final albums = await repo.getAlbums();
      expect(albums.map((a) => a.name), ['A', 'B']);
      expect(albums.first.songCount, 2);

      final artists = await repo.getArtists();
      expect(artists.map((a) => a.name), ['One', 'Two']);
      expect((await repo.getSongsByArtist(8)).map((s) => s.id), [1, 2]);
    });

    test(
      'retries uninitialized-context failures then surfaces a safe error',
      () async {
        final store = _FakeLibraryMediaStore()
          ..error = PlatformException(
            code: 'error',
            message: 'lateinit property context has not been initialized',
          );
        final repo = MusicRepositoryImpl(
          deviceLibrary: store,
          useNativeLibrary: true,
        );

        await expectLater(
          repo.getSongs(),
          throwsA(isA<LibraryAccessException>()),
        );
        expect(store.queryCount, 5);
      },
    );

    test(
      'groups unknown album ids by album name instead of collapsing to 0',
      () async {
        final store = _FakeLibraryMediaStore()
          ..rows = [
            _row(id: 1, album: 'One', albumId: 0, artist: 'A', artistId: 0),
            _row(id: 2, album: 'Two', albumId: 0, artist: 'B', artistId: 0),
          ];
        final repo = MusicRepositoryImpl(
          deviceLibrary: store,
          useNativeLibrary: true,
        );

        final albums = await repo.getAlbums();
        expect(albums, hasLength(2));
        expect(albums.map((a) => a.name).toSet(), {'One', 'Two'});
      },
    );

    test('uses relative-path hints for folders when DATA is missing', () async {
      final store = _FakeLibraryMediaStore()
        ..rows = [
          _row(
            id: 1,
            filePath: '',
            relativePath: 'Music/Concert/',
            uri: 'content://media/external/audio/media/1',
          ),
        ];
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );

      expect(await repo.getFolders(), ['Music/Concert']);
      expect((await repo.getSongsByFolder('Music/Concert')).map((s) => s.id), [
        1,
      ]);
    });

    test('retries MissingPluginException before giving up', () async {
      final store = _FakeLibraryMediaStore()
        ..error = MissingPluginException('dev.csy20.nen/library');
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );

      await expectLater(
        repo.getSongs(),
        throwsA(isA<LibraryAccessException>()),
      );
      expect(store.queryCount, 5);
    });

    test('reuses artwork across tracks on the same album', () async {
      final store = _FakeLibraryMediaStore()
        ..rows = [
          _row(id: 1, albumId: 50),
          _row(id: 2, albumId: 50, title: 'B', uri: 'content://media/2'),
        ];
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );
      await repo.getSongs();
      await repo.getAlbumArt(1, size: 96);
      await repo.getAlbumArt(2, size: 96);
      expect(store.artworkCount, 1);
    });

    test('does not retry a permission denial', () async {
      final store = _FakeLibraryMediaStore()
        ..error = PlatformException(
          code: 'permission_denied',
          message: 'denied',
        );
      final repo = MusicRepositoryImpl(
        deviceLibrary: store,
        useNativeLibrary: true,
      );

      await expectLater(
        repo.getSongs(),
        throwsA(
          isA<LibraryAccessException>()
              .having((e) => e.permissionDenied, 'permissionDenied', isTrue)
              .having(
                (e) => e.message,
                'message',
                contains('grant audio permission'),
              ),
        ),
      );
      expect(store.queryCount, 1);
    });
  });
}
