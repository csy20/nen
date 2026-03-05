/// Core album entity.
class Album {
  final int id;
  final String name;
  final String artist;
  final int songCount;
  final int year;
  final String? artUri;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.songCount,
    this.year = 0,
    this.artUri,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Album && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
