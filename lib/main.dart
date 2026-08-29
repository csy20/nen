import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/audio_repository_impl.dart';
import 'data/repositories/music_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/services/nen_audio_handler.dart';
import 'data/services/permission_service.dart';
import 'presentation/providers/di_providers.dart';
import 'presentation/providers/equalizer_provider.dart';
import 'presentation/providers/playback_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/startup_gate.dart';
import 'presentation/theme/nen_theme.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('PlatformDispatcher error: $error');
        return true;
      };
      unawaited(_boot());
    },
    (error, stack) {
      debugPrint('zone error: $error\n$stack');
    },
  );
}

Future<void> _boot() async {
  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: NenTheme.trueBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  } catch (e) {
    debugPrint('chrome setup error: $e');
  }

  final audioRepo = AudioRepositoryImpl();
  final musicRepo = MusicRepositoryImpl();
  final settingsRepo = SettingsRepositoryImpl();
  final permissionService = PermissionService();

  var hasSeenOnboarding = false;
  var hasAudioPermission = false;
  late NenAudioHandler handler;

  try {
    handler = NenAudioHandler(audioRepo, musicRepo: musicRepo);
    await handler.init();
  } catch (e) {
    debugPrint('local audio handler init error: $e');
    handler = NenAudioHandler(audioRepo, musicRepo: musicRepo);
  }

  try {
    hasSeenOnboarding = await settingsRepo.getHasSeenOnboarding();
  } catch (e) {
    debugPrint('onboarding flag error: $e');
  }
  try {
    hasAudioPermission = await permissionService.hasAudioPermission();
  } catch (e) {
    debugPrint('permission probe error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        audioRepositoryProvider.overrideWithValue(audioRepo),
        musicRepositoryProvider.overrideWithValue(musicRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        permissionServiceProvider.overrideWithValue(permissionService),
        audioHandlerProvider.overrideWithValue(handler),
        hasSeenOnboardingProvider.overrideWith((ref) => hasSeenOnboarding),
        hasAudioPermissionProvider.overrideWith((ref) => hasAudioPermission),
      ],
      child: const NenApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_promoteAudioService(audioRepo, musicRepo, handler));
  });
}

Future<void> _promoteAudioService(
  AudioRepositoryImpl audioRepo,
  MusicRepositoryImpl musicRepo,
  NenAudioHandler existing,
) async {
  try {
    await initAudioHandler(
      audioRepo,
      musicRepo: musicRepo,
      existing: existing,
    ).timeout(const Duration(seconds: 6));
    existing.syncFromEngine();
  } catch (e) {
    debugPrint('audio_service optional init failed: $e');
  }
}

class NenApp extends ConsumerStatefulWidget {
  const NenApp({super.key});

  @override
  ConsumerState<NenApp> createState() => _NenAppState();
}

class _NenAppState extends ConsumerState<NenApp> {
  late final ProviderSubscription<PlaybackFeedbackMessage?>
  _feedbackSubscription;
  bool _lastIsDark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await Future.wait([
          ref.read(settingsProvider.notifier).load(),
          ref.read(favoritesProvider.notifier).load(),
          ref.read(recentlyPlayedProvider.notifier).load(),
          ref.read(playlistsProvider.notifier).load(),
          ref.read(equalizerProvider.notifier).load(),
        ]);
      } catch (e) {
        debugPrint('Failed to load initial data: $e');
      }
    });
    _feedbackSubscription = ref.listenManual(playbackFeedbackProvider, (
      _,
      next,
    ) {
      if (next == null) {
        return;
      }

      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.message)));
      ref.read(playbackFeedbackProvider.notifier).clear(next.id);
    });
  }

  @override
  void dispose() {
    _feedbackSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final isDark =
        settings.themeMode == NenThemeMode.dark ||
        (settings.themeMode == NenThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    if (isDark != _lastIsDark) {
      _lastIsDark = isDark;
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark
              ? NenTheme.trueBlack
              : NenTheme.backgroundPrimaryLight,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
      );
    }

    return MaterialApp(
      title: 'nen',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: NenTheme.buildLight(accentColor: settings.customAccentColor),
      darkTheme: NenTheme.buildDark(accentColor: settings.customAccentColor),
      themeMode: settings.flutterThemeMode,
      home: const StartupGate(),
    );
  }
}
