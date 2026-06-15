import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';

Future<void> showSongActionsSheet(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  if (ref.read(playlistsProvider).isEmpty) {
    await ref.read(playlistsProvider.notifier).load();
  }

  if (!context.mounted) {
    return;
  }

  final colors = NenTheme.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return Consumer(
        builder: (sheetContext, ref, _) {
          final playlists = ref.watch(playlistsProvider);
          final sheetColors = NenTheme.of(sheetContext);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sheetColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sheetColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.queue_music_rounded,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    ),
                    title: Text(
                      'Add to queue',
                      style: TextStyle(color: sheetColors.textPrimary),
                    ),
                    onTap: () {
                      ref.read(playbackProvider.notifier).addToQueue(song);
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Queued ${song.title}')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add to playlist',
                    style: TextStyle(
                      color: sheetColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (playlists.isEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.playlist_add_rounded,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      ),
                      title: Text(
                        'Create playlist',
                        style: TextStyle(color: sheetColors.textPrimary),
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final playlistName = await _showCreatePlaylistDialog(
                          context,
                        );
                        if (playlistName == null || playlistName.isEmpty) {
                          return;
                        }

                        final playlist = await ref
                            .read(playlistsProvider.notifier)
                            .create(playlistName);
                        await ref
                            .read(playlistsProvider.notifier)
                            .addSong(playlist.id, song);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Added ${song.title} to ${playlist.name}',
                              ),
                            ),
                          );
                        }
                      },
                    )
                  else
                    ...playlists.map((playlist) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.playlist_play_rounded),
                        title: Text(
                          playlist.name,
                          style: TextStyle(color: sheetColors.textPrimary),
                        ),
                        subtitle: Text(
                          '${playlist.songs.length} songs',
                          style: TextStyle(
                            color: sheetColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        onTap: () async {
                          await ref
                              .read(playlistsProvider.notifier)
                              .addSong(playlist.id, song);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Added ${song.title} to ${playlist.name}',
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> _showCreatePlaylistDialog(BuildContext context) async {
  final controller = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = NenTheme.of(dialogContext);
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: const Text('New Playlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Playlist name'),
            style: TextStyle(color: colors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
