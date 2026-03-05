import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class GetSongsByAlbumUseCase {
  final MusicRepository _repository;
  const GetSongsByAlbumUseCase(this._repository);

  Future<List<Song>> call(int albumId) => _repository.getSongsByAlbum(albumId);
}
