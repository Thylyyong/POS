import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'OmniPOS Dual-Screen';
  static const String appVersion = '1.0.0';
  static const String defaultCurrency = '\$';
  static const double defaultTaxRate = 10.0;

  // ── Light Theme Palette ───────────────────────────────────────────────────
  // Backgrounds
  static const Color bgBase      = Color(0xFFF8FAFC); // slate-50
  static const Color bgSurface   = Color(0xFFFFFFFF); // white cards
  static const Color bgMuted     = Color(0xFFF1F5F9); // slate-100 subtle rows

  // Borders
  static const Color border      = Color(0xFFE2E8F0); // slate-200
  static const Color borderStrong= Color(0xFFCBD5E1); // slate-300

  // Sidebar / Nav (keep dark for contrast)
  static const Color sidebarBg   = Color(0xFF0F172A); // slate-900
  static const Color sidebarCard = Color(0xFF1E293B); // slate-800

  // Accents
  static const Color accentGreen      = Color(0xFF10B981); // emerald-500
  static const Color accentGreenDark  = Color(0xFF059669); // emerald-600
  static const Color accentCyan       = Color(0xFF06B6D4); // cyan-500
  static const Color accentAmber      = Color(0xFFF59E0B); // amber-500
  static const Color accentRose       = Color(0xFFF43F5E); // rose-500
  static const Color accentPurple     = Color(0xFF8B5CF6); // purple-500
  static const Color accentBlue       = Color(0xFF3B82F6); // blue-500
  static const Color accentOrange     = Color(0xFFF97316); // orange-500

  // Text
  static const Color textPrimary   = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textMuted     = Color(0xFF94A3B8); // slate-400
  static const Color textOnDark    = Color(0xFFF8FAFC); // for dark surfaces

  // Legacy aliases kept for backward compat (map to light equivalents)
  static const Color primaryDark    = sidebarBg;
  static const Color primarySurface = sidebarCard;
  static const Color primaryCard    = Color(0xFF334155);
  static const Color surfaceBorder  = Color(0xFF475569);

  // Category color palette
  static const List<Color> categoryColors = [
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
  ];

  // Table status colors
  static const Color tableAvailable    = Color(0xFF10B981);
  static const Color tableOccupied     = Color(0xFFF59E0B);
  static const Color tableBillRequest  = Color(0xFF6366F1);

  // ── Light ThemeData ───────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgBase,
      primaryColor: accentGreen,
      colorScheme: const ColorScheme.light(
        primary: accentGreen,
        secondary: accentCyan,
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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
        shadowColor: Colors.black12,
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
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: textPrimary),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,   color: textPrimary),
        headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w700,   color: textPrimary),
        titleLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w600,   color: textPrimary),
        titleMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w600,   color: textPrimary),
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
          borderSide: const BorderSide(color: accentGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
        selectedColor: accentGreen.withAlpha(30),
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Dark ThemeData (for toggle) ───────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: sidebarBg,
      primaryColor: accentGreen,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentCyan,
        surface: sidebarCard,
        error: accentRose,
        onPrimary: Colors.white,
        onSurface: textOnDark,
      ),
      cardTheme: CardThemeData(
        color: sidebarCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2E3A4E), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2E3A4E), thickness: 1, space: 1),
      textTheme: const TextTheme(
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: textOnDark),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,   color: textOnDark),
        bodyLarge:      TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textOnDark),
        bodyMedium:     TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Color(0xFF94A3B8)),
      ),
    );
  }
}
