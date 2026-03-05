import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';

/// Settings screen with accessibility toggles.
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
}
