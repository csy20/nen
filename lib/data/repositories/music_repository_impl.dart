import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';

/// Implementation of [MusicRepository] using on_audio_query.
class MusicRepositoryImpl implements MusicRepository {
  final OnAudioQuery _audioQuery;

  MusicRepositoryImpl({OnAudioQuery? audioQuery})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  @override
  Future<List<Song>> getSongs() async {
    final models = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return models.map(_mapSong).toList();
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
    final models = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return models
        .where((s) => s.albumId == albumId)
        .map(_mapSong)
        .toList();
  }

  @override
  Future<List<Song>> getSongsByArtist(int artistId) async {
    final models = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
    );
    return models
        .where((s) => s.artistId == artistId)
        .map(_mapSong)
        .toList();
  }

  @override
  Future<Uint8List?> getAlbumArt(int songId) async {
    return _audioQuery.queryArtwork(
      songId,
      ArtworkType.AUDIO,
      size: 512,
      quality: 80,
    );
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    final all = await getSongs();
    final q = query.toLowerCase();
    return all
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q))
        .toList();
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
