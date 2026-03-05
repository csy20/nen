import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import 'library_screen.dart';

/// Splash / permission gate screen.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  bool _loading = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final service = ref.read(permissionServiceProvider);
    final granted = await service.hasAudioPermission();
    if (granted) {
      _onGranted();
    } else {
      setState(() {
        _loading = false;
        _granted = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    final service = ref.read(permissionServiceProvider);
    final granted = await service.requestAudioPermission();
    if (granted) {
      _onGranted();
    } else {
      setState(() {
        _loading = false;
        _granted = false;
      });
    }
  }

  void _onGranted() {
    // Audio engine is already initialized in main() via NenAudioHandler
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LibraryScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NenTheme.trueBlack,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'nen',
                      style: TextStyle(
                        color: NenTheme.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nen needs access to your music library to play songs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NenTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Grant Permission',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (!_granted) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'We only access audio files on your device.\nNo data is collected or uploaded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: NenTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
