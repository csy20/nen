/// Core artist entity.
class Artist {
  final int id;
  final String name;
  final int albumCount;
  final int songCount;

  const Artist({
    required this.id,
    required this.name,
    required this.albumCount,
    required this.songCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Artist && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
