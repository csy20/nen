import '../entities/entities.dart';
import '../repositories/music_repository.dart';

class GetSongsByArtistUseCase {
  final MusicRepository _repository;
  const GetSongsByArtistUseCase(this._repository);

  Future<List<Song>> call(int artistId) =>
      _repository.getSongsByArtist(artistId);
}
