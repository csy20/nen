import 'song.dart';

/// User-created playlist.
class Playlist {
  final String id;
  final String name;
  final List<Song> songs;
  final DateTime createdAt;

  const Playlist({
    required this.id,
    required this.name,
    required this.songs,
    required this.createdAt,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<Song>? songs,
    DateTime? createdAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Playlist && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
