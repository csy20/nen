import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/playlist_repository.dart';

/// Implementation of [PlaylistRepository] backed by SQLite.
class PlaylistRepositoryImpl implements PlaylistRepository {
  static const _databaseName = 'nen_playlists.db';
  static const _databaseVersion = 1;
  static const _legacyKey = 'playlists_v1';
  static const _migrationKey = 'playlists_sqlite_migrated_v1';

  final Uuid _uuid = const Uuid();
  Database? _database;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, _databaseName);
    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_songs (
            playlist_id TEXT NOT NULL,
            song_order INTEGER NOT NULL,
            song_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            album_id INTEGER NOT NULL,
            duration_ms INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            track_number INTEGER NOT NULL,
            year INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, song_order)
          )
        ''');
      },
    );
    return _database!;
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final db = await _readyDb();
    final rows = await db.query('playlists', orderBy: 'created_at DESC');

    final playlists = <Playlist>[];
    for (final row in rows) {
      playlists.add(await _mapPlaylist(db, row));
    }
    return playlists;
  }

  @override
  Future<Playlist> createPlaylist(String name) async {
    final db = await _readyDb();
    final playlist = Playlist(
      id: _uuid.v4(),
      name: name,
      songs: const [],
      createdAt: DateTime.now(),
    );
    await _insertPlaylist(db, playlist);
    return playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final db = await _readyDb();
    await db.transaction((txn) async {
      await txn.delete(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [id],
      );
      await txn.delete('playlists', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<Playlist> addSongToPlaylist(String playlistId, Song song) async {
    final db = await _readyDb();
    return db.transaction((txn) async {
      final existing = await txn.query(
        'playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, song.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return _getPlaylistById(txn, playlistId);
      }

      final nextOrder =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COALESCE(MAX(song_order), -1) + 1 FROM playlist_songs WHERE playlist_id = ?',
              [playlistId],
            ),
          ) ??
          0;

      await _insertSong(txn, playlistId, song, nextOrder);
      return _getPlaylistById(txn, playlistId);
    });
  }

  @override
  Future<Playlist> removeSongFromPlaylist(String playlistId, int songId) async {
    final db = await _readyDb();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'song_order ASC',
      );
      final songs = rows
          .map(_mapSongRow)
          .where((song) => song.id != songId)
          .toList();
      await _rewritePlaylistSongs(txn, playlistId, songs);
      return _getPlaylistById(txn, playlistId);
    });
  }

  @override
  Future<Playlist> reorderPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final db = await _readyDb();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
        orderBy: 'song_order ASC',
      );
      final songs = rows.map(_mapSongRow).toList();
      final item = songs.removeAt(oldIndex);
      songs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
      await _rewritePlaylistSongs(txn, playlistId, songs);
      return _getPlaylistById(txn, playlistId);
    });
  }

  @override
  Future<void> renamePlaylist(String id, String newName) async {
    final db = await _readyDb();
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Database> _readyDb() async {
    final db = await _db;
    await _migrateLegacyPlaylists(db);
    return db;
  }

  Future<void> _migrateLegacyPlaylists(Database db) async {
    final prefs = await _prefs;
    if (prefs.getBool(_migrationKey) ?? false) {
      return;
    }

    final legacy = prefs.getStringList(_legacyKey) ?? const <String>[];
    if (legacy.isEmpty) {
      await prefs.setBool(_migrationKey, true);
      return;
    }

    final existingCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM playlists'),
        ) ??
        0;
    if (existingCount > 0) {
      await prefs.setBool(_migrationKey, true);
      return;
    }

    await db.transaction((txn) async {
      for (final raw in legacy) {
        await _insertPlaylist(txn, _decode(raw));
      }
    });

    await prefs.setBool(_migrationKey, true);
  }

  Future<void> _insertPlaylist(DatabaseExecutor db, Playlist playlist) async {
    await db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'created_at': playlist.createdAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _rewritePlaylistSongs(db, playlist.id, playlist.songs);
  }

  Future<void> _rewritePlaylistSongs(
    DatabaseExecutor db,
    String playlistId,
    List<Song> songs,
  ) async {
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );

    for (var index = 0; index < songs.length; index++) {
      await _insertSong(db, playlistId, songs[index], index);
    }
  }

  Future<void> _insertSong(
    DatabaseExecutor db,
    String playlistId,
    Song song,
    int order,
  ) async {
    await db.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_order': order,
      'song_id': song.id,
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'album_id': song.albumId,
      'duration_ms': song.duration.inMilliseconds,
      'file_path': song.filePath,
      'track_number': song.trackNumber,
      'year': song.year,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Playlist> _getPlaylistById(
    DatabaseExecutor db,
    String playlistId,
  ) async {
    final rows = await db.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [playlistId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Playlist not found');
    }
    return _mapPlaylist(db, rows.first);
  }

  Future<Playlist> _mapPlaylist(
    DatabaseExecutor db,
    Map<String, Object?> row,
  ) async {
    final songs = await db.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [row['id']],
      orderBy: 'song_order ASC',
    );

    return Playlist(
      id: row['id']! as String,
      name: row['name']! as String,
      createdAt: DateTime.parse(row['created_at']! as String),
      songs: songs.map(_mapSongRow).toList(),
    );
  }

  Song _mapSongRow(Map<String, Object?> row) => Song(
    id: row['song_id']! as int,
    title: row['title']! as String,
    artist: row['artist']! as String,
    album: row['album']! as String,
    albumId: row['album_id']! as int,
    duration: Duration(milliseconds: row['duration_ms']! as int),
    filePath: row['file_path']! as String,
    trackNumber: row['track_number']! as int,
    year: row['year']! as int,
  );

  Playlist _decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      songs: (map['songs'] as List<dynamic>)
          .map((song) => _decodeSong(song as Map<String, dynamic>))
          .toList(),
    );
  }

  Song _decodeSong(Map<String, dynamic> map) => Song(
    id: map['id'] as int,
    title: map['title'] as String,
    artist: map['artist'] as String,
    album: map['album'] as String,
    albumId: map['albumId'] as int,
    duration: Duration(milliseconds: map['duration'] as int),
    filePath: map['filePath'] as String,
    trackNumber: map['trackNumber'] as int? ?? 0,
    year: map['year'] as int? ?? 0,
  );
}
