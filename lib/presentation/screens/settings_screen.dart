import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Settings screen with redesigned glassmorphic grouped sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
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
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // Audio & Playback Section
          _SectionHeader('AUDIO & PLAYBACK'),
          _SettingsGroup(
            children: [
              _CustomSwitchTile(
                title: 'Crossfade Tracks',
                subtitle: 'Smooth transition between songs',
                value: settings.crossfadeEnabled,
                activeColor: Colors.cyanAccent,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleCrossfade(),
              ),
              if (settings.crossfadeEnabled) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: colors.textTertiary,
                        size: 20,
                      ),
                      Expanded(
                        child: Slider(
                          value: settings.crossfadeDuration.toDouble(),
                          min: 1,
                          max: 10,
                          divisions: 9,
                          activeColor: Colors.cyanAccent,
                          inactiveColor: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          onChanged: (v) => ref
                              .read(settingsProvider.notifier)
                              .setCrossfadeDuration(v.toInt()),
                        ),
                      ),
                      Text(
                        '${settings.crossfadeDuration}s',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              _DividerLine(),
              _CustomListTile(
                title: 'Audio Engine',
                subtitle: 'SoLoud + system decoder · all common formats',
                trailing: Icon(
                  Icons.memory_rounded,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Visualizer Section
          _SectionHeader('VISUALIZER'),
          _SettingsGroup(
            children: [
              _CustomSwitchTile(
                title: 'Reduce Motion',
                subtitle: 'Limit particle and wave effects',
                value: settings.reduceMotion,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleReduceMotion(),
              ),
              _DividerLine(),
              _CustomSwitchTile(
                title: 'High Contrast',
                subtitle: 'Remove glass blur for readability',
                value: settings.highContrast,
                onChanged: (_) =>
                    ref.read(settingsProvider.notifier).toggleHighContrast(),
              ),
              // We removed Reduce Flash explicitly visually but can keep it behind if wanted,
              // mockups don't show it in the VISUALIZER section initially.
            ],
          ),

          const SizedBox(height: 32),

          // Appearance Section
          _SectionHeader('APPEARANCE'),
          _SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    _ThemeSegmentedControl(
                      currentMode: settings.themeMode,
                      onChanged: (mode) {
                        ref.read(settingsProvider.notifier).setThemeMode(mode);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // System Section
          _SectionHeader('SYSTEM'),
          _SettingsGroup(
            children: [
              _CustomListTile(
                title: 'Rescan Library',
                subtitle: 'Find newly added audio files',
                titleColor: Colors.cyanAccent,
                trailing: const Icon(
                  Icons.sync_rounded,
                  color: Colors.cyanAccent,
                ),
                onTap: () => _rescanMedia(context),
              ),
            ],
          ),

          const SizedBox(height: 48), // Bottom padding
        ],
      ),
    );
  }

  Future<void> _rescanMedia(BuildContext context) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Scanning for new media...')));
    try {
      await ref.read(libraryRefreshProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Media scan complete')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: children),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
      indent: 16,
      endIndent: 16,
    );
  }
}

class _CustomSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const _CustomSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor:
                  activeColor ?? Theme.of(context).colorScheme.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _CustomListTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor ?? colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final NenThemeMode currentMode;
  final ValueChanged<NenThemeMode> onChanged;

  const _ThemeSegmentedControl({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegment(
            context,
            mode: NenThemeMode.dark,
            child: const Icon(Icons.nightlight_round, size: 20),
          ),
          _buildSegment(
            context,
            mode: NenThemeMode.system,
            child: const Text(
              'Auto',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          _buildSegment(
            context,
            mode: NenThemeMode.light,
            child: const Icon(Icons.wb_sunny_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required NenThemeMode mode,
    required Widget child,
  }) {
    final isSelected = currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: DefaultTextStyle(
            style: TextStyle(
              color: isSelected
                  ? Colors.black
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: isSelected
                    ? Colors.black
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
