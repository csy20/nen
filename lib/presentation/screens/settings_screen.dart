import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Settings screen with accessibility, playback, appearance, and about sections.
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 16),

          // Accessibility section
          _sectionHeader('Accessibility'),

          SwitchListTile(
            title: Text('Reduce Motion',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Reduces animations and visualizer motion effects',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            value: settings.reduceMotion,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleReduceMotion(),
          ),

          SwitchListTile(
            title: Text('Reduce Flash',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Disables rapid brightness changes in the visualizer',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            value: settings.reduceFlash,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleReduceFlash(),
          ),

          SwitchListTile(
            title: Text('High Contrast',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Increases borders and removes blur effects',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            value: settings.highContrast,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleHighContrast(),
          ),

          Divider(color: colors.surfaceOverlay, height: 32),

          // Playback section
          _sectionHeader('Playback'),

          SwitchListTile(
            title: Text('Crossfade',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Smooth ${settings.crossfadeDuration}s transition between tracks',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            value: settings.crossfadeEnabled,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleCrossfade(),
          ),

          if (settings.crossfadeEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Duration',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: settings.crossfadeDuration.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${settings.crossfadeDuration}s',
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setCrossfadeDuration(v.toInt()),
                    ),
                  ),
                  Text('${settings.crossfadeDuration}s',
                      style: TextStyle(
                          color: colors.textTertiary, fontSize: 12)),
                ],
              ),
            ),

          Divider(color: colors.surfaceOverlay, height: 32),

          // Appearance section
          _sectionHeader('Appearance'),

          // Theme mode selector
          ListTile(
            title: Text('Theme',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              settings.themeMode == NenThemeMode.dark
                  ? 'Dark'
                  : settings.themeMode == NenThemeMode.light
                      ? 'Light'
                      : 'System',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            trailing: SegmentedButton<NenThemeMode>(
              segments: const [
                ButtonSegment(
                  value: NenThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded, size: 18),
                ),
                ButtonSegment(
                  value: NenThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded, size: 18),
                ),
                ButtonSegment(
                  value: NenThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded, size: 18),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(settingsProvider.notifier)
                    .setThemeMode(selection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          ListTile(
            title: Text('Accent Color',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              settings.customAccentColor != null
                  ? 'Custom color set'
                  : 'Dynamic from album art',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: settings.customAccentColor ?? NenTheme.defaultAccent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
            ),
            onTap: () => _showColorPicker(context),
          ),

          Divider(color: colors.surfaceOverlay, height: 32),

          // Library section
          _sectionHeader('Library'),

          ListTile(
            title: Text('Rescan Media',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Scan device for new music files',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            leading: Icon(Icons.refresh_rounded,
                color: colors.textSecondary),
            onTap: () => _rescanMedia(context),
          ),

          Divider(color: colors.surfaceOverlay, height: 32),

          // About section
          _sectionHeader('About'),

          ListTile(
            title: Text('nen Music Player',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Version 1.0.0\nOffline music with real-time visualizer',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ),

          ListTile(
            title: Text('Audio Engine',
                style: TextStyle(color: colors.textPrimary)),
            subtitle: Text(
              'Powered by flutter_soloud (C++ SoLoud)',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = NenTheme.of(context);
    final colorOptions = [
      null, // dynamic / reset
      const Color(0xFF8B7EC8), // wisteria (default accent)
      const Color(0xFFE84393),
      const Color(0xFF00B894),
      const Color(0xFF0984E3),
      const Color(0xFFFD79A8),
      const Color(0xFFE17055),
      const Color(0xFF00CEC9),
      const Color(0xFFA29BFE),
      const Color(0xFFFFBE76),
      const Color(0xFFFF6B6B),
      const Color(0xFF48DBFB),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(NenRadius.modal)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Accent Color',
                style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colorOptions.map((color) {
                final isSelected = color == ref.read(settingsProvider).customAccentColor ||
                    (color == null && ref.read(settingsProvider).customAccentColor == null);
                return GestureDetector(
                  onTap: () {
                    ref.read(settingsProvider.notifier).setAccentColor(color);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color ?? NenTheme.defaultAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: color == null
                        ? const Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _rescanMedia(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning for new media...')),
    );
    try {
      await ref.read(musicRepositoryProvider).rescanMedia();
      ref.invalidate(songsProvider);
      ref.invalidate(albumsProvider);
      ref.invalidate(artistsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media scan complete')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    }
  }
}
