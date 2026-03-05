import 'dart:typed_data';

import '../entities/entities.dart';

/// Contract for querying the device media store.
abstract class MusicRepository {
  Future<List<Song>> getSongs();
  Future<List<Album>> getAlbums();
  Future<List<Artist>> getArtists();
  Future<List<Song>> getSongsByAlbum(int albumId);
  Future<List<Song>> getSongsByArtist(int artistId);
  Future<Uint8List?> getAlbumArt(int songId);
  Future<List<Song>> searchSongs(String query);
}
