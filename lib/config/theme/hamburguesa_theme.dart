import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Hamburguesa Express — full design system theme.
///
/// Provides both [light] and [dark] [ThemeData] instances built with
/// the brand typography (Bungee, DM Sans, JetBrains Mono) and the
/// color tokens from [AppColors].
class HamburguesaThemeData {
  final ThemeData light;
  final ThemeData dark;

  const HamburguesaThemeData({
    required this.light,
    required this.dark,
  });

  /// Returns the theme for the given [brightness].
  ThemeData forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Builds and caches the two themes once.
  static HamburguesaThemeData _instance;
  static HamburguesaThemeData get instance {
    _instance ??= HamburguesaThemeData._build();
    return _instance;
  }

  HamburguesaThemeData._build()
      : light = _buildTheme(Brightness.light),
        dark = _buildTheme(Brightness.dark);

  /// Builds a complete [ThemeData] for the given [brightness].
  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = AppColors.forBrightness(brightness);

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: AppColors.accent,
            secondary: colors.warning,
            surface: colors.surface,
            error: colors.danger,
            onPrimary: colors.textPrimary,
            onSecondary: colors.textPrimary,
            onSurface: colors.textPrimary,
            onError: Colors.white,
            brightness: Brightness.dark,
          )
        : ColorScheme.light(
            primary: AppColors.accent,
            secondary: colors.warning,
            surface: colors.surface,
            error: colors.danger,
            onPrimary: colors.textPrimary,
            onSecondary: colors.textPrimary,
            onSurface: colors.textPrimary,
            onError: Colors.white,
            brightness: Brightness.light,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.bg,
      brightness: brightness,

      // ── Typography ──────────────────────────────────
      textTheme: _buildTextTheme(colors),
      primaryTextTheme: _buildTextTheme(colors),

      // ── AppBar ──────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),

      // ── Buttons ─────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.accent),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.accent),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.accent),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.accent),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      // ── Inputs ──────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.textSecondary.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.textSecondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: GoogleFonts.dmSans(color: colors.textSecondary),
        hintStyle: GoogleFonts.dmSans(color: colors.textSecondary.withValues(alpha: 0.6)),
      ),

      // ── Cards ───────────────────────────────────────
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: isDark ? 4 : 2,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── FAB ─────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Navigation ──────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: AppColors.accent,
        unselectedItemColor: colors.textSecondary,
        backgroundColor: colors.surface,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
      ),

      // ── Dividers ────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: colors.textSecondary.withValues(alpha: 0.2),
        thickness: 1,
        space: 1,
      ),

      // ── List tiles ──────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        subtitleTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: colors.textSecondary,
        ),
        leadingAndTrailingTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: colors.textSecondary,
        ),
      ),

      // ── SnackBar ────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: GoogleFonts.dmSans(fontSize: 14),
      ),

      // ── Dialogs ─────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.bungee(
          fontSize: 20,
          color: colors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: colors.textPrimary,
        ),
      ),

      // ── Progress ────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: colors.textSecondary.withValues(alpha: 0.2),
      ),

      // ─── Chip ───────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        labelStyle: GoogleFonts.dmSans(color: colors.textPrimary, fontSize: 12),
        side: BorderSide(color: colors.textSecondary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // ── Switch ───────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return colors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent.withValues(alpha: 0.5);
          }
          return colors.textSecondary.withValues(alpha: 0.3);
        }),
      ),

      // ── Drawer ──────────────────────────────────────
      drawerTheme: DrawerThemeData(
        backgroundColor: colors.surface,
      ),

      // ── PopupMenu ───────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.dmSans(color: colors.textPrimary, fontSize: 14),
      ),
    );
  }

  /// Builds the typography system using the three brand fonts.
  static TextTheme _buildTextTheme(AppColorsTheme colors) {
    final bungee = GoogleFonts.bungee;
    final dmSans = GoogleFonts.dmSans;
    final jetBrainsMono = GoogleFonts.jetBrainsMono;

    return TextTheme(
      // Bungee — titles, product names
      displayLarge: bungee(fontSize: 32, fontWeight: FontWeight.bold, color: colors.textPrimary),
      displayMedium: bungee(fontSize: 28, fontWeight: FontWeight.bold, color: colors.textPrimary),
      displaySmall: bungee(fontSize: 24, fontWeight: FontWeight.bold, color: colors.textPrimary),
      headlineLarge: bungee(fontSize: 22, fontWeight: FontWeight.bold, color: colors.textPrimary),
      headlineMedium: bungee(fontSize: 20, fontWeight: FontWeight.bold, color: colors.textPrimary),
      headlineSmall: bungee(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
      titleLarge: bungee(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),

      // DM Sans — body text, forms, lists
      titleMedium: dmSans(fontSize: 16, fontWeight: FontWeight.w500, color: colors.textPrimary),
      titleSmall: dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
      bodyLarge: dmSans(fontSize: 16, color: colors.textPrimary),
      bodyMedium: dmSans(fontSize: 14, color: colors.textPrimary),
      bodySmall: dmSans(fontSize: 12, color: colors.textSecondary),

      // JetBrains Mono — order numbers, amounts, timers
      labelLarge: jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w500, color: colors.textPrimary),
      labelMedium: jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w500, color: colors.textPrimary),
      labelSmall: jetBrainsMono(fontSize: 10, color: colors.textSecondary),
    );
  }
}
