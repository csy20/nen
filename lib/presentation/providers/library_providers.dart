import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'di_providers.dart';

// ── Songs ───────────────────────────────────────────────────────────

final songsProvider = FutureProvider<List<Song>>((ref) {
  return ref.watch(getSongsUseCaseProvider)();
});

// ── Albums ──────────────────────────────────────────────────────────

final albumsProvider = FutureProvider<List<Album>>((ref) {
  return ref.watch(getAlbumsUseCaseProvider)();
});

// ── Artists ─────────────────────────────────────────────────────────

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  return ref.watch(getArtistsUseCaseProvider)();
});

// ── Songs by Album ─────────────────────────────────────────────────

final songsByAlbumProvider =
    FutureProvider.family<List<Song>, int>((ref, albumId) {
  return ref.watch(getSongsByAlbumUseCaseProvider)(albumId);
});

// ── Songs by Artist ────────────────────────────────────────────────

final songsByArtistProvider =
    FutureProvider.family<List<Song>, int>((ref, artistId) {
  return ref.watch(getSongsByArtistUseCaseProvider)(artistId);
});

// ── Search ─────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<List<Song>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return Future.value([]);
  return ref.watch(searchSongsUseCaseProvider)(query);
});

// ── Album Art Cache ────────────────────────────────────────────────

final albumArtProvider = FutureProvider.family<dynamic, int>((ref, songId) {
  return ref.watch(musicRepositoryProvider).getAlbumArt(songId);
});
