import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class GetAlbumsUseCase {
  final MusicRepository _repository;
  const GetAlbumsUseCase(this._repository);

  Future<List<Album>> call() => _repository.getAlbums();
}
