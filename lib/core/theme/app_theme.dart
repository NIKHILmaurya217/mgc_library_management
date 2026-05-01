import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  // The Soft Light Theme Palette
  static const Color _lightBackground = Color(0xFFF8FAFC); // Soft Slate/Gray
  static const Color _lightSurface = Color(0xFFFFFFFF);    // Pure White
  static const Color _lightAccent = Color(0xFF3B82F6);     // Soft Ocean Blue
  static const Color _lightBorder = Color(0xFFE2E8F0);     // Very Soft Blue-Gray
  static const Color _lightTextPrimary = Color(0xFF0F172A); // Slate 900 (Not pure black)
  static const Color _lightTextSecondary = Color(0xFF64748B); // Slate 500

  // The Dark Theme Palette (Existing)
  static const Color _darkBackground = Color(0xFF07090F);
  static const Color _darkSurface = Color(0xFF0D1117);
  static const Color _darkAccent = Color(0xFF00D4FF);
  static const Color _darkBorder = Color(0xFF1E2D45);
  static const Color _darkTextPrimary = Colors.white;
  static const Color _darkTextSecondary = Color(0xFF9E9E9E);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      primaryColor: _lightAccent,
      colorScheme: const ColorScheme.light(
        primary: _lightAccent,
        surface: _lightSurface,
        error: AppColors.error,
        onPrimary: _lightSurface,
        onSurface: _lightTextPrimary,
        outline: _lightBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: _lightAccent),
        titleTextStyle: TextStyle(
          color: _lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
        bodyLarge: const TextStyle(color: _lightTextPrimary),
        bodyMedium: const TextStyle(color: _lightTextPrimary),
        labelLarge: const TextStyle(color: _lightAccent, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBackground,
        hintStyle: const TextStyle(color: _lightTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lightAccent),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lightBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _lightAccent,
        unselectedItemColor: _lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
      ),
      extensions: const [
        AppColorsExtension(
          background: _lightBackground,
          surface: _lightSurface,
          accent: _lightAccent,
          border: _lightBorder,
          textPrimary: _lightTextPrimary,
          textSecondary: _lightTextSecondary,
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      primaryColor: _darkAccent,
      colorScheme: const ColorScheme.dark(
        primary: _darkAccent,
        surface: _darkSurface,
        error: AppColors.error,
        onPrimary: _darkBackground,
        onSurface: _darkTextPrimary,
        outline: _darkBorder,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: _darkAccent),
        titleTextStyle: TextStyle(
          color: _darkAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: const TextStyle(color: _darkTextPrimary),
        bodyMedium: const TextStyle(color: _darkTextPrimary),
        labelLarge: const TextStyle(color: _darkAccent, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurface,
        hintStyle: const TextStyle(color: _darkTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkAccent),
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _darkAccent,
        unselectedItemColor: _darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
      ),
      extensions: const [
        AppColorsExtension(
          background: _darkBackground,
          surface: _darkSurface,
          accent: _darkAccent,
          border: _darkBorder,
          textPrimary: _darkTextPrimary,
          textSecondary: _darkTextSecondary,
        ),
      ],
    );
  }
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color background;
  final Color surface;
  final Color accent;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppColorsExtension({
    required this.background,
    required this.surface,
    required this.accent,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? background,
    Color? surface,
    Color? accent,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension ThemeColorsExt on BuildContext {
  AppColorsExtension get color => Theme.of(this).extension<AppColorsExtension>()!;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
