import 'package:flutter/material.dart';

/// Hamburguesa Express — Design System Colors.
///
/// All color tokens for both dark and light modes.
/// Shared accent stays the same across themes.
///
/// Naming follows the PRD §15: every color has a Spanish cocina name
/// (Carbón, Plancha, Achiote, Mostaza, Mojo, Guayaba).
abstract final class AppColors {
  // ═══════════════════════════════════════════════════════
  // DARK MODE
  // ═══════════════════════════════════════════════════════

  /// Carbón — Dark background
  static const Color darkBg = Color(0xFF241A14);

  /// Plancha — Dark cards, panels, surfaces
  static const Color darkSurface = Color(0xFF382A21);

  /// Main text on dark backgrounds
  static const Color darkTextPrimary = Color(0xFFF6ECDF);

  /// Secondary / muted text on dark backgrounds
  static const Color darkTextSecondary = Color(0xFFB0A196);

  // ═══════════════════════════════════════════════════════
  // LIGHT MODE
  // ═══════════════════════════════════════════════════════

  /// Papel — Light background
  static const Color lightBg = Color(0xFFF6ECDF);

  /// White — Light cards, panels, surfaces
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Main text on light backgrounds
  static const Color lightTextPrimary = Color(0xFF241A14);

  /// Secondary / muted text on light backgrounds
  static const Color lightTextSecondary = Color(0xFF8A7A6C);

  // ═══════════════════════════════════════════════════════
  // SEMANTIC COLORS (shared base)
  // ═══════════════════════════════════════════════════════

  /// Achiote — Brand color, primary buttons, "en cocina" state.
  /// Stays the same in both themes for brand recognition.
  static const Color accent = Color(0xFFD9531E);

  /// Mostaza — Dark mode warning.
  static const Color warningDark = Color(0xFFE4A22E);

  /// Mostaza — Light mode warning (darkened for contrast).
  static const Color warningLight = Color(0xFFB97A1E);

  /// Mojo — Dark mode success.
  static const Color successDark = Color(0xFF7C9A3B);

  /// Mojo — Light mode success (darkened for contrast).
  static const Color successLight = Color(0xFF5E7A2A);

  /// Guayaba — Dark mode danger / error / cancelled.
  static const Color dangerDark = Color(0xFFC2495B);

  /// Guayaba — Light mode danger / error / cancelled (darkened).
  static const Color dangerLight = Color(0xFFA03347);

  // ═══════════════════════════════════════════════════════
  // MODE-AWARE HELPERS
  // ═══════════════════════════════════════════════════════

  /// Resolves semantic color set for the given [brightness].
  static AppColorsTheme forBrightness(Brightness brightness) =>
      brightness == Brightness.dark
          ? AppColorsTheme(
              bg: darkBg,
              surface: darkSurface,
              textPrimary: darkTextPrimary,
              textSecondary: darkTextSecondary,
              warning: warningDark,
              success: successDark,
              danger: dangerDark,
            )
          : AppColorsTheme(
              bg: lightBg,
              surface: lightSurface,
              textPrimary: lightTextPrimary,
              textSecondary: lightTextSecondary,
              warning: warningLight,
              success: successLight,
              danger: dangerLight,
            );
}

/// A resolved set of mode-dependent colors.
///
/// Use [AppColors.forBrightness] to get an instance for the current theme.
class AppColorsTheme {
  final Color bg;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color warning;
  final Color success;
  final Color danger;

  /// Accent is mode-independent — always [AppColors.accent].
  Color get accent => AppColors.accent;

  const AppColorsTheme({
    required this.bg,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.warning,
    required this.success,
    required this.danger,
  });
}
