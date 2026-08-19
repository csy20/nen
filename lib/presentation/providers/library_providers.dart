import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../domain/entities/entities.dart';
import '../theme/nen_theme.dart';
import 'di_providers.dart';
import 'playback_provider.dart';

class LibraryRefreshNotifier extends StateNotifier<int> {
  final Ref _ref;

  LibraryRefreshNotifier(this._ref) : super(0);

  Future<void> refresh({bool rescan = true}) async {
    if (rescan) {
      await _ref.read(musicRepositoryProvider).rescanMedia();
    }
    state++;
  }
}

final libraryRefreshProvider =
    StateNotifierProvider<LibraryRefreshNotifier, int>((ref) {
      return LibraryRefreshNotifier(ref);
    });

/// Current playing song ID — extracted from playbackProvider to minimize
/// rebuilds in SongTile (watching a single int vs the full PlaybackState).
final currentSongIdProvider = Provider<int?>((ref) {
  return ref.watch(playbackProvider.select((s) => s.currentSong?.id));
});

// ── Songs ───────────────────────────────────────────────────────────

final songsProvider = FutureProvider<List<Song>>((ref) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(getSongsUseCaseProvider)();
});

// ── Albums ──────────────────────────────────────────────────────────

final albumsProvider = FutureProvider<List<Album>>((ref) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(getAlbumsUseCaseProvider)();
});

// ── Artists ─────────────────────────────────────────────────────────

final artistsProvider = FutureProvider<List<Artist>>((ref) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(getArtistsUseCaseProvider)();
});

// ── Songs by Album ─────────────────────────────────────────────────

final songsByAlbumProvider = FutureProvider.family<List<Song>, int>((
  ref,
  albumId,
) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(getSongsByAlbumUseCaseProvider)(albumId);
});

// ── Songs by Artist ────────────────────────────────────────────────

final songsByArtistProvider = FutureProvider.family<List<Song>, int>((
  ref,
  artistId,
) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(getSongsByArtistUseCaseProvider)(artistId);
});

// ── Search ─────────────────────────────────────────────────────────

class SearchQueryNotifier extends StateNotifier<String> {
  SearchQueryNotifier() : super('');

  static const _debounceDuration = Duration(milliseconds: 300);

  Timer? _debounce;
  String _rawQuery = '';

  void setQuery(String query) {
    if (query == _rawQuery) {
      return;
    }

    _rawQuery = query;
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      state = '';
      return;
    }

    _debounce = Timer(_debounceDuration, () {
      state = query.trim();
    });
  }

  void clear() {
    _rawQuery = '';
    _debounce?.cancel();
    state = '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchQueryProvider = StateNotifierProvider<SearchQueryNotifier, String>((
  _,
) {
  return SearchQueryNotifier();
});

final searchResultsProvider = FutureProvider<List<Song>>((ref) {
  ref.watch(libraryRefreshProvider);
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return Future.value([]);
  return ref.watch(searchSongsUseCaseProvider)(query);
});

// ── Album Art Cache ────────────────────────────────────────────────

final albumArtProvider = FutureProvider.autoDispose.family<Uint8List?, int>((
  ref,
  songId,
) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(musicRepositoryProvider).getAlbumArt(songId);
});

final songAccentColorProvider = FutureProvider.autoDispose.family<Color, int>((
  ref,
  songId,
) async {
  final art = await ref.watch(albumArtProvider(songId).future);
  if (art == null || art.isEmpty) {
    return NenTheme.defaultAccent;
  }

  final palette = await PaletteGenerator.fromImageProvider(
    MemoryImage(art),
    maximumColorCount: 8,
  );

  return palette.dominantColor?.color ??
      palette.vibrantColor?.color ??
      NenTheme.defaultAccent;
});

// ── Folders ────────────────────────────────────────────────────────

final foldersProvider = FutureProvider<List<String>>((ref) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(musicRepositoryProvider).getFolders();
});

final songsByFolderProvider = FutureProvider.family<List<Song>, String>((
  ref,
  path,
) {
  ref.watch(libraryRefreshProvider);
  return ref.watch(musicRepositoryProvider).getSongsByFolder(path);
});
