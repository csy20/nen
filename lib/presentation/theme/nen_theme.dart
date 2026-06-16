import 'package:flutter/material.dart';

// ── Design Tokens ───────────────────────────────────────────────────
// Japanese glassmorphic aesthetic with Ma whitespace principles.

/// Border radius tokens.
class NenRadius {
  NenRadius._();
  static const double card = 16;
  static const double button = 12;
  static const double modal = 24;
  static const double pill = 999;
}

/// Shadow tokens for layered depth.
class NenShadows {
  NenShadows._();

  static final List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      offset: const Offset(0, 1),
      blurRadius: 4,
    ),
  ];

  static final List<BoxShadow> elevated = [
    BoxShadow(
      color: const Color(0xFF1F2687).withValues(alpha: 0.25),
      offset: const Offset(0, 8),
      blurRadius: 32,
    ),
  ];

  static final List<BoxShadow> inner = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
  ];
}

/// Nen app theme with dark-first Japanese glassmorphic aesthetic.
/// Supports both dark and light modes via [buildDark] and [buildLight].
class NenTheme {
  NenTheme._();

  // ── Dark Mode Palette ──────────────────────────────────────────────
  static const Color trueBlack = Color(0xFF000000);
  static const Color backgroundPrimaryDark = Color(0xFF1A1A2E);
  static const Color backgroundSecondaryDark = Color(0xFF16213E);
  static const Color surfaceDark = Color(0xFF0A0A0A);
  static const Color surfaceElevated = Color(0xFF141414);
  static const Color surfaceOverlay = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF666666);

  // ── Light Mode Palette ─────────────────────────────────────────────
  static const Color backgroundPrimaryLight = Color(0xFFF5F5F0);
  static const Color backgroundSecondaryLight = Color(0xFFEAEAE5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedLight = Color(0xFFF0F0EB);
  static const Color surfaceOverlayLight = Color(0xFFE8E8E3);
  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF5A5A6E);
  static const Color textTertiaryLight = Color(0xFF9999AA);

  // ── Brand / Accent ─────────────────────────────────────────────────
  static const Color defaultAccent = Color(0xFF8B7EC8); // wisteria purple

  // ── Glass Surface Colors ───────────────────────────────────────────
  static Color glassSurfaceDark = Colors.white.withValues(alpha: 0.08);
  static Color glassSurfaceLight = Colors.white.withValues(alpha: 0.7);
  static Color glassBorderDark = Colors.white.withValues(alpha: 0.12);
  static Color glassBorderLight = Colors.black.withValues(alpha: 0.08);

  // ── Typography constants ───────────────────────────────────────────
  static const String _fontFamily = 'Noto Sans JP';
  static const List<String> _fontFamilyFallback = [
    'Inter',
    '-apple-system',
    'BlinkMacSystemFont',
    'sans-serif',
  ];

  /// Build the dark theme with an optional dynamic accent color.
  static ThemeData buildDark({Color? accentColor}) {
    final accent = accentColor ?? defaultAccent;
    return _buildTheme(
      brightness: Brightness.dark,
      accent: accent,
      scaffoldBg: trueBlack,
      surface: trueBlack,
      surfaceElevatedColor: surfaceElevated,
      overlayColor: surfaceOverlay,
      textPrimaryColor: textPrimary,
      textSecondaryColor: textSecondary,
      textTertiaryColor: textTertiary,
      navBarBg: trueBlack,
    );
  }

  /// Build the light theme with an optional dynamic accent color.
  static ThemeData buildLight({Color? accentColor}) {
    final accent = accentColor ?? defaultAccent;
    return _buildTheme(
      brightness: Brightness.light,
      accent: accent,
      scaffoldBg: backgroundPrimaryLight,
      surface: backgroundPrimaryLight,
      surfaceElevatedColor: surfaceElevatedLight,
      overlayColor: surfaceOverlayLight,
      textPrimaryColor: textPrimaryLight,
      textSecondaryColor: textSecondaryLight,
      textTertiaryColor: textTertiaryLight,
      navBarBg: backgroundPrimaryLight,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color accent,
    required Color scaffoldBg,
    required Color surface,
    required Color surfaceElevatedColor,
    required Color overlayColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color textTertiaryColor,
    required Color navBarBg,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = isDark
        ? ColorScheme.dark(
            surface: surface,
            primary: accent,
            secondary: accent.withValues(alpha: 0.7),
            onPrimary: Colors.white,
            onSurface: textPrimaryColor,
            onSecondary: Colors.white,
            error: const Color(0xFFCF6679),
          )
        : ColorScheme.light(
            surface: surface,
            primary: accent,
            secondary: accent.withValues(alpha: 0.7),
            onPrimary: Colors.white,
            onSurface: textPrimaryColor,
            onSecondary: Colors.white,
            error: const Color(0xFFB00020),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false, // Left-aligned branding
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontFamilyFallback: _fontFamilyFallback,
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevatedColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NenRadius.card),
        ),
      ),
      iconTheme: IconThemeData(color: textSecondaryColor),
      textTheme: TextTheme(
        // Display — for branding
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          color: textPrimaryColor,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          height: 1.6,
        ),
        bodyMedium: TextStyle(color: textSecondaryColor, fontSize: 14),
        bodySmall: TextStyle(color: textTertiaryColor, fontSize: 12),
        labelLarge: TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: TextStyle(color: textTertiaryColor, fontSize: 11),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: overlayColor,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
        trackHeight: 3,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBarBg,
        selectedItemColor: accent,
        unselectedItemColor: textTertiaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return textTertiaryColor;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.4);
          }
          return overlayColor;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevatedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NenRadius.modal),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevatedColor,
        contentTextStyle: TextStyle(color: textPrimaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NenRadius.button),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // Accessibility: visible focus indicators
      focusColor: accent.withValues(alpha: 0.3),
      hoverColor: accent.withValues(alpha: 0.1),
      highlightColor: accent.withValues(alpha: 0.15),
      splashColor: accent.withValues(alpha: 0.2),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevatedColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NenRadius.button),
          borderSide: BorderSide(color: textTertiaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NenRadius.button),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        labelStyle: TextStyle(color: textSecondaryColor),
        hintStyle: TextStyle(color: textTertiaryColor),
      ),
    );
  }

  // ── Helper: resolve colors by brightness ───────────────────────────
  /// Get context-aware colors based on current theme brightness.
  static NenColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return NenColors(isDark: isDark);
  }
}

