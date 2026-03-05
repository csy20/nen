import 'package:flutter/material.dart';

/// Nen app dark theme with true black background, glassmorphic and neumorphic styles.
class NenTheme {
  NenTheme._();

  static const Color trueBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF0A0A0A);
  static const Color surfaceElevated = Color(0xFF141414);
  static const Color surfaceOverlay = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF666666);
  static const Color defaultAccent = Color(0xFF6C5CE7);

  /// Build the app theme with an optional dynamic accent color.
  static ThemeData build({Color? accentColor}) {
    final accent = accentColor ?? defaultAccent;
    final colorScheme = ColorScheme.dark(
      surface: trueBlack,
      primary: accent,
      secondary: accent.withValues(alpha: 0.7),
      onPrimary: Colors.white,
      onSurface: textPrimary,
      onSecondary: Colors.white,
      error: const Color(0xFFCF6679),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: trueBlack,
      colorScheme: colorScheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: textTertiary, fontSize: 12),
        labelLarge: TextStyle(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceOverlay,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: trueBlack,
        selectedItemColor: accent,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return textTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.4);
          }
          return surfaceOverlay;
        }),
      ),
    );
  }
}

/// Glassmorphic container decoration.
BoxDecoration glassmorphicDecoration({
  Color? color,
  double borderRadius = 20,
  double opacity = 0.08,
}) {
  return BoxDecoration(
    color: (color ?? Colors.white).withValues(alpha: opacity),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.06),
      width: 1,
    ),
  );
}

/// Neumorphic box decoration for playback controls.
BoxDecoration neumorphicDecoration({
  Color baseColor = const Color(0xFF0A0A0A),
  double borderRadius = 50,
  bool isPressed = false,
}) {
  return BoxDecoration(
    color: baseColor,
    borderRadius: BorderRadius.circular(borderRadius),
    boxShadow: isPressed
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.03),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(4, 4),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.05),
              offset: const Offset(-4, -4),
              blurRadius: 8,
            ),
          ],
  );
}
