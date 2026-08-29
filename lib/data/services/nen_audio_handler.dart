import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart' as as_lib;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';

import '../../domain/audio/audio_format.dart';
import '../../domain/audio/audio_playback_exception.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/music_repository.dart';

class NenAudioHandler extends as_lib.BaseAudioHandler with as_lib.SeekHandler {
  final AudioRepository _audioRepo;
  final MusicRepository? _musicRepo;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _noisySub;
  DateTime _lastPositionBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  bool _playing = false;
  bool _pausedByInterrupt = false;
  final List<void> _pendingCompletions = [];
  static const int _maxPendingCompletions = 16;

  Future<void> Function()? onCompletion;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  NenAudioHandler(this._audioRepo, {MusicRepository? musicRepo})
    : _musicRepo = musicRepo;

  Stream<as_lib.AudioServiceRepeatMode> get repeatModeStream =>
      playbackState.map((state) => state.repeatMode).distinct();

  Future<void> init() async {
    _completionSub = _audioRepo.completionStream.listen((_) {
      final callback = onCompletion;
      if (callback != null) {
        unawaited(callback());
      } else if (_pendingCompletions.length < _maxPendingCompletions) {
        _pendingCompletions.add(null);
      }
    });

    _positionSub = _audioRepo.positionStream.listen(_onPosition);
    _playingSub = _audioRepo.playingStream.listen((playing) {
      _playing = playing;
      _broadcastState();
    });

    await _audioRepo.initialize();
    await _configureAudioSession();

    while (_pendingCompletions.isNotEmpty) {
      final callback = onCompletion;
      if (callback != null) {
        _pendingCompletions.clear();
        unawaited(callback());
      } else {
        break;
      }
    }
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int queueIndex = 0,
  }) async {
    _playing = true;
    // Metadata must hit MediaSession before playing=true starts the FGS.
    // Samsung One UI shows "nen is running" + an empty bar when title
    // or duration is missing at that moment.
    final item = _mediaItemFor(song);
    mediaItem.add(item);
    this.queue.add([item]);
    await Future<void>.delayed(Duration.zero);
    _broadcastState(position: Duration.zero, queueIndex: queueIndex);
    unawaited(_attachArtwork(song));
    try {
      await _audioRepo.play(song);
    } on PlaybackSupersededException {
      return;
    } catch (e, st) {
      debugPrint('playSong failed: $e\n$st');
      _playing = false;
      _broadcastState();
      if (e is AudioPlaybackException) rethrow;
      throw AudioPlaybackException.unsupported(
        title: song.title,
        formatLabel: AudioFormat.displayName(
          AudioFormat.normalizeExtension(
            song.fileExtension,
            fallbackPath: song.filePath,
          ),
        ),
      );
    }
    final duration = AudioFormat.coalesceDuration(
      _audioRepo.currentDuration,
      song.duration,
    );
    final current = mediaItem.value;
    if (current != null &&
        duration > Duration.zero &&
        current.duration != duration) {
      mediaItem.add(current.copyWith(duration: duration));
    }
    _playing = _audioRepo.isPlaying;
    _broadcastState(position: Duration.zero, queueIndex: queueIndex);
  }

  Duration get currentDuration => _audioRepo.currentDuration;

  Stream<bool> get enginePlayingStream => _audioRepo.playingStream;

  bool get enginePlaying => _audioRepo.isPlaying;

  /// Push engine truth to MediaSession after AudioService.init.
  void syncFromEngine() {
    _playing = _audioRepo.isPlaying;
    _broadcastState();
  }

  @override
  Future<void> play() async {
    await _audioRepo.resume();
    _playing = _audioRepo.isPlaying;
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _audioRepo.pause();
    _playing = _audioRepo.isPlaying;
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _audioRepo.stop();
    _playing = false;
    _broadcastState(position: Duration.zero);
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioRepo.seek(position);
    final dur = mediaItem.value?.duration ?? _audioRepo.currentDuration;
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        bufferedPosition: dur > position ? dur : position,
      ),
    );
  }

  @override
  Future<void> setRepeatMode(as_lib.AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> skipToNext() async {
    final callback = onSkipToNext;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final callback = onSkipToPrevious;
    if (callback != null) {
      await callback();
      return;
    }
    await seek(Duration.zero);
  }

  Future<void> setVolume(double volume) => _audioRepo.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) async {
    await _audioRepo.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  Future<void> setCrossfadeEnabled(bool enabled) =>
      _audioRepo.setCrossfadeEnabled(enabled);

  Future<void> setCrossfadeDuration(Duration duration) =>
      _audioRepo.setCrossfadeDuration(duration);

  void _onPosition(Duration pos) {
    final now = DateTime.now();
    if (pos > Duration.zero &&
        now.difference(_lastPositionBroadcast) <
            const Duration(milliseconds: 800)) {
      return;
    }
    _lastPositionBroadcast = now;
    final dur = mediaItem.value?.duration ?? _audioRepo.currentDuration;
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: pos,
        bufferedPosition: dur > pos ? dur : pos,
      ),
    );
  }

  /// Build notification metadata from library tags, not the decoder.
  ///
  /// Do not pass a `content://` audio URI as [MediaItem.artUri]. audio_service
  /// calls `ContentResolver.loadThumbnail` on that URI *before* applying
  /// metadata. On a 1–2 hour lecture MP3 that extract can hang, so Samsung
  /// keeps the FGS fallback "nen is running" with an empty seek bar.
  as_lib.MediaItem _mediaItemFor(Song song, {Uri? artUri, Duration? duration}) {
    final resolvedDuration =
        duration ??
        (song.duration > Duration.zero
            ? song.duration
            : AudioFormat.coalesceDuration(
                _audioRepo.currentDuration,
                song.duration,
              ));
    final id = song.uri.isNotEmpty
        ? song.uri
        : (song.filePath.isNotEmpty ? song.filePath : 'nen-${song.id}');
    final title = song.title.trim().isEmpty ? 'Unknown title' : song.title;
    final artist = song.artist.trim().isEmpty ? 'Unknown artist' : song.artist;
    final album = song.album.trim().isEmpty ? 'Unknown album' : song.album;
    final safeArt = (artUri != null && artUri.scheme != 'content')
        ? artUri
        : null;
    return as_lib.MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: resolvedDuration > Duration.zero ? resolvedDuration : null,
      artUri: safeArt,
      playable: true,
      displayTitle: title,
      displaySubtitle: artist,
      extras: <String, dynamic>{'songId': song.id},
    );
  }

  Future<void> _attachArtwork(Song song) async {
    final repo = _musicRepo;
    if (repo == null) return;
    try {
      final bytes = await repo.getAlbumArt(song.id, size: 300);
      if (bytes == null || bytes.isEmpty) return;
      if (mediaItem.value?.extras?['songId'] != song.id) return;
      final uri = await _writeArtFile(song.id, bytes);
      if (uri == null) return;
      if (mediaItem.value?.extras?['songId'] != song.id) return;
      mediaItem.add(_mediaItemFor(song, artUri: uri));
    } catch (e) {
      debugPrint('notification art error: $e');
    }
  }

  Future<Uri?> _writeArtFile(int songId, Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nen_notif_art_$songId.jpg');
      await file.writeAsBytes(bytes, flush: true);
      return Uri.file(file.path);
    } catch (e) {
      debugPrint('write art file error: $e');
      return null;
    }
  }

  void _broadcastState({Duration? position, int? queueIndex}) {
    final currentState = playbackState.value;
    // Use updatePosition, not position: the latter is projected forward
    // while playing, so a slow ExoPlayer load would look like a seek.
    final pos = position ?? currentState.updatePosition;
    final dur = mediaItem.value?.duration ?? _audioRepo.currentDuration;
    playbackState.add(
      currentState.copyWith(
        controls: [
          as_lib.MediaControl.skipToPrevious,
          _playing ? as_lib.MediaControl.pause : as_lib.MediaControl.play,
          as_lib.MediaControl.skipToNext,
        ],
        systemActions: const {
          as_lib.MediaAction.seek,
          as_lib.MediaAction.seekForward,
          as_lib.MediaAction.seekBackward,
          as_lib.MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: as_lib.AudioProcessingState.ready,
        playing: _playing,
        updatePosition: pos,
        bufferedPosition: dur > pos ? dur : pos,
        speed: currentState.speed == 0 ? 1.0 : currentState.speed,
        queueIndex: queueIndex ?? currentState.queueIndex,
      ),
    );
  }

  AudioRepository get audioRepo => _audioRepo;

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen((event) {
        unawaited(_handleInterruption(event));
      });
      _noisySub = session.becomingNoisyEventStream.listen((_) {
        unawaited(pause());
      });
    } catch (e) {
      debugPrint('audio session configure error: $e');
    }
  }

  Future<void> _handleInterruption(AudioInterruptionEvent event) async {
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        return;
      }
      if (_playing) {
        _pausedByInterrupt = true;
        await pause();
      }
      return;
    }

    if (_pausedByInterrupt && event.type == AudioInterruptionType.pause) {
      _pausedByInterrupt = false;
      await play();
    } else {
      _pausedByInterrupt = false;
    }
  }

  Future<void> teardown() async {
    await _positionSub?.cancel();
    await _completionSub?.cancel();
    await _playingSub?.cancel();
    await _interruptionSub?.cancel();
    await _noisySub?.cancel();
    await _audioRepo.dispose();
  }
}

Future<NenAudioHandler> initAudioHandler(
  AudioRepository audioRepo, {
  MusicRepository? musicRepo,
  NenAudioHandler? existing,
}) async {
  final handler = await as_lib.AudioService.init(
    builder: () =>
        existing ?? NenAudioHandler(audioRepo, musicRepo: musicRepo),
    config: const as_lib.AudioServiceConfig(
      androidNotificationChannelId: 'dev.csy20.nen.audio',
      androidNotificationChannelName: 'Now playing',
      androidNotificationChannelDescription: 'Playback controls and track info',
      androidNotificationIcon: 'drawable/ic_stat_nen',
      notificationColor: Color(0xFF8B7EC8),
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
      artDownscaleWidth: 192,
      artDownscaleHeight: 192,
    ),
  );
  if (!identical(handler, existing)) {
    await handler.init();
  }
  return handler;
}
