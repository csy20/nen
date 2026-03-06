import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/audio_repository_impl.dart';
import 'data/services/nen_audio_handler.dart';
import 'presentation/providers/di_providers.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/permission_screen.dart';
import 'presentation/theme/nen_theme.dart';

late final NenAudioHandler globalAudioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait for the immersive now-playing experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark system chrome
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: NenTheme.trueBlack,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Pre-warm the visualizer shader to avoid first-render jank
  try {
    await ui.FragmentProgram.fromAsset('shaders/visualizer.frag');
  } catch (_) {
    // Shader may not be available on all platforms
  }

  // Initialize background audio service
  final audioRepo = AudioRepositoryImpl();
  globalAudioHandler = await initAudioHandler(audioRepo);

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

class NenApp extends ConsumerStatefulWidget {
  const NenApp({super.key});

  @override
  ConsumerState<NenApp> createState() => _NenAppState();
}

class _NenAppState extends ConsumerState<NenApp> {
  @override
  void initState() {
    super.initState();
    // Load persisted settings (including accent color)
    Future.microtask(() {
      ref.read(settingsProvider.notifier).load();
      ref.read(favoritesProvider.notifier).load();
      ref.read(recentlyPlayedProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'Nen',
      debugShowCheckedModeBanner: false,
      theme: NenTheme.build(accentColor: settings.customAccentColor),
      home: const PermissionScreen(),
    );
  }
}
