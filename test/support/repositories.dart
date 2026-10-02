import 'dart:async';
import 'dart:typed_data';

import 'package:nen/domain/audio/audio_playback_exception.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/repositories.dart';

class FakeAudioRepository implements AudioRepository {
  FakeAudioRepository({
    this.supportsEqualizer = false,
    this.supportsCrossfade = false,
  });
  Duration _position = Duration.zero;
  @override
  Duration get currentPosition => _position;
  @override
  Stream<AudioPlaybackException> get errorStream => _errorController.stream;
  @override
  final bool supportsEqualizer;
  final StreamController<AudioPlaybackException> _errorController =
      StreamController<AudioPlaybackException>.broadcast();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  bool _initialized = false;
  double volume = 1.0;
  double speed = 1.0;
  bool crossfadeEnabled = false;
  Duration crossfadeDuration = const Duration(seconds: 3);
  final List<Song> playedSongs = [];
  Song? nextPreloaded;
  int playPreloadedCalls = 0;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isVisualizerLive => false;

  @override
  bool get isEqualizerLive => false;

  @override
  final bool supportsCrossfade;

  @override
  Song? get preloadedSong => nextPreloaded;

  @override
  Duration get currentDuration =>
      playedSongs.isEmpty ? Duration.zero : playedSongs.last.duration;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get playingStream => const Stream.empty();

  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _completionController.close();
    await _errorController.close();
    _initialized = false;
  }

  @override
  List<double> getFFTData() => const [];

  @override
  List<double> getEqualizerBands() => List<double>.filled(8, 1.0);

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> play(
    Song song, {
    Duration initialPosition = Duration.zero,
  }) async {
    _position = initialPosition;
    playedSongs.add(song);
    _playing = true;
  }

  @override
  Future<bool> playPreloaded() async {
    playPreloadedCalls++;
    final next = nextPreloaded;
    if (next == null) return false;
    playedSongs.add(next);
    nextPreloaded = null;
    _playing = true;
    return true;
  }

  @override
  Future<void> preload(Song song) async {}

  @override
  Future<void> resume() async {
    _playing = true;
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _positionController.add(position);
  }

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {
    crossfadeDuration = duration;
  }

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {
    crossfadeEnabled = enabled;
  }

  @override
  Future<void> setEqualizerActive(bool active) async {}

  @override
  Future<void> setEqualizerBand(int band, double gain) async {}

  @override
  Future<void> resetEqualizerBands() async {}

  @override
  Future<void> setSpeed(double value) async {
    speed = value;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _position = Duration.zero;
  }

  void emitCompletion() {
    _completionController.add(null);
  }

  void emitError(AudioPlaybackException error) {
    _playing = false;
    _errorController.add(error);
  }
}

class FakeSettingsRepository implements SettingsRepository {
  bool reduceMotion = false;
  bool reduceFlash = false;
  double volume = 1.0;
  int accentColor = 0;
  double playbackSpeed = 1.0;
  bool crossfadeEnabled = false;
  int crossfadeDuration = 3;
  int themeMode = 0;
  bool highContrast = false;
  List<int> favoriteIds = const [];
  List<int> recentSongIds = const [];

  @override
  Future<int> getAccentColor() async => accentColor;

  @override
  Future<bool> getCrossfadeEnabled() async => crossfadeEnabled;

  @override
  Future<int> getCrossfadeDuration() async => crossfadeDuration;

  @override
  Future<List<int>> getFavoriteIds() async => favoriteIds;

  @override
  Future<double> getPlaybackSpeed() async => playbackSpeed;

  @override
  Future<List<int>> getRecentSongIds() async => recentSongIds;

  @override
  Future<bool> getReduceFlash() async => reduceFlash;

  @override
  Future<bool> getReduceMotion() async => reduceMotion;

  @override
  Future<bool> getHighContrast() async => highContrast;

  @override
  Future<int> getThemeMode() async => themeMode;

  @override
  Future<double> getVolume() async => volume;

  @override
  Future<void> setAccentColor(int value) async {
    accentColor = value;
  }

  @override
  Future<void> setCrossfadeDuration(int seconds) async {
    crossfadeDuration = seconds;
  }

