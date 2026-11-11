import 'package:flutter/material.dart';

/// NARA design language: dark navy foundation, purple/blue accents, subtle
/// glow. Accessible contrast on every pairing used by text.
class NaraTheme {
  const NaraTheme._();

  static const Color _navy = Color(0xFF0A0E1A);
  static const Color _navySurface = Color(0xFF111827);
  static const Color _navyCard = Color(0xFF161F33);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _textPrimary = Color(0xFFF1F5F9);
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _success = Color(0xFF34D399);
  static const Color _danger = Color(0xFFF87171);
  static const Color _warning = Color(0xFFFBBF24);

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: _purple,
      secondary: _blue,
      surface: _navySurface,
      error: _danger,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _navy,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: _navy,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _navyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _navySurface,
        indicatorColor: _purple.withValues(alpha: 0.25),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: _textSecondary, fontSize: 12),
        ),
        iconTheme: const WidgetStatePropertyAll(IconThemeData(color: _textPrimary)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: const BorderSide(color: _textSecondary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _navyCard,
        hintStyle: const TextStyle(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _textPrimary,
        textColor: _textPrimary,
      ),
      dividerColor: _textSecondary.withValues(alpha: 0.15),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _navyCard,
        contentTextStyle: const TextStyle(color: _textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Exposed for custom widgets.
  static const Color accentPurple = _purple;
  static const Color accentBlue = _blue;
  static const Color success = _success;
  static const Color danger = _danger;
  static const Color warning = _warning;
  static const Color textSecondary = _textSecondary;
  static const Color card = _navyCard;
}
