import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class GetSongsUseCase {
  final MusicRepository _repository;
  const GetSongsUseCase(this._repository);

  Future<List<Song>> call() => _repository.getSongs();
}
