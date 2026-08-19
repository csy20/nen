import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'permission_screen.dart';

/// Chooses first-launch onboarding, the permission gate, or home.
/// Flags are preloaded in `main()` so this never flashes the wrong screen.
class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeen = ref.watch(hasSeenOnboardingProvider);
    if (!hasSeen) return const OnboardingScreen();
    final hasPermission = ref.watch(hasAudioPermissionProvider);
    if (!hasPermission) return const PermissionScreen();
    return const HomeScreen();
  }
}
