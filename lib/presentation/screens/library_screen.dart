import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../widgets/mini_player_bar.dart';
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
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(favoritesProvider.notifier).load();
      ref.read(recentlyPlayedProvider.notifier).load();
      ref.read(settingsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      appBar: AppBar(
        title: const Text('nen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => _showSearch(context),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildTab()),
          MiniPlayerBar(
            onTap: () => _openNowPlaying(context),
          ),
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
      0 => const _SongsTab(),
      1 => const _FavoritesTab(),
      2 => const _AlbumsTab(),
      3 => const _ArtistsTab(),
      4 => const PlaylistsScreen(),
      5 => const _FoldersTab(),
      _ => const SizedBox.shrink(),
    };
  }

  void _openNowPlaying(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const NowPlayingScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: _SongSearchDelegate(ref));
  }
}

// ── Songs Tab ───────────────────────────────────────────────────────

class _SongsTab extends ConsumerWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsProvider);
    final recentIds = ref.watch(recentlyPlayedProvider);

    return songsAsync.when(
      data: (songs) {
        if (songs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.music_off_rounded, size: 64,
                    color: NenTheme.textTertiary),
                SizedBox(height: 16),
                Text('No songs found',
                    style: TextStyle(color: NenTheme.textSecondary)),
                SizedBox(height: 8),
                Text('Add music to your device to get started',
                    style: TextStyle(color: NenTheme.textTertiary,
                        fontSize: 12)),
              ],
            ),
          );
        }

        // Build recently played section + all songs
        final recentSongs = recentIds
            .map((id) => songs.cast<dynamic>().firstWhere(
                (s) => s.id == id,
                orElse: () => null))
            .where((s) => s != null)
            .take(10)
            .toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (recentSongs.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Recently Played',
                      style: TextStyle(
                          color: NenTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
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
                          label: Text(song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: NenTheme.textPrimary, fontSize: 12)),
                          backgroundColor: NenTheme.surfaceElevated,
                          onPressed: () {
                            ref.read(playbackProvider.notifier).playSong(song);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('All Songs',
                      style: TextStyle(
                          color: NenTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songs[index];
                  return SongTile(
                    song: song,
                    onTap: () {
                      ref.read(playbackProvider.notifier)
                          .playQueue(songs, startIndex: index);
                    },
                  );
                },
                childCount: songs.length,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: NenTheme.textSecondary)),
      ),
    );
  }
}

// ── Favorites Tab ──────────────────────────────────────────────────

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteIds = ref.watch(favoritesProvider);
    final songsAsync = ref.watch(songsProvider);

    return songsAsync.when(
      data: (allSongs) {
        final favSongs =
            allSongs.where((s) => favoriteIds.contains(s.id)).toList();

        if (favSongs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border_rounded,
                    size: 64, color: NenTheme.textTertiary),
                SizedBox(height: 16),
                Text('No favorites yet',
                    style: TextStyle(color: NenTheme.textSecondary)),
                SizedBox(height: 8),
                Text('Tap the ♥ icon on songs to add them here',
                    style: TextStyle(
                        color: NenTheme.textTertiary, fontSize: 12)),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${favSongs.length} favorites',
                      style: const TextStyle(
                          color: NenTheme.textSecondary, fontSize: 12)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(favSongs),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Play All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: favSongs.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final song = favSongs[index];
                  return SongTile(
                    song: song,
                    onTap: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(favSongs, startIndex: index),
                    onLongPress: () {
                      ref.read(favoritesProvider.notifier).toggle(song.id);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: NenTheme.textSecondary)),
      ),
    );
  }
}

// ── Albums Tab ──────────────────────────────────────────────────────

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);

    return albumsAsync.when(
      data: (albums) {
        if (albums.isEmpty) {
          return const Center(
            child: Text('No albums found',
                style: TextStyle(color: NenTheme.textSecondary)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final album = albums[index];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(album: album),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: NenTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.album_rounded,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NenTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: NenTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: NenTheme.textSecondary)),
      ),
    );
  }
}

// ── Artists Tab ─────────────────────────────────────────────────────

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);

    return artistsAsync.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(
            child: Text('No artists found',
                style: TextStyle(color: NenTheme.textSecondary)),
          );
        }

        return ListView.builder(
          itemCount: artists.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final artist = artists[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: NenTheme.surfaceElevated,
                child: Icon(
                  Icons.person_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
                ),
              ),
              title: Text(artist.name,
                  style: const TextStyle(color: NenTheme.textPrimary)),
              subtitle: Text(
                '${artist.songCount} songs · ${artist.albumCount} albums',
                style: const TextStyle(
                    color: NenTheme.textTertiary, fontSize: 12),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistDetailScreen(artist: artist),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: NenTheme.textSecondary)),
      ),
    );
  }
}

// ── Folders Tab ────────────────────────────────────────────────────

class _FoldersTab extends ConsumerWidget {
  const _FoldersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);

    return foldersAsync.when(
      data: (folders) {
        if (folders.isEmpty) {
          return const Center(
            child: Text('No folders found',
                style: TextStyle(color: NenTheme.textSecondary)),
          );
        }

        return ListView.builder(
          itemCount: folders.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final folder = folders[index];
            final folderName = folder.split('/').last;
            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: NenTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.folder_rounded,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5)),
              ),
              title: Text(folderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NenTheme.textPrimary)),
              subtitle: Text(folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: NenTheme.textTertiary, fontSize: 11)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _FolderDetailScreen(path: folder, name: folderName),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: const TextStyle(color: NenTheme.textSecondary)),
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
    final songsAsync = ref.watch(songsByFolderProvider(path));

    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      appBar: AppBar(title: Text(name)),
      body: songsAsync.when(
        data: (songs) {
          if (songs.isEmpty) {
            return const Center(
              child: Text('No songs in this folder',
                  style: TextStyle(color: NenTheme.textSecondary)),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('${songs.length} songs',
                        style: const TextStyle(
                            color: NenTheme.textTertiary, fontSize: 12)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(playbackProvider.notifier)
                          .playQueue(songs),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Play All'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: songs.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SongTile(
                      song: song,
                      onTap: () => ref
                          .read(playbackProvider.notifier)
                          .playQueue(songs, startIndex: index),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: NenTheme.textSecondary)),
        ),
      ),
    );
  }
}

// ── Search Delegate ────────────────────────────────────────────────

class _SongSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;

  _SongSearchDelegate(this.ref);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return NenTheme.build().copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: NenTheme.textTertiary),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildContent();

  @override
  Widget buildSuggestions(BuildContext context) => _buildContent();

  Widget _buildContent() {
    return Consumer(builder: (context, ref, _) {
      ref.read(searchQueryProvider.notifier).state = query;
      final results = ref.watch(searchResultsProvider);

      return results.when(
        data: (songs) {
          if (songs.isEmpty) {
            return Center(
              child: Text(
                query.isEmpty ? 'Search for songs' : 'No results',
                style: const TextStyle(color: NenTheme.textSecondary),
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
                  close(context, '');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      );
    });
  }
}
