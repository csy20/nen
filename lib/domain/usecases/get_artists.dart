import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class GetArtistsUseCase {
  final MusicRepository _repository;
  const GetArtistsUseCase(this._repository);

  Future<List<Artist>> call() => _repository.getArtists();
}
