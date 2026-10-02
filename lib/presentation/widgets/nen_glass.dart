import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// Glass controls become opaque immediately when High Contrast is enabled.
class NenGlass extends ConsumerWidget {
  const NenGlass({super.key, required this.child, this.blurSigma = 12});

  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = ref.watch(
      settingsProvider.select((s) => s.highContrast),
    );
    if (highContrast) {
      return ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF141414)
            : Colors.white,
        child: child,
      );
    }
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: child,
    );
  }
}
