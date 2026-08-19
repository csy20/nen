import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/di_providers.dart';
import '../providers/settings_provider.dart';
import '../theme/nen_theme.dart';
import 'permission_screen.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _pages = [
  _OnboardingPageData(
    icon: Icons.music_note_rounded,
    title: 'Welcome to nen',
    body:
        'A lightweight offline audio player for the music already on your device. Fast playback, no streaming, no clutter — just your library.',
  ),
  _OnboardingPageData(
    icon: Icons.library_music_rounded,
    title: 'Browse local music',
    body:
        'Grant access once and Nen scans audio files on this device. Browse songs, albums, artists, playlists, and folders. Pull to refresh, or rescan from Settings when you add new tracks.',
  ),
  _OnboardingPageData(
    icon: Icons.play_circle_rounded,
    title: 'Playback controls',
    body:
        'Play, pause, skip, shuffle, and repeat from now playing. Background playback and lock-screen controls stay with you. Open a track for the visualizer, equalizer, and sleep timer.',
  ),
  _OnboardingPageData(
    icon: Icons.headphones_rounded,
    title: 'Ready when you are',
    body:
        'nen stays on-device. Next you will grant library access, then start listening.',
  ),
];

/// First-launch walkthrough. Shown only when [has_seen_onboarding] is false.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.onCompleted});

  /// Invoked after the onboarding flag is persisted.
  /// If null, navigates to [PermissionScreen].
  final VoidCallback? onCompleted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;
  bool _completing = false;

  bool get _isLastPage => _index == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    try {
      await ref.read(settingsRepositoryProvider).setHasSeenOnboarding(true);
      ref.invalidate(hasSeenOnboardingProvider);
      if (widget.onCompleted != null) {
        widget.onCompleted!();
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PermissionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _next() {
    if (_isLastPage) {
      _complete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        key: const Key('onboarding_skip'),
                        onPressed: _completing ? null : _complete,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    key: const Key('onboarding_page_view'),
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) {
                      return _OnboardingPage(data: _pages[index]);
                    },
                  ),
                ),
                _DotIndicators(
                  count: _pages.length,
                  index: _index,
                  accent: accent,
                  inactive: colors.textTertiary,
                  onDotTap: (i) {
                    _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: _isLastPage
                          ? const Key('onboarding_get_started')
                          : const Key('onboarding_next'),
                      onPressed: _completing ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(NenRadius.button),
                        ),
                      ),
                      child: _completing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isLastPage ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.25),
                          blurRadius: 32,
                        ),
                      ],
                    ),
                    child: Icon(data.icon, size: 44, color: accent),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'nen',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: NenTheme.defaultAccent.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DotIndicators extends StatelessWidget {
  const _DotIndicators({
    required this.count,
    required this.index,
    required this.accent,
    required this.inactive,
    required this.onDotTap,
  });

  final int count;
  final int index;
  final Color accent;
  final Color inactive;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('onboarding_dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return GestureDetector(
          onTap: () => onDotTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: selected ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected ? accent : inactive.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(NenRadius.pill),
            ),
          ),
        );
      }),
    );
  }
}
