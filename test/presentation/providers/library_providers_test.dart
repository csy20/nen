import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/music_repository.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/library_providers.dart';

class _FakeMusicRepository implements MusicRepository {
  int rescanCalls = 0;

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<Uint8List?> getAlbumArt(int songId, {int size = 96}) async => null;

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<List<String>> getFolders() async => const [];

  @override
  Future<List<Song>> getSongs() async => const [];

  @override
  Future<List<Song>> getSongsByAlbum(int albumId) async => const [];

  @override
  Future<List<Song>> getSongsByArtist(int artistId) async => const [];

  @override
  Future<List<Song>> getSongsByFolder(String path) async => const [];

  @override
  Future<void> rescanMedia() async {
    rescanCalls++;
  }

  @override
  Future<List<Song>> searchSongs(String query) async => const [];
}

void main() {
  group('SearchQueryNotifier', () {
    test('debounces search updates', () async {
      final notifier = SearchQueryNotifier();
      addTearDown(notifier.dispose);

      notifier.setQuery('n');
      notifier.setQuery('ne');
      notifier.setQuery('nen');

      expect(notifier.state, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 325));
      expect(notifier.state, 'nen');
    });

    test('clear resets the debounced query immediately', () async {
      final notifier = SearchQueryNotifier();
      addTearDown(notifier.dispose);

      notifier.setQuery('queued');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      notifier.clear();
      await Future<void>.delayed(const Duration(milliseconds: 325));

      expect(notifier.state, isEmpty);
    });

    test('clear is a no-op when already empty', () {
      final notifier = SearchQueryNotifier();
      addTearDown(notifier.dispose);
      notifier.clear();
      expect(notifier.state, isEmpty);
    });
  });

  group('libraryRefreshProvider', () {
    test('refresh rescans media and increments revision', () async {
      final repository = _FakeMusicRepository();
      final container = ProviderContainer(
        overrides: [musicRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      expect(container.read(libraryRefreshProvider), 0);

      await container.read(libraryRefreshProvider.notifier).refresh();

      expect(repository.rescanCalls, 1);
      expect(container.read(libraryRefreshProvider), 1);
    });

    test('refresh can invalidate without rescanning', () async {
      final repository = _FakeMusicRepository();
      final container = ProviderContainer(
        overrides: [musicRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(libraryRefreshProvider.notifier)
          .refresh(rescan: false);

      expect(repository.rescanCalls, 0);
      expect(container.read(libraryRefreshProvider), 1);
    });
  });
}
