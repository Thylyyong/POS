import 'package:flutter/material.dart';
export 'core/theme/color_theme.dart';
import 'core/theme/color_theme.dart';

class AppConfig {
  static const String appName = 'OmniPOS Dual-Screen';
  static const String appVersion = '1.0.0';
  static const String defaultCurrency = '\$';
  static const double defaultTaxRate = 10.0;

  // ── Light Theme Palette (aligned with ColorTheme) ──────────────────
  // Backgrounds
  static const Color bgBase        = ColorTheme.screenBg; // Color(0xFFF5F5F5)
  static const Color bgSurface     = ColorTheme.cardBg;   // Color(0xFFFFFFFF)
  static const Color bgMuted       = ColorTheme.neutral100; // Color(0xFFF2F2F2)
  static const Color bgDark        = ColorTheme.primary600; // Color(0xFF111935)

  // Borders
  static const Color border        = ColorTheme.neutral300; // Color(0xFFE0E0E0)
  static const Color borderStrong  = ColorTheme.neutral200; // Color(0xFFCACACA)

  // Sidebar / Nav
  static const Color sidebarBg     = ColorTheme.cardBg;     // Color(0xFFFFFFFF)
  static const Color sidebarBorder = ColorTheme.neutral300; // Color(0xFFE0E0E0)

  // Brand / Accents
  static const Color accentPrimary    = ColorTheme.buttonPrimary; // Color(0xFF0D9488)
  static const Color accentBlue       = ColorTheme.primary500;    // Color(0xFF0D9488) - Clean Teal
  static const Color accentTeal       = Color(0xFF0D9488);
  static const Color accentCyan       = Color(0xFF0891B2);
  static const Color accentAmber      = ColorTheme.semanticOrange; // Color(0xFFF97316)
  static const Color accentRose       = ColorTheme.semanticRed;    // Color(0xFFEF4444)
  static const Color accentPurple     = Color(0xFF8B5CF6);
  static const Color accentOrange     = ColorTheme.semanticOrange; // Color(0xFFF97316)

  // Emerald/Green
  static const Color accentGreen      = ColorTheme.semanticGreen;  // Color(0xFF12974F)
  static const Color accentGreenDark  = Color(0xFF0F7D41);

  // Text
  static const Color textPrimary   = ColorTheme.textPrimary;    // Color(0xFF0F172A)
  static const Color textSecondary = ColorTheme.textSecondary;  // Color(0xFF475569)
  static const Color textMuted     = ColorTheme.textMuted;      // Color(0xFF94A3B8)
  static const Color textOnDark    = Color(0xFFFFFFFF);

  // Legacy aliases
  static const Color primaryDark    = ColorTheme.primary600;
  static const Color primarySurface = ColorTheme.primary400;
  static const Color primaryCard    = ColorTheme.grey;
  static const Color surfaceBorder  = ColorTheme.neutral300;

  // Category color palette
  static const List<Color> categoryColors = [
    ColorTheme.primary400,
    ColorTheme.primary500,
    ColorTheme.secondary400,
    ColorTheme.semanticGreen,
    ColorTheme.semanticOrange,
    ColorTheme.semanticBlue,
    ColorTheme.semanticRed,
    ColorTheme.grey,
  ];

  // Table status colors
  static const Color tableAvailable    = ColorTheme.statusGreen;
  static const Color tableOccupied     = ColorTheme.statusOrange;
  static const Color tableBillRequest  = ColorTheme.primary500;

  // ── Light ThemeData ───────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgBase,
      primaryColor: accentPrimary,
      colorScheme: const ColorScheme.light(
        primary: accentPrimary,
        secondary: accentBlue,
        surface: bgSurface,
        surfaceContainerHighest: bgMuted,
        error: accentRose,
        onPrimary: Colors.white,
        onSurface: textPrimary,
        outline: border,
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.03),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgSurface,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 26, fontWeight: FontWeight.bold,   color: textPrimary, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,   color: textPrimary, letterSpacing: -0.4),
        headlineSmall:  TextStyle(fontSize: 17, fontWeight: FontWeight.w700,   color: textPrimary, letterSpacing: -0.3),
        titleLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w600,   color: textPrimary),
        titleMedium:    TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge:      TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary),
        bodyMedium:     TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: textSecondary),
        bodySmall:      TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: textMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accentPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgMuted,
        selectedColor: accentPrimary.withValues(alpha: 0.1),
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Dark ThemeData ────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F17),
      primaryColor: Colors.white,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        secondary: accentBlue,
        surface: Color(0xFF131B2A),
        error: accentRose,
        onPrimary: Colors.black,
        onSurface: textOnDark,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF131B2A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF1E293B), thickness: 1, space: 1),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 26, fontWeight: FontWeight.bold,   color: textOnDark),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,   color: textOnDark),
        bodyLarge:      TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textOnDark),
        bodyMedium:     TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
