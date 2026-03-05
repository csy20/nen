import 'package:flutter_test/flutter_test.dart';
import 'package:nen/domain/entities/entities.dart';

void main() {
  group('Song', () {
    test('equality is based on id', () {
      const song1 = Song(
        id: 1,
        title: 'Test Song',
        artist: 'Artist',
        album: 'Album',
        albumId: 10,
        duration: Duration(minutes: 3),
        filePath: '/path/to/song.mp3',
      );
      const song2 = Song(
        id: 1,
        title: 'Different Title',
        artist: 'Different',
        album: 'Different',
        albumId: 20,
        duration: Duration(minutes: 4),
        filePath: '/other/path.mp3',
      );
      const song3 = Song(
        id: 2,
        title: 'Test Song',
        artist: 'Artist',
        album: 'Album',
        albumId: 10,
        duration: Duration(minutes: 3),
        filePath: '/path/to/song.mp3',
      );

      expect(song1, equals(song2));
      expect(song1, isNot(equals(song3)));
      expect(song1.hashCode, equals(song2.hashCode));
    });

    test('copyWith creates new instance with modified fields', () {
      const original = Song(
        id: 1,
        title: 'Original',
        artist: 'Artist',
        album: 'Album',
        albumId: 10,
        duration: Duration(minutes: 3),
        filePath: '/path.mp3',
        trackNumber: 1,
        year: 2024,
      );

      final copied = original.copyWith(title: 'Modified', year: 2025);

      expect(copied.title, 'Modified');
      expect(copied.year, 2025);
      expect(copied.id, original.id);
      expect(copied.artist, original.artist);
      expect(copied.filePath, original.filePath);
    });
  });

  group('Album', () {
    test('creates with required fields', () {
      const album = Album(
        id: 1,
        name: 'Test Album',
        artist: 'Test Artist',
        songCount: 12,
      );

      expect(album.id, 1);
      expect(album.name, 'Test Album');
      expect(album.songCount, 12);
    });
  });

  group('Artist', () {
    test('creates with required fields', () {
      const artist = Artist(
        id: 1,
        name: 'Test Artist',
        albumCount: 3,
        songCount: 30,
      );

      expect(artist.id, 1);
      expect(artist.name, 'Test Artist');
      expect(artist.albumCount, 3);
      expect(artist.songCount, 30);
    });
  });

  group('FrequencyBands', () {
    test('zero factory produces all zeros', () {
      final bands = FrequencyBands.zero;

      expect(bands.subBass, 0.0);
      expect(bands.bass, 0.0);
      expect(bands.lowMid, 0.0);
      expect(bands.mid, 0.0);
      expect(bands.upperMid, 0.0);
      expect(bands.presence, 0.0);
      expect(bands.brilliance, 0.0);
    });

    test('creates with specific values', () {
      const bands = FrequencyBands(
        subBass: 0.1,
        bass: 0.2,
        lowMid: 0.3,
        mid: 0.4,
        upperMid: 0.5,
        presence: 0.6,
        brilliance: 0.7,
      );

      expect(bands.subBass, 0.1);
      expect(bands.brilliance, 0.7);
    });
  });

  group('PlaybackState', () {
    test('default values', () {
      const state = PlaybackState();

      expect(state.currentSong, isNull);
      expect(state.queue, isEmpty);
      expect(state.queueIndex, 0);
      expect(state.isPlaying, false);
      expect(state.position, Duration.zero);
      expect(state.duration, Duration.zero);
      expect(state.volume, 1.0);
      expect(state.repeatMode, NenRepeatMode.off);
      expect(state.shuffleMode, ShuffleMode.off);
    });

    test('copyWith preserves unmodified fields', () {
      const original = PlaybackState(
        isPlaying: false,
        volume: 0.8,
        repeatMode: NenRepeatMode.all,
      );

      final modified = original.copyWith(isPlaying: true);

      expect(modified.isPlaying, true);
      expect(modified.volume, 0.8);
      expect(modified.repeatMode, NenRepeatMode.all);
    });

    test('copyWith modifies all fields', () {
      const song = Song(
        id: 1,
        title: 'Test',
        artist: 'Artist',
        album: 'Album',
        albumId: 1,
        duration: Duration(minutes: 3),
        filePath: '/path.mp3',
      );

      final state = const PlaybackState().copyWith(
        currentSong: song,
        isPlaying: true,
        volume: 0.5,
        repeatMode: NenRepeatMode.one,
        shuffleMode: ShuffleMode.on,
        position: const Duration(seconds: 30),
        duration: const Duration(minutes: 3),
      );

      expect(state.currentSong, song);
      expect(state.isPlaying, true);
      expect(state.volume, 0.5);
      expect(state.repeatMode, NenRepeatMode.one);
      expect(state.shuffleMode, ShuffleMode.on);
      expect(state.position, const Duration(seconds: 30));
    });
  });

  group('Playlist', () {
    test('creates and copies with songs', () {
      const song = Song(
        id: 1,
        title: 'Song 1',
        artist: 'Artist',
        album: 'Album',
        albumId: 1,
        duration: Duration(minutes: 3),
        filePath: '/path.mp3',
      );

      final playlist = Playlist(
        id: 'abc-123',
        name: 'My Playlist',
        songs: const [song],
        createdAt: DateTime(2025, 1, 1),
      );

      expect(playlist.songs.length, 1);
      expect(playlist.name, 'My Playlist');

      final renamed = playlist.copyWith(name: 'Renamed');
      expect(renamed.name, 'Renamed');
      expect(renamed.songs.length, 1);
      expect(renamed.id, playlist.id);
    });
  });

  group('NenRepeatMode', () {
    test('has correct values', () {
      expect(NenRepeatMode.values.length, 3);
      expect(NenRepeatMode.off.index, 0);
      expect(NenRepeatMode.one.index, 1);
      expect(NenRepeatMode.all.index, 2);
    });

    test('cycling through modes', () {
      final modes = NenRepeatMode.values;
      var current = NenRepeatMode.off;

      current = modes[(current.index + 1) % modes.length];
      expect(current, NenRepeatMode.one);

      current = modes[(current.index + 1) % modes.length];
      expect(current, NenRepeatMode.all);

      current = modes[(current.index + 1) % modes.length];
      expect(current, NenRepeatMode.off);
    });
  });
}
