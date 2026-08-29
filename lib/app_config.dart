import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'OmniPOS Dual-Screen';
  static const String appVersion = '1.0.0';
  static const String defaultCurrency = '\$';
  static const double defaultTaxRate = 10.0;

  // ── Light Theme Palette (Modern Premium Minimalist Slate) ──────────────────
  // Backgrounds
  static const Color bgBase        = Color(0xFFF8FAFC); // slate-50
  static const Color bgSurface     = Color(0xFFFFFFFF); // pure white cards
  static const Color bgMuted       = Color(0xFFF1F5F9); // slate-100
  static const Color bgDark        = Color(0xFF0F172A); // slate-900

  // Borders
  static const Color border        = Color(0xFFE2E8F0); // slate-200
  static const Color borderStrong  = Color(0xFFCBD5E1); // slate-300

  // Sidebar / Nav
  static const Color sidebarBg     = Color(0xFFFFFFFF); // pure white light sidebar
  static const Color sidebarBorder = Color(0xFFE2E8F0); // slate-200

  // Brand / Accents (Sleek Slate & Indigo/Teal)
  static const Color accentPrimary    = Color(0xFF0F172A); // slate-900 primary
  static const Color accentBlue       = Color(0xFF2563EB); // royal blue-600
  static const Color accentTeal       = Color(0xFF0D9488); // teal-600
  static const Color accentCyan       = Color(0xFF0284C7); // sky-600
  static const Color accentAmber      = Color(0xFFD97706); // amber-600
  static const Color accentRose       = Color(0xFFE11D48); // rose-600
  static const Color accentPurple     = Color(0xFF7C3AED); // violet-600
  static const Color accentOrange     = Color(0xFFEA580C); // orange-600

  // Emerald/Green (Subtle, strictly for positive finance & metrics)
  static const Color accentGreen      = Color(0xFF10B981); // emerald-500
  static const Color accentGreenDark  = Color(0xFF059669); // emerald-600

  // Text
  static const Color textPrimary   = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textMuted     = Color(0xFF94A3B8); // slate-400
  static const Color textOnDark    = Color(0xFFF8FAFC); // for dark surfaces

  // Legacy aliases
  static const Color primaryDark    = Color(0xFF0F172A);
  static const Color primarySurface = Color(0xFF1E293B);
  static const Color primaryCard    = Color(0xFF334155);
  static const Color surfaceBorder  = Color(0xFFCBD5E1);

  // Category color palette
  static const List<Color> categoryColors = [
    Color(0xFF0F172A),
    Color(0xFF2563EB),
    Color(0xFF0D9488),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF0284C7),
    Color(0xFFE11D48),
    Color(0xFF475569),
  ];

  // Table status colors
  static const Color tableAvailable    = Color(0xFF059669);
  static const Color tableOccupied     = Color(0xFFD97706);
  static const Color tableBillRequest  = Color(0xFF2563EB);

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
