import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/audio_repository_impl.dart';
import 'data/services/nen_audio_handler.dart';
import 'presentation/providers/di_providers.dart';
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

class NenApp extends StatelessWidget {
  const NenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nen',
      debugShowCheckedModeBanner: false,
      theme: NenTheme.build(),
      home: const PermissionScreen(),
    );
  }
}
