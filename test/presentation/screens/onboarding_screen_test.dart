import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/permission_service.dart';
import 'package:nen/domain/repositories/settings_repository.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/providers/settings_provider.dart';
import 'package:nen/presentation/screens/onboarding_screen.dart';
import 'package:nen/presentation/screens/startup_gate.dart';
import 'package:nen/presentation/theme/nen_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsRepository implements SettingsRepository {
  bool hasSeenOnboarding = false;

  @override
  Future<bool> getHasSeenOnboarding() async => hasSeenOnboarding;

  @override
  Future<void> setHasSeenOnboarding(bool value) async {
    hasSeenOnboarding = value;
  }

  @override
  Future<int> getAccentColor() async => 0;

  @override
  Future<bool> getCrossfadeEnabled() async => false;

  @override
  Future<int> getCrossfadeDuration() async => 3;

  @override
  Future<List<int>> getFavoriteIds() async => const [];

  @override
  Future<double> getPlaybackSpeed() async => 1.0;

  @override
  Future<List<int>> getRecentSongIds() async => const [];

  @override
  Future<bool> getReduceFlash() async => false;

  @override
  Future<bool> getReduceMotion() async => false;

  @override
  Future<bool> getHighContrast() async => false;

  @override
  Future<int> getThemeMode() async => 0;

  @override
  Future<double> getVolume() async => 1.0;

  @override
  Future<void> setAccentColor(int value) async {}

  @override
  Future<void> setCrossfadeDuration(int seconds) async {}

  @override
  Future<void> setCrossfadeEnabled(bool value) async {}

  @override
  Future<void> setFavoriteIds(List<int> ids) async {}

  @override
  Future<void> setPlaybackSpeed(double value) async {}

  @override
  Future<void> setRecentSongIds(List<int> ids) async {}

  @override
  Future<void> setReduceFlash(bool value) async {}

  @override
  Future<void> setReduceMotion(bool value) async {}

  @override
  Future<void> setHighContrast(bool value) async {}

  @override
  Future<void> setThemeMode(int value) async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  Future<bool> getEqualizerActive() async => false;

  @override
  Future<void> setEqualizerActive(bool value) async {}

  @override
  Future<List<double>> getEqualizerBands() async => List.filled(8, 1.0);

  @override
  Future<void> setEqualizerBands(List<double> bands) async {}

  @override
  Future<LastPlaybackSession?> getLastPlaybackSession() async => null;

  @override
  Future<void> setLastPlaybackSession(LastPlaybackSession? session) async {}
}

class _DeniedPermissionService extends PermissionService {
  @override
  Future<bool> hasAudioPermission() async => false;

  @override
  Future<bool> requestAudioPermission() async => false;
}

Widget _wrap(
  Widget child, {
  _FakeSettingsRepository? repo,
  PermissionService? permissionService,
  bool hasSeenOnboarding = false,
  bool hasAudioPermission = false,
}) {
  return ProviderScope(
    overrides: [
      if (repo != null) settingsRepositoryProvider.overrideWithValue(repo),
      if (permissionService != null)
        permissionServiceProvider.overrideWithValue(permissionService),
      hasSeenOnboardingProvider.overrideWith((ref) => hasSeenOnboarding),
      hasAudioPermissionProvider.overrideWith((ref) => hasAudioPermission),
    ],
    child: MaterialApp(theme: NenTheme.buildDark(), home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows welcome copy, skip, and next on first page', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen(onCompleted: _noop)));

    expect(find.text('Welcome to nen'), findsOneWidget);
    expect(find.textContaining('lightweight offline'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_next')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_dots')), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
  });

  testWidgets('Next walks through all pages to Get Started', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen(onCompleted: _noop)));

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Browse local music'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Playback controls'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    expect(find.text('Ready when you are'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_get_started')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_skip')), findsOneWidget);
  });

  testWidgets('Skip persists the onboarding flag and invokes onCompleted', (
    tester,
  ) async {
    final repo = _FakeSettingsRepository();
    var completed = false;

    await tester.pumpWidget(
      _wrap(
        OnboardingScreen(onCompleted: () => completed = true),
        repo: repo,
      ),
    );

    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pump();
    await tester.pump();

    expect(repo.hasSeenOnboarding, isTrue);
    expect(completed, isTrue);
  });

  testWidgets('Get Started persists the onboarding flag', (tester) async {
    final repo = _FakeSettingsRepository();
    var completed = false;

    await tester.pumpWidget(
      _wrap(
        OnboardingScreen(onCompleted: () => completed = true),
        repo: repo,
      ),
    );

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('onboarding_next')));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('onboarding_get_started')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_get_started')));
    await tester.pump();
    await tester.pump();

    expect(repo.hasSeenOnboarding, isTrue);
    expect(completed, isTrue);
  });

  testWidgets('StartupGate shows onboarding when flag is false', (
    tester,
  ) async {
    final repo = _FakeSettingsRepository();
    await tester.pumpWidget(_wrap(const StartupGate(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to nen'), findsOneWidget);
  });

  testWidgets('StartupGate skips onboarding when flag is true', (tester) async {
    final repo = _FakeSettingsRepository()..hasSeenOnboarding = true;
    await tester.pumpWidget(
      _wrap(
        const StartupGate(),
        repo: repo,
        permissionService: _DeniedPermissionService(),
        hasSeenOnboarding: true,
      ),
    );
    await tester.pump();

    expect(find.text('Welcome to nen'), findsNothing);
    expect(find.text('Grant Permission'), findsOneWidget);
  });

  testWidgets('StartupGate does not flash onboarding when already completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const StartupGate(),
        permissionService: _DeniedPermissionService(),
        hasSeenOnboarding: true,
      ),
    );

    expect(find.text('Welcome to nen'), findsNothing);
    expect(find.byKey(const Key('onboarding_skip')), findsNothing);
  });

}

void _noop() {}