  @override
  Future<void> setCrossfadeEnabled(bool value) async {
    crossfadeEnabled = value;
  }

  @override
  Future<void> setFavoriteIds(List<int> ids) async {
    favoriteIds = ids;
  }

  @override
  Future<void> setPlaybackSpeed(double value) async {
    playbackSpeed = value;
  }

  @override
  Future<void> setRecentSongIds(List<int> ids) async {
    recentSongIds = ids;
  }

  @override
  Future<void> setReduceFlash(bool value) async {
    reduceFlash = value;
  }

  @override
  Future<void> setReduceMotion(bool value) async {
    reduceMotion = value;
  }

  @override
  Future<void> setHighContrast(bool value) async {
    highContrast = value;
  }

  @override
  Future<void> setThemeMode(int value) async {
    themeMode = value;
  }

  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<bool> getEqualizerActive() async => false;

  @override
  Future<void> setEqualizerActive(bool value) async {}

  @override
  Future<List<double>> getEqualizerBands() async => List.filled(8, 1.0);

  @override
  Future<void> setEqualizerBands(List<double> bands) async {}

  @override
  Future<bool> getHasSeenOnboarding() async => false;

  @override
  Future<void> setHasSeenOnboarding(bool value) async {}

  LastPlaybackSession? lastSession;

  @override
  Future<LastPlaybackSession?> getLastPlaybackSession() async => lastSession;

  @override
  Future<void> setLastPlaybackSession(LastPlaybackSession? session) async {
    lastSession = session;
  }
}

class FakeMusicRepository implements MusicRepository {
  List<Song> songs;

  FakeMusicRepository(this.songs);

  @override
  Future<List<Album>> getAlbums() async => const [];

  @override
  Future<Uint8List?> getAlbumArt(int songId, {int size = 96}) async => null;

  @override
  Future<List<Artist>> getArtists() async => const [];

  @override
  Future<List<String>> getFolders() async => const [];

  @override
  Future<List<Song>> getSongs() async => songs;

  @override
  Future<List<Song>> getSongsByAlbum(int albumId) async => const [];

  @override
  Future<List<Song>> getSongsByArtist(int artistId) async => const [];

  @override
  Future<List<Song>> getSongsByFolder(String path) async => const [];

  @override
  Future<void> rescanMedia() async {}

  @override
  Future<List<Song>> searchSongs(String query) async => const [];
}

class FakePlaylistRepository implements PlaylistRepository {
  FakePlaylistRepository([List<Playlist> initial = const []])
    : entries = [...initial];

  List<Playlist> entries;

  @override
  Future<List<Playlist>> getPlaylists() async => [...entries];

  @override
  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist(
      id: 'playlist-${entries.length}',
      name: name,
      songs: const [],
      createdAt: DateTime(2026),
    );
    entries.add(playlist);
    return playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async =>
      entries.removeWhere((p) => p.id == id);

  @override
  Future<Playlist> replacePlaylistSongs(
    String playlistId,
    List<Song> songs,
  ) async {
    final index = entries.indexWhere((p) => p.id == playlistId);
    if (index < 0) throw PlaylistNotFoundException(playlistId);
    final playlist = entries[index].copyWith(songs: [...songs]);
    entries[index] = playlist;
    return playlist;
  }

  @override
  Future<Playlist> addSongToPlaylist(String playlistId, Song song) async {
    final current = entries.firstWhere((p) => p.id == playlistId);
    return replacePlaylistSongs(playlistId, [...current.songs, song]);
  }

  @override
  Future<Playlist> removeSongFromPlaylist(String playlistId, int songId) async {
    final current = entries.firstWhere((p) => p.id == playlistId);
    return replacePlaylistSongs(
      playlistId,
      current.songs.where((song) => song.id != songId).toList(),
    );
  }

  @override
  Future<Playlist> reorderPlaylist(
    String playlistId,
    int oldIndex,
    int newIndex,
  ) async {
    final current = entries.firstWhere((p) => p.id == playlistId);
    final songs = [...current.songs];
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, song);
    return replacePlaylistSongs(playlistId, songs);
  }

  @override
  Future<void> renamePlaylist(String id, String newName) async {
    entries = [
      for (final p in entries) p.id == id ? p.copyWith(name: newName) : p,
    ];
  }
}
