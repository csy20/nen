import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../widgets/song_tile.dart';

/// Detail screen showing songs by an artist.
class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(songsByArtistProvider(artist.id));

    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: NenTheme.trueBlack,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.25),
                      NenTheme.trueBlack,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${artist.songCount} songs · ${artist.albumCount} albums',
                style: const TextStyle(
                  color: NenTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Play all
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: songsAsync.when(
                data: (songs) => ElevatedButton.icon(
                  onPressed: songs.isEmpty
                      ? null
                      : () => ref
                          .read(playbackProvider.notifier)
                          .playQueue(songs),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
          songsAsync.when(
            data: (songs) => SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = songs[index];
                  return SongTile(
                    song: song,
                    onTap: () => ref
                        .read(playbackProvider.notifier)
                        .playQueue(songs, startIndex: index),
                  );
                },
                childCount: songs.length,
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: NenTheme.textSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
