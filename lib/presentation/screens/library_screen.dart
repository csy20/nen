import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../theme/page_transitions.dart';
import '../widgets/async_error_view.dart';
import '../widgets/mini_player_bar.dart';
import '../widgets/song_actions_sheet.dart';
import '../widgets/song_tile.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';

/// Main library screen with tabs: Songs, Albums, Artists, Playlists, Folders.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'nen',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            shadows: [
              Shadow(
                color: NenTheme.defaultAccent.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 22,
            ),
            onPressed: () {
              final current = ref.read(settingsProvider).themeMode;
              final next = current == NenThemeMode.dark
                  ? NenThemeMode.light
                  : NenThemeMode.dark;
              ref.read(settingsProvider.notifier).setThemeMode(next);
            },
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(
              context,
              NenSlideRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildTab()),
          MiniPlayerBar(onTap: () => _openNowPlaying(context)),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note_rounded),
            label: 'Songs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_rounded),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.album_rounded),
            label: 'Albums',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Artists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play_rounded),
            label: 'Playlists',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Folders',
          ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    return switch (_tabIndex) {
      0 => const SongsTab(),
      1 => const FavoritesTab(),
      2 => const AlbumsTab(),
      3 => const ArtistsTab(),
      4 => const PlaylistsScreen(),
      5 => const FoldersTab(),
      _ => const SizedBox.shrink(),
    };
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NowPlayingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    ref.read(searchQueryProvider.notifier).clear();
    showSearch(context: context, delegate: _SongSearchDelegate(ref));
  }
}

// ── Songs Tab ───────────────────────────────────────────────────────

class SongsTab extends ConsumerWidget {
  const SongsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final songsAsync = ref.watch(songsProvider);
    final recentIds = ref.watch(recentlyPlayedProvider);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.read(libraryRefreshProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_off_rounded,
                          size: 64,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No songs found',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add music to your device to get started',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Build recently played section + all songs
        final songsById = {for (final song in songs) song.id: song};
        final recentSongs = recentIds
            .map((id) => songsById[id])
            .whereType<Song>()
            .take(10)
            .toList();

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (recentSongs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'Recently Played',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 56,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: recentSongs.length,
                      itemBuilder: (context, index) {
                        final song = recentSongs[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            label: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: colors.surfaceElevated,
                            onPressed: () {
                              ref
                                  .read(playbackProvider.notifier)
                                  .playSong(song);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'All Songs',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = songs[index];
                  return SongTile(
                    song: song,
                    onTap: () {
                      ref
                          .read(playbackProvider.notifier)
                          .playQueue(songs, startIndex: index);
                    },
                    onLongPress: () => showSongActionsSheet(context, ref, song),
                  );
                }, childCount: songs.length),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
        error: e,
        onRetry: () =>
            ref.read(libraryRefreshProvider.notifier).refresh(rescan: false),
      ),
    );
  }
}

// ── Favorites Tab ──────────────────────────────────────────────────

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final favoriteIds = ref.watch(favoritesProvider);
    final songsAsync = ref.watch(songsProvider);

    return songsAsync.when(
      data: (allSongs) {
        final favSongs = allSongs
            .where((s) => favoriteIds.contains(s.id))
            .toList();

        if (favSongs.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.read(libraryRefreshProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 64,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No favorites yet',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap the ♥ icon on songs to add them here',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: favSongs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        '${favSongs.length} favorites',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => ref
                            .read(playbackProvider.notifier)
                            .playQueue(favSongs),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final song = favSongs[index - 1];
              return SongTile(
                song: song,
                onTap: () => ref
                    .read(playbackProvider.notifier)
                    .playQueue(favSongs, startIndex: index - 1),
                onLongPress: () => showSongActionsSheet(context, ref, song),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
        error: e,
        onRetry: () =>
            ref.read(libraryRefreshProvider.notifier).refresh(rescan: false),
      ),
    );
  }
}

// ── Albums Tab ──────────────────────────────────────────────────────

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final albumsAsync = ref.watch(albumsProvider);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.read(libraryRefreshProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Text(
                      'No albums found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: albums.length,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  NenSlideRoute(
                    builder: (_) => AlbumDetailScreen(album: album),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.album_rounded,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      album.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
        error: e,
        onRetry: () =>
            ref.read(libraryRefreshProvider.notifier).refresh(rescan: false),
      ),
    );
  }
}

