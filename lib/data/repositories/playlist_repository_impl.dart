import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/playlist_repository.dart';

/// Implementation of [PlaylistRepository] using SharedPreferences.
class PlaylistRepositoryImpl implements PlaylistRepository {
  static const _key = 'playlists_v1';
  final Uuid _uuid = const Uuid();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<Playlist>> getPlaylists() async {
    final prefs = await _prefs;
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((json) => _decode(json)).toList();
  }

  @override
  Future<Playlist> createPlaylist(String name) async {
    final playlists = await getPlaylists();
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      songs: const [],
      createdAt: DateTime.now(),
    );
    playlists.add(playlist);
    await _save(playlists);
    return playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final playlists = await getPlaylists();
    playlists.removeWhere((p) => p.id == id);
    await _save(playlists);
  }

  @override
  Future<Playlist> addSongToPlaylist(String playlistId, Song song) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) throw Exception('Playlist not found');

    final playlist = playlists[index];
    if (playlist.songs.any((s) => s.id == song.id)) return playlist;

    final updated = playlist.copyWith(
      songs: [...playlist.songs, song],
    );
    playlists[index] = updated;
    await _save(playlists);
    return updated;
  }

  @override
  Future<Playlist> removeSongFromPlaylist(
      String playlistId, int songId) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) throw Exception('Playlist not found');

    final playlist = playlists[index];
    final updated = playlist.copyWith(
      songs: playlist.songs.where((s) => s.id != songId).toList(),
    );
    playlists[index] = updated;
    await _save(playlists);
    return updated;
  }

  @override
  Future<Playlist> reorderPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);
    if (index == -1) throw Exception('Playlist not found');

    final playlist = playlists[index];
    final songs = List<Song>.from(playlist.songs);
    final item = songs.removeAt(oldIndex);
    songs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);

    final updated = playlist.copyWith(songs: songs);
    playlists[index] = updated;
    await _save(playlists);
    return updated;
  }

  @override
  Future<void> renamePlaylist(String id, String newName) async {
    final playlists = await getPlaylists();
    final index = playlists.indexWhere((p) => p.id == id);
    if (index == -1) throw Exception('Playlist not found');

    playlists[index] = playlists[index].copyWith(name: newName);
    await _save(playlists);
  }

  // ── Serialization ──────────────────────────────────────────────────

  Future<void> _save(List<Playlist> playlists) async {
    final prefs = await _prefs;
    final raw = playlists.map((p) => _encode(p)).toList();
    await prefs.setStringList(_key, raw);
  }

  String _encode(Playlist p) => jsonEncode({
        'id': p.id,
        'name': p.name,
        'createdAt': p.createdAt.toIso8601String(),
        'songs': p.songs.map(_encodeSong).toList(),
      });

  Map<String, dynamic> _encodeSong(Song s) => {
        'id': s.id,
        'title': s.title,
        'artist': s.artist,
        'album': s.album,
        'albumId': s.albumId,
        'duration': s.duration.inMilliseconds,
        'filePath': s.filePath,
        'trackNumber': s.trackNumber,
        'year': s.year,
      };

  Playlist _decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      songs: (map['songs'] as List)
          .map((s) => _decodeSong(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Song _decodeSong(Map<String, dynamic> m) => Song(
        id: m['id'] as int,
        title: m['title'] as String,
        artist: m['artist'] as String,
        album: m['album'] as String,
        albumId: m['albumId'] as int,
        duration: Duration(milliseconds: m['duration'] as int),
        filePath: m['filePath'] as String,
        trackNumber: m['trackNumber'] as int? ?? 0,
        year: m['year'] as int? ?? 0,
      );
}
