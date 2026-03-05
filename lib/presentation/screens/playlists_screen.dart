import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../widgets/song_tile.dart';

/// Playlist management screen.
class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    // Load playlists on mount
    Future.microtask(() => ref.read(playlistsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);

    return Column(
      children: [
        // Create playlist button
        Padding(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => _showCreateDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: glassmorphicDecoration(
                borderRadius: 12,
                opacity: 0.06,
              ),
              child: Row(
                children: [
                  Icon(Icons.add_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Playlist',
                    style: TextStyle(
                      color: NenTheme.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Playlist list
        Expanded(
          child: playlists.isEmpty
              ? const Center(
                  child: Text(
                    'No playlists yet',
                    style: TextStyle(color: NenTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: playlists.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: NenTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.playlist_play_rounded,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        style: const TextStyle(color: NenTheme.textPrimary),
                      ),
                      subtitle: Text(
                        '${playlist.songs.length} songs',
                        style: const TextStyle(
                          color: NenTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: NenTheme.textTertiary),
                        color: NenTheme.surfaceElevated,
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'rename') {
                            _showRenameDialog(context, playlist.id,
                                playlist.name);
                          } else if (val == 'delete') {
                            ref
                                .read(playlistsProvider.notifier)
                                .delete(playlist.id);
                          }
                        },
                      ),
                      onTap: () => _openPlaylistDetail(context, playlist),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NenTheme.surfaceElevated,
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: NenTheme.textTertiary),
          ),
          style: const TextStyle(color: NenTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).create(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String id, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NenTheme.surfaceElevated,
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: NenTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(playlistsProvider.notifier).rename(id, name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _openPlaylistDetail(BuildContext context, dynamic playlist) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _PlaylistDetailScreen(playlist: playlist),
    ));
  }
}

class _PlaylistDetailScreen extends ConsumerWidget {
  final dynamic playlist;

  const _PlaylistDetailScreen({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          if (playlist.songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => ref
                  .read(playbackProvider.notifier)
                  .playQueue(List.from(playlist.songs)),
              tooltip: 'Play All',
            ),
        ],
      ),
      body: playlist.songs.isEmpty
          ? const Center(
              child: Text(
                'No songs in this playlist',
                style: TextStyle(color: NenTheme.textSecondary),
              ),
            )
          : ListView.builder(
              itemCount: playlist.songs.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final song = playlist.songs[index];
                return Dismissible(
                  key: ValueKey('${playlist.id}_${song.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.redAccent),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(playlistsProvider.notifier)
                        .removeSong(playlist.id, song.id);
                  },
                  child: SongTile(
                    song: song,
                    onTap: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(List.from(playlist.songs),
                            startIndex: index),
                  ),
                );
              },
            ),
    );
  }
}
