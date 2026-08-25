import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/audio_repository_impl.dart';
import 'data/repositories/music_repository_impl.dart';
import 'data/repositories/settings_repository_impl.dart';
import 'data/services/nen_audio_handler.dart';
import 'data/services/permission_service.dart';
import 'presentation/providers/di_providers.dart';
import 'presentation/providers/playback_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/startup_gate.dart';
import 'presentation/theme/nen_theme.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for the immersive now-playing experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark system chrome
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: NenTheme.trueBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Shader compile is independent of first paint.
  unawaited(
    ui.FragmentProgram.fromAsset(
      'shaders/visualizer.frag',
    ).then((_) {}, onError: (_) {}),
  );

  // Onboarding/permission flags plus audio_service in parallel so a slow
  // MediaStore probe does not serialize behind AudioService.init.
  final audioRepo = AudioRepositoryImpl();
  final musicRepo = MusicRepositoryImpl();
  final settingsRepo = SettingsRepositoryImpl();
  final permissionService = PermissionService();
  final startup = await Future.wait<Object?>([
    settingsRepo.getHasSeenOnboarding(),
    permissionService.hasAudioPermission(),
    _initAudioHandlerWithFallback(audioRepo, musicRepo),
  ]);
  final hasSeenOnboarding = startup[0] as bool;
  final hasAudioPermission = startup[1] as bool;
  final globalAudioHandler = startup[2] as NenAudioHandler;

  runApp(
    ProviderScope(
      overrides: [
        audioRepositoryProvider.overrideWithValue(audioRepo),
        musicRepositoryProvider.overrideWithValue(musicRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        permissionServiceProvider.overrideWithValue(permissionService),
        audioHandlerProvider.overrideWithValue(globalAudioHandler),
        hasSeenOnboardingProvider.overrideWith((ref) => hasSeenOnboarding),
        hasAudioPermissionProvider.overrideWith((ref) => hasAudioPermission),
      ],
      child: const NenApp(),
    ),
  );
}

Future<NenAudioHandler> _initAudioHandlerWithFallback(
  AudioRepositoryImpl audioRepo,
  MusicRepositoryImpl musicRepo,
) async {
  try {
    return await initAudioHandler(
      audioRepo,
      musicRepo: musicRepo,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // If audio_service stalls/fails during startup, keep the app bootable.
    final handler = NenAudioHandler(audioRepo, musicRepo: musicRepo);
    await handler.init();
    return handler;
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
    // Load persisted settings (including accent color)
    Future.microtask(() async {
      try {
        await Future.wait([
          ref.read(settingsProvider.notifier).load(),
          ref.read(favoritesProvider.notifier).load(),
          ref.read(recentlyPlayedProvider.notifier).load(),
          ref.read(playlistsProvider.notifier).load(),
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

    // Update system chrome based on theme mode
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
