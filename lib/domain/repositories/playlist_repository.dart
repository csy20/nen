import '../entities/entities.dart';

/// Contract for playlist persistence.
abstract class PlaylistRepository {
  Future<List<Playlist>> getPlaylists();
  Future<Playlist> createPlaylist(String name);
  Future<void> deletePlaylist(String id);
  Future<Playlist> addSongToPlaylist(String playlistId, Song song);
  Future<Playlist> removeSongFromPlaylist(String playlistId, int songId);
  Future<Playlist> reorderPlaylist(String playlistId, int oldIndex, int newIndex);
  Future<void> renamePlaylist(String id, String newName);
}
