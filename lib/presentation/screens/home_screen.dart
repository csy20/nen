import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import '../theme/page_transitions.dart';
import 'library_screen.dart'; // for FavoritesTab, AlbumsTab, ArtistsTab, FoldersTab
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';
import 'tabs/home_tab.dart'; // the songs list

/// The main dashboard screen, managing the bottom navigation
/// and displaying the core tabs under a persistent Now Playing header.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: true, // Allows body to scroll behind the floating nav bar
      body: Stack(
        children: [
          // Persistent Top Header + Tab Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Persistent Top Bar
              const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: _HomeTopBar(),
                ),
              ),

              // 2. Persistent Now Playing Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              // 3. Persistent Now Playing Card
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: _HomeNowPlayingCard(),
              ),

              const SizedBox(height: 16),

              // 4. Tab Content area
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 6,
                  onPageChanged: (index) {
                    setState(() => _tabIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return switch (index) {
                      0 => const HomeTab(),
                      1 => const FavoritesTab(),
                      2 => const AlbumsTab(),
                      3 => const ArtistsTab(),
                      4 => const PlaylistsScreen(),
                      5 => const FoldersTab(),
                      _ => const SizedBox.shrink(),
                    };
                  },
                ),
              ),
            ],
          ),

          // 5. The floating bottom navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 24, // spacing from the bottom of the screen
            child: SafeArea(
              top: false,
              child: Center(
                child: _FloatingBottomNavBar(
                  currentIndex: _tabIndex,
                  onTap: (index) {
                    setState(() => _tabIndex = index);
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuint,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Persistent Headers ──────────────────────────────────────────────────

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Logo
        Text(
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
        // Action Buttons
        Row(
          children: [
            _TopBarIconButton(
              icon: isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_outlined,
              onPressed: () {
                final current = ref.read(settingsProvider).themeMode;
                final next = current == NenThemeMode.dark
                    ? NenThemeMode.light
                    : NenThemeMode.dark;
                ref.read(settingsProvider.notifier).setThemeMode(next);
              },
            ),
            const SizedBox(width: 12),
            _TopBarIconButton(
              icon: Icons.search_rounded,
              onPressed: () {
                ref.read(searchQueryProvider.notifier).clear();
                showSearch(context: context, delegate: SongSearchDelegate(ref));
              },
            ),
            const SizedBox(width: 12),
            _TopBarIconButton(
              icon: Icons.tune_rounded,
              onPressed: () {
                Navigator.push(
                  context,
                  NenSlideRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _TopBarIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Icon(icon, size: 20, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _HomeNowPlayingCard extends ConsumerWidget {
  const _HomeNowPlayingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final song = ref.watch(playbackProvider.select((s) => s.currentSong));
    final isPlaying = ref.watch(playbackProvider.select((s) => s.isPlaying));

    if (song == null) {
      // Empty state
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Text(
            'Not Playing',
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    final artAsync = ref.watch(largeAlbumArtProvider(song.id));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          NenSlideRoute(builder: (_) => const NowPlayingScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Album Art
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    // Light blue gradient per mockup
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E9BFF), Color(0xFF6A55FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: artAsync.when(
                      data: (art) {
                        if (art != null && art.isNotEmpty) {
                          return Image.memory(art, fit: BoxFit.cover);
                        }
                        return const Icon(
                          Icons.music_note_rounded,
                          size: 32,
                          color: Colors.white,
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      error: (err, stack) => const Icon(
                        Icons.music_note_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Track Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play / Pause Button
                GestureDetector(
                  onTap: () {
                    ref.read(playbackProvider.notifier).togglePlayPause();
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 32,
                        color: Colors
                            .black, // Dark icon on white button per mockup
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom Area (Visualizer Icon)
            Row(
              children: [
                _VisualizerBars(isPlaying: isPlaying),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VisualizerBars extends StatelessWidget {
  final bool isPlaying;

  const _VisualizerBars({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    // A simple static visualizer representation
    final colors = NenTheme.of(context);
    final barColor = colors.textTertiary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _VsBar(height: 12, color: barColor),
        const SizedBox(width: 4),
        _VsBar(height: 20, color: barColor),
        const SizedBox(width: 4),
        _VsBar(height: 16, color: barColor),
        const SizedBox(width: 4),
        _VsBar(height: 24, color: barColor),
        const SizedBox(width: 4),
        _VsBar(height: 14, color: barColor),
      ],
    );
  }
}

class _VsBar extends StatelessWidget {
  final double height;
  final Color color;

  const _VsBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Shared Bottom Navigation Bar ────────────────────────────────────────────────

class _FloatingBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(NenRadius.pill),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NenRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  icon: Icons.library_music_rounded,
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.favorite_border_rounded,
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                _NavItem(
                  icon: Icons.album_rounded,
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.mic_none_rounded,
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
                _NavItem(
                  icon: Icons.playlist_play_rounded,
                  isSelected: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
                _NavItem(
                  icon: Icons.folder_rounded,
                  isSelected: currentIndex == 5,
                  onTap: () => onTap(5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final activeColor = Theme.of(context).colorScheme.primary;
    final inactiveColor = colors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        // subtle background for the active item
        decoration: isSelected
            ? BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              )
            : null,
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? activeColor : inactiveColor,
        ),
      ),
    );
  }
}
