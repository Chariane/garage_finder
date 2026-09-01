import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF155EEF);
  static const Color secondary = Color(0xFF0F766E);
  static const Color accent = Color(0xFFFFB000);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color success = Color(0xFF12B76A);
  static const Color darkSurface = Color(0xFF121826);
  static const double radius = 8;

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: const Color(0xFFF6F8FC),
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      tertiary: accent,
      surface: Color(0xFFFFFFFF),
      onSurface: ink,
      primaryContainer: Color(0xFFEAF1FF),
      secondaryContainer: Color(0xFFE7F8F6),
      tertiaryContainer: Color(0xFFFFF3D8),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(color: muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF6F8FC),
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEAF1FF),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE4E7EC),
      thickness: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF84ADFF),
    scaffoldBackgroundColor: const Color(0xFF0B1020),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF84ADFF),
      secondary: Color(0xFF5EEAD4),
      tertiary: Color(0xFFFFC95C),
      surface: darkSurface,
      onSurface: Color(0xFFEFF4FF),
      primaryContainer: Color(0xFF172554),
      secondaryContainer: Color(0xFF134E4A),
      tertiaryContainer: Color(0xFF713F12),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEFF4FF),
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEFF4FF),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFFEFF4FF),
      ),
      bodyMedium: TextStyle(color: Color(0xFFB7C0D5)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B1020),
      foregroundColor: Color(0xFFEFF4FF),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFFEFF4FF),
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: darkSurface,
      surfaceTintColor: darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF182033),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Color(0xFF84ADFF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF84ADFF),
        foregroundColor: const Color(0xFF0B1020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF182033),
      selectedColor: const Color(0xFF172554),
      side: const BorderSide(color: Color(0xFF273248)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF273248),
      thickness: 1,
    ),
  );
}
