import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/audio_repository_impl.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/services/nen_audio_handler.dart';
import '../../data/services/permission_service.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

// ── Services ────────────────────────────────────────────────────────

final permissionServiceProvider = Provider<PermissionService>(
  (_) => PermissionService(),
);

// ── Audio Handler (background service) ──────────────────────────────

/// Overridden in main() with the initialized singleton.
final audioHandlerProvider = Provider<NenAudioHandler>(
  (_) => throw UnimplementedError('audioHandlerProvider must be overridden'),
);

// ── Repositories ────────────────────────────────────────────────────

final musicRepositoryProvider = Provider<MusicRepository>(
  (_) => MusicRepositoryImpl(),
);

/// Overridden in main() so the same instance is shared with the handler.
final audioRepositoryProvider = Provider<AudioRepository>(
  (_) => AudioRepositoryImpl(),
);

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (_) => PlaylistRepositoryImpl(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => SettingsRepositoryImpl(),
);

// ── Use Cases ───────────────────────────────────────────────────────

final getSongsUseCaseProvider = Provider<GetSongsUseCase>(
  (ref) => GetSongsUseCase(ref.watch(musicRepositoryProvider)),
);

final getAlbumsUseCaseProvider = Provider<GetAlbumsUseCase>(
  (ref) => GetAlbumsUseCase(ref.watch(musicRepositoryProvider)),
);

final getArtistsUseCaseProvider = Provider<GetArtistsUseCase>(
  (ref) => GetArtistsUseCase(ref.watch(musicRepositoryProvider)),
);

final getSongsByAlbumUseCaseProvider = Provider<GetSongsByAlbumUseCase>(
  (ref) => GetSongsByAlbumUseCase(ref.watch(musicRepositoryProvider)),
);

final getSongsByArtistUseCaseProvider = Provider<GetSongsByArtistUseCase>(
  (ref) => GetSongsByArtistUseCase(ref.watch(musicRepositoryProvider)),
);

final searchSongsUseCaseProvider = Provider<SearchSongsUseCase>(
  (ref) => SearchSongsUseCase(ref.watch(musicRepositoryProvider)),
);

final managePlaylistUseCaseProvider = Provider<ManagePlaylistUseCase>(
  (ref) => ManagePlaylistUseCase(ref.watch(playlistRepositoryProvider)),
);
