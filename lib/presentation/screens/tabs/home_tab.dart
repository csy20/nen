import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/nen_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/async_error_view.dart';
import '../../widgets/song_actions_sheet.dart';
import '../../widgets/song_tile.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final songsAsync = ref.watch(songsProvider);

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background handled by parent HomeScreen
      body: RefreshIndicator.adaptive(
        onRefresh: () => ref.read(libraryRefreshProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Library Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  'LIBRARY',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            // Songs List
            songsAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No songs found',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(
                    bottom: 120,
                  ), // Padding for the floating bottom nav
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = songs[index];
                        return SongTile(
                          song: song,
                          onTap: () {
                            ref
                                .read(playbackProvider.notifier)
                                .playQueue(songs, startIndex: index);
                          },
                          onLongPress: () =>
                              showSongActionsSheet(context, ref, song),
                        );
                      },
                      childCount: songs.length,
                      addAutomaticKeepAlives: false,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AsyncErrorView(
                  error: e,
                  title: 'Error loading songs.',
                  onRetry: () =>
                      ref.read(libraryRefreshProvider.notifier).refresh(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
