import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Song list tile with album art, title, artist, duration, and favorite toggle.
class SongTile extends ConsumerWidget {
  final dynamic song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artAsync = ref.watch(albumArtProvider(song.id));
    final playback = ref.watch(playbackProvider);
    final isPlaying = playback.currentSong?.id == song.id;
    final favorites = ref.watch(favoritesProvider);
    final isFav = favorites.contains(song.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: artAsync.when(
            data: (art) {
              if (art != null && art is Uint8List && art.isNotEmpty) {
                return Image.memory(art, fit: BoxFit.cover,
                    cacheWidth: 96, cacheHeight: 96);
              }
              return _defaultArt(context);
            },
            loading: () => _defaultArt(context),
            error: (_, __) => _defaultArt(context),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : NenTheme.textPrimary,
          fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: NenTheme.textSecondary, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => ref.read(favoritesProvider.notifier).toggle(song.id),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isFav ? Colors.redAccent : NenTheme.textTertiary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(song.duration),
            style: const TextStyle(color: NenTheme.textTertiary, fontSize: 12),
          ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _defaultArt(BuildContext context) {
    return Container(
      color: NenTheme.surfaceElevated,
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
