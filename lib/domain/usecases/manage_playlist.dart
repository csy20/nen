import '../entities/entities.dart';
import '../repositories/playlist_repository.dart';

class ManagePlaylistUseCase {
  final PlaylistRepository _repository;
  const ManagePlaylistUseCase(this._repository);

  Future<List<Playlist>> getAll() => _repository.getPlaylists();

  Future<Playlist> create(String name) => _repository.createPlaylist(name);

  Future<void> delete(String id) => _repository.deletePlaylist(id);

  Future<Playlist> addSong(String playlistId, Song song) =>
      _repository.addSongToPlaylist(playlistId, song);

  Future<Playlist> removeSong(String playlistId, int songId) =>
      _repository.removeSongFromPlaylist(playlistId, songId);

  Future<Playlist> reorder(String playlistId, int oldIndex, int newIndex) =>
      _repository.reorderPlaylist(playlistId, oldIndex, newIndex);

  Future<void> rename(String id, String newName) =>
      _repository.renamePlaylist(id, newName);
}
