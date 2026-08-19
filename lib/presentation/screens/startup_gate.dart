import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../theme/nen_theme.dart';
import 'onboarding_screen.dart';
import 'permission_screen.dart';

/// Chooses first-launch onboarding or the permission gate.
class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = ref.watch(hasSeenOnboardingProvider);
    return seen.when(
      loading: () => const _LaunchSplash(),
      error: (_, _) => const PermissionScreen(),
      data: (hasSeen) =>
          hasSeen ? const PermissionScreen() : const OnboardingScreen(),
    );
  }
}

class _LaunchSplash extends StatelessWidget {
  const _LaunchSplash();

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Text(
          'nen',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: NenTheme.defaultAccent.withValues(alpha: 0.6),
                blurRadius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
