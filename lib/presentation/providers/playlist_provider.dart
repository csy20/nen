import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import 'di_providers.dart';

/// Manages the list of playlists.
class PlaylistNotifier extends StateNotifier<List<Playlist>> {
  final Ref _ref;

  PlaylistNotifier(this._ref) : super(const []);

  Future<void> load() async {
    state = await _ref.read(managePlaylistUseCaseProvider).getAll();
  }

  Future<Playlist> create(String name) async {
    final playlist = await _ref
        .read(managePlaylistUseCaseProvider)
        .create(name);
    state = [...state, playlist];
    return playlist;
  }

  Future<void> delete(String id) async {
    await _ref.read(managePlaylistUseCaseProvider).delete(id);
    state = state.where((p) => p.id != id).toList();
  }

  Future<void> addSong(String playlistId, Song song) async {
    final updated = await _ref
        .read(managePlaylistUseCaseProvider)
        .addSong(playlistId, song);
    state = state.map((p) => p.id == playlistId ? updated : p).toList();
  }

  Future<void> removeSong(String playlistId, int songId) async {
    final updated = await _ref
        .read(managePlaylistUseCaseProvider)
        .removeSong(playlistId, songId);
    state = state.map((p) => p.id == playlistId ? updated : p).toList();
  }

  Future<void> rename(String id, String newName) async {
    await _ref.read(managePlaylistUseCaseProvider).rename(id, newName);
    state = state
        .map((p) => p.id == id ? p.copyWith(name: newName) : p)
        .toList();
  }

  /// Create or replace a playlist of [name] so re-import is not a duplicate.
  Future<Playlist> importNamed(String name, List<Song> songs) async {
    final trimmed = name.trim();
    Playlist? existing;
    for (final playlist in state) {
      if (playlist.name.toLowerCase() == trimmed.toLowerCase()) {
        existing = playlist;
        break;
      }
    }
    final target = existing ?? await create(trimmed);
    final updated = await _ref
        .read(managePlaylistUseCaseProvider)
        .replaceSongs(target.id, songs);
    state = [for (final p in state) p.id == target.id ? updated : p];
    return updated;
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistNotifier, List<Playlist>>((ref) {
      return PlaylistNotifier(ref);
    });
