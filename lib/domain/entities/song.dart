/// Core song entity — pure domain, no framework dependencies.
class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final Duration duration;
  final String filePath;
  final int trackNumber;
  final int year;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.duration,
    required this.filePath,
    this.trackNumber = 0,
    this.year = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Song && id == other.id;

  @override
  int get hashCode => id.hashCode;

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    String? album,
    int? albumId,
    Duration? duration,
    String? filePath,
    int? trackNumber,
    int? year,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      duration: duration ?? this.duration,
      filePath: filePath ?? this.filePath,
      trackNumber: trackNumber ?? this.trackNumber,
      year: year ?? this.year,
    );
  }
}