/// Context-aware color accessor for theme-dependent values.
class NenColors {
  final bool isDark;
  const NenColors({required this.isDark});

  Color get background =>
      isDark ? NenTheme.trueBlack : NenTheme.backgroundPrimaryLight;
  Color get backgroundSecondary => isDark
      ? NenTheme.backgroundSecondaryDark
      : NenTheme.backgroundSecondaryLight;
  Color get surface => isDark ? NenTheme.surfaceDark : NenTheme.surfaceLight;
  Color get surfaceElevated =>
      isDark ? NenTheme.surfaceElevated : NenTheme.surfaceElevatedLight;
  Color get surfaceOverlay =>
      isDark ? NenTheme.surfaceOverlay : NenTheme.surfaceOverlayLight;
  Color get textPrimary =>
      isDark ? NenTheme.textPrimary : NenTheme.textPrimaryLight;
  Color get textSecondary =>
      isDark ? NenTheme.textSecondary : NenTheme.textSecondaryLight;
  Color get textTertiary =>
      isDark ? NenTheme.textTertiary : NenTheme.textTertiaryLight;
  Color get glassSurface =>
      isDark ? NenTheme.glassSurfaceDark : NenTheme.glassSurfaceLight;
  Color get glassBorder =>
      isDark ? NenTheme.glassBorderDark : NenTheme.glassBorderLight;
}

/// Glassmorphic container decoration — theme-aware.
BoxDecoration glassmorphicDecoration({
  Color? color,
  double borderRadius = 20,
  double opacity = 0.08,
  bool isDark = true,
}) {
  final surfaceColor = isDark
      ? (color ?? Colors.white).withValues(alpha: opacity)
      : (color ?? Colors.white).withValues(alpha: 0.7);
  final borderColor = isDark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.08);

  return BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(color: borderColor, width: 1),
    boxShadow: NenShadows.card,
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

/// Theme mode options for the app.
enum NenThemeMode { dark, light, system }
