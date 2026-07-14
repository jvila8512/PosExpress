import 'package:flutter/material.dart';

class AppTheme {
  // Colores de la app
  static const Color colorCeleste = Color(0xFF00BCD4);
  static const Color colorMorado = Color(0xFF9C27B0);
  static const Color scaffoldBackgroundColor = Color(0xFFF0F8FF);

  static ThemeData getTheme() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colorCeleste,
      primary: colorCeleste,
      secondary: colorMorado,
      brightness: Brightness.light,
      surface: Colors.white,
    ),

    scaffoldBackgroundColor: scaffoldBackgroundColor,

    // Títulos con fuente del sistema (Roboto - viene con Android)
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Roboto', fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontFamily: 'Roboto', fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontFamily: 'Roboto', fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontFamily: 'Roboto', fontSize: 20, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontFamily: 'Roboto', fontSize: 16),
      bodyMedium: TextStyle(fontFamily: 'Roboto', fontSize: 14),
      bodySmall: TextStyle(fontFamily: 'Roboto', fontSize: 12),
      labelLarge: TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(fontFamily: 'Roboto', fontSize: 10),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: colorCeleste,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(colorMorado),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(colorCeleste),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(colorCeleste),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: colorCeleste)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: colorCeleste, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: colorMorado, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: colorMorado,
      foregroundColor: Colors.white,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: colorMorado,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
    ),

    dividerTheme: const DividerThemeData(
      color: Colors.grey,
      thickness: 0.5,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}