// ── Artists Tab ─────────────────────────────────────────────────────

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final artistsAsync = ref.watch(artistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.read(libraryRefreshProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Text(
                      'No artists found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: artists.length,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemBuilder: (context, index) {
              final artist = artists[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colors.surfaceElevated,
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                title: Text(
                  artist.name,
                  style: TextStyle(color: colors.textPrimary),
                ),
                subtitle: Text(
                  '${artist.songCount} songs · ${artist.albumCount} albums',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
                onTap: () => Navigator.push(
                  context,
                  NenSlideRoute(
                    builder: (_) => ArtistDetailScreen(artist: artist),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
        error: e,
        onRetry: () =>
            ref.read(libraryRefreshProvider.notifier).refresh(rescan: false),
      ),
    );
  }
}

// ── Folders Tab ────────────────────────────────────────────────────

class FoldersTab extends ConsumerWidget {
  const FoldersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final foldersAsync = ref.watch(foldersProvider);

    return foldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) {
          return RefreshIndicator.adaptive(
            onRefresh: () =>
                ref.read(libraryRefreshProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Center(
                    child: Text(
                      'No folders found',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator.adaptive(
          onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: folders.length,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemBuilder: (context, index) {
              final folder = folders[index];
              final folderName = folder.split('/').last;
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                title: Text(
                  folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textPrimary),
                ),
                subtitle: Text(
                  folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
                onTap: () => Navigator.push(
                  context,
                  NenSlideRoute(
                    builder: (_) =>
                        _FolderDetailScreen(path: folder, name: folderName),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AsyncErrorView(
        error: e,
        onRetry: () =>
            ref.read(libraryRefreshProvider.notifier).refresh(rescan: false),
      ),
    );
  }
}

class _FolderDetailScreen extends ConsumerWidget {
  final String path;
  final String name;

  const _FolderDetailScreen({required this.path, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final songsAsync = ref.watch(songsByFolderProvider(path));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: Text(name)),
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
        child: songsAsync.when(
          data: (songs) {
            if (songs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(
                      child: Text(
                        'No songs in this folder',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: songs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(
                          '${songs.length} songs',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => ref
                              .read(playbackProvider.notifier)
                              .playQueue(songs),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Play All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final song = songs[index - 1];
                return SongTile(
                  song: song,
                  onTap: () => ref
                      .read(playbackProvider.notifier)
                      .playQueue(songs, startIndex: index - 1),
                  onLongPress: () => showSongActionsSheet(context, ref, song),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
            error: e,
            onRetry: () => ref
                .read(libraryRefreshProvider.notifier)
                .refresh(rescan: false),
          ),
        ),
      ),
    );
  }
}

// ── Search Delegate ────────────────────────────────────────────────

class _SongSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  bool _querySynced = false;

  _SongSearchDelegate(this.ref);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final colors = NenTheme.of(context);
    return Theme.of(context).copyWith(
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: colors.textTertiary),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () {
          query = '';
          ref.read(searchQueryProvider.notifier).clear();
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        ref.read(searchQueryProvider.notifier).clear();
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildContent();

  @override
  Widget buildSuggestions(BuildContext context) => _buildContent();

  Widget _buildContent() {
    return Consumer(
      builder: (context, ref, _) {
        final colors = NenTheme.of(context);
        if (!_querySynced && query.isNotEmpty) {
          _querySynced = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _querySynced = false;
            ref.read(searchQueryProvider.notifier).setQuery(query);
          });
        }
        final results = ref.watch(searchResultsProvider);

        return results.when(
          data: (songs) {
            if (songs.isEmpty) {
              return Center(
                child: Text(
                  query.isEmpty ? 'Search for songs' : 'No results',
                  style: TextStyle(color: colors.textSecondary),
                ),
              );
            }
            return ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongTile(
                  song: song,
                  onTap: () {
                    ref.read(playbackProvider.notifier).playSong(song);
                    ref.read(searchQueryProvider.notifier).clear();
                    close(context, '');
                  },
                  onLongPress: () => showSongActionsSheet(context, ref, song),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AsyncErrorView(
            error: e,
            onRetry: () => ref
                .read(libraryRefreshProvider.notifier)
                .refresh(rescan: false),
          ),
        );
      },
    );
  }
}
