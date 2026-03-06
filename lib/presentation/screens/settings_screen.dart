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

    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 16),

          // Accessibility section
          _sectionHeader('Accessibility'),

          SwitchListTile(
            title: const Text('Reduce Motion',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: const Text(
              'Reduces animations and visualizer motion effects',
              style: TextStyle(color: NenTheme.textTertiary, fontSize: 12),
            ),
            value: settings.reduceMotion,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleReduceMotion(),
          ),

          SwitchListTile(
            title: const Text('Reduce Flash',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: const Text(
              'Disables rapid brightness changes in the visualizer',
              style: TextStyle(color: NenTheme.textTertiary, fontSize: 12),
            ),
            value: settings.reduceFlash,
            onChanged: (_) =>
                ref.read(settingsProvider.notifier).toggleReduceFlash(),
          ),

          const Divider(color: NenTheme.surfaceOverlay, height: 32),

          // Playback section
          _sectionHeader('Playback'),

          SwitchListTile(
            title: const Text('Crossfade',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: Text(
              'Smooth ${settings.crossfadeDuration}s transition between tracks',
              style: const TextStyle(color: NenTheme.textTertiary, fontSize: 12),
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
                  const Text('Duration',
                      style: TextStyle(color: NenTheme.textSecondary, fontSize: 13)),
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
                      style: const TextStyle(
                          color: NenTheme.textTertiary, fontSize: 12)),
                ],
              ),
            ),

          const Divider(color: NenTheme.surfaceOverlay, height: 32),

          // Appearance section
          _sectionHeader('Appearance'),

          ListTile(
            title: const Text('Accent Color',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: Text(
              settings.customAccentColor != null
                  ? 'Custom color set'
                  : 'Dynamic from album art',
              style: const TextStyle(color: NenTheme.textTertiary, fontSize: 12),
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

          const Divider(color: NenTheme.surfaceOverlay, height: 32),

          // Library section
          _sectionHeader('Library'),

          ListTile(
            title: const Text('Rescan Media',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: const Text(
              'Scan device for new music files',
              style: TextStyle(color: NenTheme.textTertiary, fontSize: 12),
            ),
            leading: const Icon(Icons.refresh_rounded,
                color: NenTheme.textSecondary),
            onTap: () => _rescanMedia(context),
          ),

          const Divider(color: NenTheme.surfaceOverlay, height: 32),

          // About section
          _sectionHeader('About'),

          const ListTile(
            title: Text('Nen Music Player',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: Text(
              'Version 1.0.0\nOffline music with real-time visualizer',
              style: TextStyle(color: NenTheme.textTertiary, fontSize: 12),
            ),
          ),

          const ListTile(
            title: Text('Audio Engine',
                style: TextStyle(color: NenTheme.textPrimary)),
            subtitle: Text(
              'Powered by flutter_soloud (C++ SoLoud)',
              style: TextStyle(color: NenTheme.textTertiary, fontSize: 12),
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
    final colors = [
      null, // dynamic / reset
      const Color(0xFF6C5CE7),
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
      backgroundColor: NenTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose Accent Color',
                style: TextStyle(
                    color: NenTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
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
