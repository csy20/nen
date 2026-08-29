import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_svc;
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/nen_audio_handler.dart';
import 'package:nen/domain/entities/entities.dart';
import 'package:nen/domain/repositories/audio_repository.dart';

class _FakeAudioRepository implements AudioRepository {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  Duration leftoverDuration = Duration.zero;
  final List<Song> playedSongs = [];

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  bool get isInitialized => true;

  @override
  bool get isVisualizerLive => false;

  @override
  bool get isEqualizerLive => false;

  @override
  bool get supportsCrossfade => false;

  @override
  Song? get preloadedSong => null;

  @override
  Duration get currentDuration => leftoverDuration;

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
  }

  @override
  List<double> getFFTData() => const [];

  @override
  List<double> getEqualizerBands() => List<double>.filled(8, 1.0);

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause() async {
    _playing = false;
  }

  @override
  Future<void> play(Song song) async {
    playedSongs.add(song);
    _playing = true;
  }

  @override
  Future<bool> playPreloaded() async => false;

  @override
  Future<void> preload(Song song) async {}

  @override
  Future<void> resume() async {
    _playing = true;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setCrossfadeDuration(Duration duration) async {}

  @override
  Future<void> setCrossfadeEnabled(bool enabled) async {}

  @override
  Future<void> setEqualizerActive(bool active) async {}

  @override
  Future<void> setEqualizerBand(int band, double gain) async {}

  @override
  Future<void> resetEqualizerBands() async {}

  @override
  Future<void> setSpeed(double value) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<void> stop() async {}
}

const _longLecture = Song(
  id: 11,
  title: 'Osho Maha Geeta 11',
  artist: 'Osho',
  album: 'Osho World',
  albumId: 4,
  duration: Duration(hours: 1, minutes: 47, seconds: 59),
  filePath: '/storage/emulated/0/Music/Osho Maha Geeta 11.mp3',
  uri: 'content://media/external/audio/media/11',
  fileExtension: 'mp3',
  fileSize: 40 * 1024 * 1024,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudioRepository repo;
  late NenAudioHandler handler;

  setUp(() {
    repo = _FakeAudioRepository();
    handler = NenAudioHandler(repo);
  });

  tearDown(() async {
    await handler.teardown();
  });

  test('long lecture publishes title, duration, and seek actions immediately',
      () async {
    repo.leftoverDuration = const Duration(seconds: 1);

    await handler.playSong(_longLecture);

    final item = handler.mediaItem.value;
    expect(item, isNotNull);
    expect(item!.title, 'Osho Maha Geeta 11');
    expect(item.artist, 'Osho');
    expect(item.displayTitle, 'Osho Maha Geeta 11');
    expect(item.duration, _longLecture.duration);
    expect(item.artUri, isNull);
    expect(item.extras?['songId'], 11);

    final state = handler.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.processingState, audio_svc.AudioProcessingState.ready);
    expect(state.systemActions, contains(audio_svc.MediaAction.seek));
    expect(state.bufferedPosition, _longLecture.duration);
    expect(handler.queue.value.single.title, 'Osho Maha Geeta 11');
  });

  test('does not use the audio content URI as notification artwork', () async {
    await handler.playSong(_longLecture);
    expect(handler.mediaItem.value?.artUri, isNull);
    expect(
      handler.mediaItem.value?.extras?.containsKey('loadThumbnailUri'),
      isFalse,
    );
  });
}
