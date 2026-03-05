import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class SearchSongsUseCase {
  final MusicRepository _repository;
  const SearchSongsUseCase(this._repository);

  Future<List<Song>> call(String query) => _repository.searchSongs(query);
}
