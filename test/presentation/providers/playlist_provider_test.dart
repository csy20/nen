import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/playlist_repository.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/playlist_provider.dart';

class _FakePlaylistRepository implements PlaylistRepository {
  final List<Playlist> playlists = [];

  @override
  Future<List<Playlist>> getPlaylists() async => List.of(playlists);

  @override
  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: 'id-$name',
      name: name,
      songs: const [],
      createdAt: DateTime(2026, 1, 1),
    );
    playlists.add(playlist);
    return playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    playlists.removeWhere((p) => p.id == id);
  }

  @override
  Future<Playlist> addSongToPlaylist(String playlistId, Song song) {
    throw UnimplementedError();
  }

  @override
  Future<Playlist> removeSongFromPlaylist(String playlistId, int songId) {
    throw UnimplementedError();
  }

  @override
  Future<Playlist> reorderPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> renamePlaylist(String id, String newName) async {}

  @override
  Future<Playlist> replacePlaylistSongs(
    String playlistId,
    List<Song> songs,
  ) async {
    final index = playlists.indexWhere((p) => p.id == playlistId);
    final updated = playlists[index].copyWith(songs: songs);
    playlists[index] = updated;
    return updated;
  }
}

const _song = Song(
  id: 1,
  title: 'Track',
  artist: 'Artist',
  album: 'Album',
  albumId: 10,
  duration: Duration(minutes: 3),
  filePath: '/music/track.mp3',
  uri: 'content://media/external/audio/media/1',
);

void main() {
  test(
    'importNamed replaces an existing playlist instead of duplicating',
    () async {
      final repo = _FakePlaylistRepository();
      final container = ProviderContainer(
        overrides: [playlistRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final first = await container
          .read(playlistsProvider.notifier)
          .importNamed('Workout', const [_song]);
      final second = await container
          .read(playlistsProvider.notifier)
          .importNamed('workout', const [_song]);

      expect(first.id, second.id);
      expect(container.read(playlistsProvider), hasLength(1));
      expect(container.read(playlistsProvider).single.songs, const [_song]);
    },
  );
}
