import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/providers.dart';
import '../theme/nen_theme.dart';
import 'home_screen.dart';

/// Splash / permission gate screen.
class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  static const _permissionTimeout = Duration(seconds: 8);

  bool _loading = true;
  bool _granted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final service = ref.read(permissionServiceProvider);
      final granted = await service.hasAudioPermission().timeout(
        _permissionTimeout,
      );
      if (granted) {
        _onGranted();
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _granted = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _granted = false;
        _errorMessage =
            'Unable to check media permission right now. Please try again.';
      });
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(permissionServiceProvider);
      final granted = await service.requestAudioPermission().timeout(
        _permissionTimeout,
      );
      if (granted) {
        _onGranted();
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _granted = false;
        _errorMessage =
            'Permission not granted. You can grant it in app settings.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _granted = false;
        _errorMessage = 'Permission request timed out. Please try again.';
      });
    }
  }

  void _onGranted() {
    // Audio engine is already initialized in main() via NenAudioHandler.
    // Schedule navigation after frame to avoid lifecycle race conditions.
    if (!mounted) return;
    setState(() {
      _granted = true;
      _loading = false;
      _errorMessage = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 32),
                    // nen branding with glow
                    Text(
                      'nen',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: NenTheme.defaultAccent.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'music player',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'nen needs access to your music library to play songs.',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              NenRadius.button,
                            ),
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
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: openAppSettings,
                          child: const Text('Open App Settings'),
                        ),
                      ),
                    ],
                    if (!_granted) ...[
                      const SizedBox(height: 12),
                      Text(
                        'We only access audio files on your device.\nNo data is collected or uploaded.',
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: colors.textTertiary,
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
