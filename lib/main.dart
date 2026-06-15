import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/audio_repository_impl.dart';
import 'data/services/nen_audio_handler.dart';
import 'presentation/providers/di_providers.dart';
import 'presentation/providers/playback_provider.dart';
import 'presentation/providers/playlist_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/permission_screen.dart';
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

  // Pre-warm the visualizer shader to avoid first-render jank
  try {
    await ui.FragmentProgram.fromAsset('shaders/visualizer.frag');
  } catch (_) {
    // Shader may not be available on all platforms
  }

  // Initialize background audio service
  final audioRepo = AudioRepositoryImpl();
  final globalAudioHandler = await _initAudioHandlerWithFallback(audioRepo);

  runApp(
    ProviderScope(
      overrides: [
        audioRepositoryProvider.overrideWithValue(audioRepo),
        audioHandlerProvider.overrideWithValue(globalAudioHandler),
      ],
      child: const NenApp(),
    ),
  );
}

Future<NenAudioHandler> _initAudioHandlerWithFallback(
  AudioRepositoryImpl audioRepo,
) async {
  try {
    return await initAudioHandler(
      audioRepo,
    ).timeout(const Duration(seconds: 8));
  } catch (_) {
    // If audio_service stalls/fails during startup, keep the app bootable.
    final handler = NenAudioHandler(audioRepo);
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
  bool _lastIsDark = true;

  @override
  void initState() {
    super.initState();
    // Load persisted settings (including accent color)
    Future.microtask(() {
      ref.read(settingsProvider.notifier).load();
      ref.read(favoritesProvider.notifier).load();
      ref.read(recentlyPlayedProvider.notifier).load();
      ref.read(playlistsProvider.notifier).load();
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
      home: const PermissionScreen(),
    );
  }
}
