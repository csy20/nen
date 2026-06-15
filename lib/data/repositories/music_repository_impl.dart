import 'dart:collection';
import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';

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
  final LinkedHashMap<int, Uint8List?> _albumArtCache =
      LinkedHashMap<int, Uint8List?>();
  static const int _maxAlbumArtCacheSize = 200;
  final Map<int, Future<Uint8List?>> _albumArtRequests =
      <int, Future<Uint8List?>>{};
  List<SongModel>? _songsCache;
  Future<List<SongModel>>? _songsRequest;

  MusicRepositoryImpl({OnAudioQuery? audioQuery})
    : _audioQuery = audioQuery ?? OnAudioQuery();

  bool _isMusicFile(SongModel model) {
    if ((model.duration ?? 0) < _minDurationMs) return false;
    final path = model.data.replaceAll('\\', '/');
    for (final segment in _excludedPathSegments) {
      if (path.contains(segment)) return false;
    }
    return true;
  }

  @override
  Future<List<Song>> getSongs() async {
    final models = await _queryAllSongs();
    return models.where(_isMusicFile).map(_mapSong).toList();
  }

  @override
  Future<List<Album>> getAlbums() async {
    final models = await _audioQuery.queryAlbums(
      sortType: AlbumSortType.ALBUM,
      orderType: OrderType.ASC_OR_SMALLER,
    );
    return models.map(_mapAlbum).toList();
  }

  @override
  Future<List<Artist>> getArtists() async {
    final models = await _audioQuery.queryArtists(
      sortType: ArtistSortType.ARTIST,
      orderType: OrderType.ASC_OR_SMALLER,
    );
    return models.map(_mapArtist).toList();
  }

  @override
  Future<List<Song>> getSongsByAlbum(int albumId) async {
    final models = await _queryAllSongs();
    return models
        .where((s) => s.albumId == albumId && _isMusicFile(s))
        .map(_mapSong)
        .toList();
  }

  @override
  Future<List<Song>> getSongsByArtist(int artistId) async {
    final models = await _queryAllSongs();
    return models
        .where((s) => s.artistId == artistId && _isMusicFile(s))
        .map(_mapSong)
        .toList();
  }

  @override
  Future<Uint8List?> getAlbumArt(int songId) async {
    if (_albumArtCache.containsKey(songId)) {
      _touchCache(songId);
      return _albumArtCache[songId];
    }

    final inFlight = _albumArtRequests[songId];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _audioQuery
        .queryArtwork(songId, ArtworkType.AUDIO, size: 512, quality: 80)
        .then((art) {
          _addToCache(songId, art);
          _albumArtRequests.remove(songId);
          return art;
        })
        .catchError((error) {
          _albumArtRequests.remove(songId);
          throw error;
        });

    _albumArtRequests[songId] = request;
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

  @override
  Future<List<String>> getFolders() async {
    final songs = await _queryAllSongs();
    final folders = <String>{};
    for (final s in songs.where(_isMusicFile)) {
      final path = s.data;
      final lastSlash = path.lastIndexOf('/');
      if (lastSlash > 0) {
        folders.add(path.substring(0, lastSlash));
      }
    }
    final sorted = folders.toList()..sort();
    return sorted;
  }

  @override
  Future<List<Song>> getSongsByFolder(String path) async {
    final songs = await _queryAllSongs();
    return songs
        .where((s) {
          if (!_isMusicFile(s)) return false;
          final lastSlash = s.data.lastIndexOf('/');
          if (lastSlash <= 0) return false;
          return s.data.substring(0, lastSlash) == path;
        })
        .map(_mapSong)
        .toList();
  }

  @override
  Future<void> rescanMedia() async {
    _songsCache = null;
    _songsRequest = null;
    _albumArtCache.clear();
    _albumArtRequests.clear();
  }

  Future<List<SongModel>> _queryAllSongs() {
    final cache = _songsCache;
    if (cache != null) {
      return Future.value(cache);
    }

    final inFlight = _songsRequest;
    if (inFlight != null) {
      return inFlight;
    }

    final request = _audioQuery
        .querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
        )
        .then((models) {
          _songsCache = models;
          _songsRequest = null;
          return models;
        })
        .catchError((error) {
          _songsRequest = null;
          throw error;
        });

    _songsRequest = request;
    return request;
  }

  void _addToCache(int songId, Uint8List? art) {
    if (_albumArtCache.length >= _maxAlbumArtCacheSize) {
      _albumArtCache.remove(_albumArtCache.keys.first);
    }
    _albumArtCache[songId] = art;
  }

  void _touchCache(int songId) {
    final art = _albumArtCache.remove(songId);
    if (art != null || _albumArtCache.containsKey(songId) == false) {
      _albumArtCache[songId] = art;
    }
  }

  Song _mapSong(SongModel m) => Song(
    id: m.id,
    title: m.title,
    artist: m.artist ?? 'Unknown Artist',
    album: m.album ?? 'Unknown Album',
    albumId: m.albumId ?? 0,
    duration: Duration(milliseconds: m.duration ?? 0),
    filePath: m.data,
    trackNumber: m.track ?? 0,
    year: 0,
  );

  Album _mapAlbum(AlbumModel m) => Album(
    id: m.id,
    name: m.album,
    artist: m.artist ?? 'Unknown Artist',
    songCount: m.numOfSongs,
  );

  Artist _mapArtist(ArtistModel m) => Artist(
    id: m.id,
    name: m.artist,
    albumCount: m.numberOfAlbums ?? 0,
    songCount: m.numberOfTracks ?? 0,
  );
}
