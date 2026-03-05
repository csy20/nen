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

  Future<void> create(String name) async {
    await _ref.read(managePlaylistUseCaseProvider).create(name);
    await load();
  }

  Future<void> delete(String id) async {
    await _ref.read(managePlaylistUseCaseProvider).delete(id);
    await load();
  }

  Future<void> addSong(String playlistId, Song song) async {
    await _ref.read(managePlaylistUseCaseProvider).addSong(playlistId, song);
    await load();
  }

  Future<void> removeSong(String playlistId, int songId) async {
    await _ref
        .read(managePlaylistUseCaseProvider)
        .removeSong(playlistId, songId);
    await load();
  }

  Future<void> rename(String id, String newName) async {
    await _ref.read(managePlaylistUseCaseProvider).rename(id, newName);
    await load();
  }
}

final playlistsProvider =
    StateNotifierProvider<PlaylistNotifier, List<Playlist>>((ref) {
  return PlaylistNotifier(ref);
});
