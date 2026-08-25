import 'dart:collection';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/audio/audio_format.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';
import '../services/library_media_store.dart';

const _excludedPathSegments = [
  '/Call/',
  '/CallRecordings/',
  '/Call Recordings/',
  '/Recordings/',
  '/Voice Recorder/',
  '/VoiceRecorder/',
  '/Sounds/',
  '/Ringtones/',
  '/Notifications/',
  '/Alarms/',
];

const _minDurationMs = 30000;

class MusicRepositoryImpl implements MusicRepository {
  final OnAudioQuery _audioQuery;
  final LibraryMediaStore _deviceLibrary;
  final bool _useNativeLibrary;
  final LinkedHashMap<String, Uint8List?> _albumArtCache =
      LinkedHashMap<String, Uint8List?>();
  static const int _maxAlbumArtCacheSize = 256;
  final Map<String, Future<Uint8List?>> _albumArtRequests =
      <String, Future<Uint8List?>>{};
  List<Song>? _songsCache;
  Future<List<Song>>? _songsRequest;
  final Map<int, String> _folderHints = <int, String>{};
  int _loadGeneration = 0;
  bool _waitedForFrame = false;

  MusicRepositoryImpl({
    OnAudioQuery? audioQuery,
    LibraryMediaStore? deviceLibrary,
    bool? useNativeLibrary,
  }) : _audioQuery = audioQuery ?? OnAudioQuery(),
       _deviceLibrary = deviceLibrary ?? LibraryMediaStore(),
       _useNativeLibrary = useNativeLibrary ?? Platform.isAndroid;

  bool _isMusicSong(Song song, {String relativePath = ''}) {
    if (song.duration.inMilliseconds < _minDurationMs) return false;
    final haystack = '${song.filePath}/$relativePath/${song.uri}'.replaceAll(
      '\\',
      '/',
    );
    for (final segment in _excludedPathSegments) {
      if (haystack.contains(segment)) return false;
    }
    return true;
  }

  @override
  Future<List<Song>> getSongs() => _queryAllSongs();

  int _albumKey(Song song) {
    if (song.albumId != 0) return song.albumId;
    return Object.hash(song.album, song.artist);
  }

  int _artistKey(Song song) {
    if (song.artistId != 0) return song.artistId;
    return song.artist.hashCode;
  }

  @override
  Future<List<Album>> getAlbums() async {
    final songs = await _queryAllSongs();
    final grouped = <int, List<Song>>{};
    for (final song in songs) {
      grouped.putIfAbsent(_albumKey(song), () => []).add(song);
    }
    final albums = grouped.entries.map((entry) {
      final tracks = entry.value;
      final first = tracks.first;
      return Album(
        id: entry.key,
        name: first.album,
        artist: first.artist,
        songCount: tracks.length,
        year: first.year,
      );
    }).toList();
    albums.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return albums;
  }

  @override
  Future<List<Artist>> getArtists() async {
    final songs = await _queryAllSongs();
    final grouped = <int, List<Song>>{};
    for (final song in songs) {
      grouped.putIfAbsent(_artistKey(song), () => []).add(song);
    }
    final artists = grouped.entries.map((entry) {
      final tracks = entry.value;
      final albums = tracks.map((s) => s.albumId).toSet();
      return Artist(
        id: entry.key,
        name: tracks.first.artist,
        albumCount: albums.length,
        songCount: tracks.length,
      );
    }).toList();
    artists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return artists;
  }

  @override
  Future<List<Song>> getSongsByAlbum(int albumId) async {
    final songs = await _queryAllSongs();
    return songs.where((s) => _albumKey(s) == albumId).toList();
  }

  @override
  Future<List<Song>> getSongsByArtist(int artistId) async {
    final songs = await _queryAllSongs();
    return songs.where((s) => _artistKey(s) == artistId).toList();
  }

