import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../theme/page_transitions.dart';
import '../widgets/song_actions_sheet.dart';
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
    final colors = NenTheme.of(context);
    final playlists = ref.watch(playlistsProvider);

    return Column(
      children: [
        // Create playlist + export/import buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showCreateDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: glassmorphicDecoration(
                      borderRadius: 12,
                      opacity: 0.06,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create Playlist',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.file_upload_outlined,
                  color: colors.textSecondary,
                ),
                onPressed: () => _exportPlaylists(context),
                tooltip: 'Export Playlists',
              ),
              IconButton(
                icon: Icon(
                  Icons.file_download_outlined,
                  color: colors.textSecondary,
                ),
                onPressed: () => _importPlaylists(context),
                tooltip: 'Import Playlists',
              ),
            ],
          ),
        ),

        // Playlist list
        Expanded(
          child: playlists.isEmpty
              ? Center(
                  child: Text(
                    'No playlists yet',
                    style: TextStyle(color: colors.textSecondary),
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
                          color: colors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.playlist_play_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      subtitle: Text(
                        '${playlist.songs.length} songs',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colors.textTertiary,
                        ),
                        color: colors.surfaceElevated,
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Delete',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'rename') {
                            _showRenameDialog(
                              context,
                              playlist.id,
                              playlist.name,
                            );
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
    final colors = NenTheme.of(context);
    final controller = TextEditingController();
    final dialog = showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: colors.textTertiary),
          ),
          style: TextStyle(color: colors.textPrimary),
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
    dialog.then((_) => controller.dispose());
  }

  void _showRenameDialog(BuildContext context, String id, String currentName) {
    final colors = NenTheme.of(context);
    final controller = TextEditingController(text: currentName);
    final dialog = showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceElevated,
        title: const Text('Rename Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
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
    dialog.then((_) => controller.dispose());
  }

  void _openPlaylistDetail(BuildContext context, Playlist playlist) {
    Navigator.of(context).push(
      NenSlideRoute(builder: (_) => _PlaylistDetailScreen(playlist: playlist)),
    );
  }

  Future<void> _exportPlaylists(BuildContext context) async {
    final playlists = ref.read(playlistsProvider);
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No playlists to export')));
      return;
    }

    final data = playlists
        .map(
          (p) => {
            'name': p.name,
            'songs': p.songs
                .map(
                  (s) => {
                    'id': s.id,
                    'title': s.title,
                    'artist': s.artist,
                    'album': s.album,
                    'albumId': s.albumId,
                    'artistId': s.artistId,
                    'duration': s.duration.inMilliseconds,
                    'filePath': s.filePath,
                    'uri': s.uri,
                    'fileExtension': s.fileExtension,
                    'fileSize': s.fileSize,
                    'trackNumber': s.trackNumber,
                    'year': s.year,
                  },
                )
                .toList(),
          },
        )
        .toList();

    final json = const JsonEncoder.withIndent('  ').convert(data);
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access storage')),
        );
      }
      return;
    }
    final file = File(p.join(dir.path, 'nen_playlists.json'));
    await file.writeAsString(json);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to ${file.path}')));
    }
  }

  Future<void> _importPlaylists(BuildContext context) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access storage')),
        );
      }
      return;
    }
    final file = File(p.join(dir.path, 'nen_playlists.json'));
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No nen_playlists.json found in app storage'),
          ),
        );
      }
      return;
    }

    try {
      final json = await file.readAsString();
      final data = jsonDecode(json) as List;
      int count = 0;
      for (final playlistData in data) {
        final map = playlistData as Map<String, dynamic>;
        final name = (map['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final songs = (map['songs'] as List<dynamic>? ?? const []).map((
          songData,
        ) {
          final song = songData as Map<String, dynamic>;
          return Song(
            id: song['id'] as int,
            title: song['title'] as String,
            artist: song['artist'] as String,
            album: song['album'] as String,
            albumId: song['albumId'] as int,
            artistId: song['artistId'] as int? ?? 0,
            duration: Duration(milliseconds: song['duration'] as int),
            filePath: song['filePath'] as String? ?? '',
            uri: song['uri'] as String? ?? '',
            fileExtension: song['fileExtension'] as String? ?? '',
            fileSize: song['fileSize'] as int? ?? 0,
            trackNumber: song['trackNumber'] as int? ?? 0,
            year: song['year'] as int? ?? 0,
          );
        }).toList();
        await ref.read(playlistsProvider.notifier).importNamed(name, songs);
        count++;
      }
      await ref.read(playlistsProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Imported $count playlists')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

class _PlaylistDetailScreen extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistDetailScreen({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final live =
        ref
            .watch(playlistsProvider)
            .where((p) => p.id == playlist.id)
            .firstOrNull ??
        playlist;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(live.name),
        actions: [
          if (live.songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => ref
                  .read(playbackProvider.notifier)
                  .playQueue(List.from(live.songs)),
              tooltip: 'Play All',
            ),
        ],
      ),
      body: live.songs.isEmpty
          ? Center(
              child: Text(
                'No songs in this playlist',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : ListView.builder(
              itemCount: live.songs.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final song = live.songs[index];
                return Dismissible(
                  key: ValueKey('${live.id}_${song.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.redAccent.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.redAccent,
                    ),
                  ),
                  onDismissed: (_) {
                    ref
                        .read(playlistsProvider.notifier)
                        .removeSong(live.id, song.id);
                  },
                  child: SongTile(
                    song: song,
                    onTap: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(List.from(live.songs), startIndex: index),
                    onLongPress: () => showSongActionsSheet(context, ref, song),
                  ),
                );
              },
            ),
    );
  }
}