  @override
  Future<Uint8List?> getAlbumArt(int songId, {int size = 96}) async {
    final albumId = _songsCache
        ?.where((s) => s.id == songId)
        .map((s) => s.albumId)
        .firstOrNull;
    final key = albumId != null && albumId != 0
        ? 'a$albumId:$size'
        : 's$songId:$size';
    if (_albumArtCache.containsKey(key)) {
      _touchCache(key);
      return _albumArtCache[key];
    }

    final inFlight = _albumArtRequests[key];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _loadArtwork(songId, size, albumId ?? 0).then(
      (art) {
        _addToCache(key, art);
        _albumArtRequests.remove(key);
        return art;
      },
      onError: (Object error, StackTrace stack) {
        _albumArtRequests.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );

    _albumArtRequests[key] = request;
    return request;
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    final all = await getSongs();
    final q = query.toLowerCase();
    return all
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
  }

  String? _folderOf(Song song) {
    final filePath = song.filePath.replaceAll('\\', '/');
    if (filePath.startsWith('/')) {
      final lastSlash = filePath.lastIndexOf('/');
      if (lastSlash > 0) return filePath.substring(0, lastSlash);
    }
    final hint = _folderHints[song.id];
    if (hint == null || hint.isEmpty) return null;
    return hint.replaceAll(RegExp(r'/+$'), '');
  }

  @override
  Future<List<String>> getFolders() async {
    final songs = await _queryAllSongs();
    final folders = <String>{};
    for (final s in songs) {
      final folder = _folderOf(s);
      if (folder != null && folder.isNotEmpty) {
        folders.add(folder);
      }
    }
    final sorted = folders.toList()..sort();
    return sorted;
  }

  @override
  Future<List<Song>> getSongsByFolder(String path) async {
    final songs = await _queryAllSongs();
    return songs.where((s) => _folderOf(s) == path).toList();
  }

  @override
  Future<void> rescanMedia() async {
    _loadGeneration++;
    _songsCache = null;
    _songsRequest = null;
    _folderHints.clear();
    _albumArtCache.clear();
    _albumArtRequests.clear();
  }

  Future<List<Song>> _queryAllSongs() {
    final cache = _songsCache;
    if (cache != null) {
      return Future.value(cache);
    }

    final inFlight = _songsRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final generation = _loadGeneration;
    final request = _loadSongsWithRetry().then(
      (songs) {
        if (generation == _loadGeneration) {
          _songsCache = songs;
          _songsRequest = null;
        }
        return songs;
      },
      onError: (Object error, StackTrace stack) {
        if (generation == _loadGeneration) {
          _songsRequest = null;
        }
        Error.throwWithStackTrace(error, stack);
      },
    );

    _songsRequest = request;
    return request;
  }

  Future<List<Song>> _loadSongsWithRetry() async {
    if (_useNativeLibrary) {
      await _ensureNativeChannel();
      Object? lastError;
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          return await _loadSongsFromNative();
        } on PlatformException catch (error) {
          if (error.code == 'permission_denied') {
            throw const LibraryAccessException(
              'Could not access your music library. Pull to retry, or grant audio permission in system settings.',
              permissionDenied: true,
            );
          }
          lastError = error;
        } on MissingPluginException catch (error) {
          lastError = error;
        }
        if (attempt == 4) break;
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
      throw _wrapLibraryError(lastError ?? 'Unknown library error');
    }

    try {
      return await _loadSongsFromOnAudioQuery();
    } catch (error) {
      throw _wrapLibraryError(error);
    }
  }

  Future<void> _ensureNativeChannel() async {
    if (!_waitedForFrame) {
      _waitedForFrame = true;
      try {
        final binding = WidgetsBinding.instance;
        if (binding.hasScheduledFrame ||
            binding.schedulerPhase != SchedulerPhase.idle) {
          await binding.endOfFrame;
        }
      } catch (_) {
        // No WidgetsBinding in unit tests / pre-engine.
      }
    }
    Object? lastError;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        await _deviceLibrary.sdkInt();
        return;
      } on MissingPluginException catch (error) {
        lastError = error;
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
      }
    }
    throw _wrapLibraryError(lastError ?? 'library plugin missing');
  }

  Future<List<Song>> _loadSongsFromNative() async {
    final rows = await _deviceLibrary.querySongs();
    final songs = <Song>[];
    for (final row in rows) {
      final relativePath = nativeString(row['relativePath']);
      final song = songFromNativeRow(row);
      if (_isMusicSong(song, relativePath: relativePath)) {
        if (!song.filePath.startsWith('/') && relativePath.isNotEmpty) {
          _folderHints[song.id] = relativePath;
        }
        songs.add(song);
      }
    }
    return songs;
  }

  Future<List<Song>> _loadSongsFromOnAudioQuery() async {
    final models = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return models.map(_mapSong).where(_isMusicSong).toList(growable: false);
  }

  Future<Uint8List?> _loadArtwork(int songId, int size, int albumId) async {
    if (_useNativeLibrary) {
      try {
        return await _deviceLibrary.queryArtwork(
          songId,
          size: size,
          albumId: albumId,
        );
      } on MissingPluginException {
        return null;
      } on PlatformException {
        return null;
      }
    }

    return _audioQuery.queryArtwork(
      songId,
      ArtworkType.AUDIO,
      size: size,
      quality: 70,
    );
  }

  Object _wrapLibraryError(Object? error) {
    if (error is LibraryAccessException) return error;
    return LibraryAccessException(libraryErrorMessage(error ?? 'unknown'));
  }

  void _addToCache(String key, Uint8List? art) {
    if (_albumArtCache.length >= _maxAlbumArtCacheSize) {
      _albumArtCache.remove(_albumArtCache.keys.first);
    }
    _albumArtCache[key] = art;
  }

  void _touchCache(String key) {
    final art = _albumArtCache.remove(key);
    if (art != null) {
      _albumArtCache[key] = art;
    }
  }

  Song _mapSong(SongModel m) {
    final filePath = (m.getMap['_data'] as String?) ?? '';
    return Song(
      id: m.id,
      title: m.title,
      artist: m.artist ?? 'Unknown Artist',
      album: m.album ?? 'Unknown Album',
      albumId: m.albumId ?? 0,
      artistId: m.artistId ?? 0,
      duration: Duration(milliseconds: m.duration ?? 0),
      filePath: filePath,
      uri: m.uri ?? '',
      fileExtension: AudioFormat.normalizeExtension(
        m.fileExtension,
        fallbackPath: filePath,
      ),
      fileSize: m.size,
      trackNumber: m.track ?? 0,
      year: 0,
    );
  }
}
