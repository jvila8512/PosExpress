import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hamburguesa_theme.dart';

/// Provider for the current theme mode.
///
/// Defaults to dark mode (most screens are Cocina or show orders).
/// The user can toggle this in Settings.
/// After login, call [setDefaultThemeForRole] to apply the role-based default.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

/// Singleton provider for the Hamburguesa theme data (light + dark).
final hamburguesaThemeProvider = Provider<HamburguesaThemeData>((_) {
  return HamburguesaThemeData.instance;
});

/// Resolved [ThemeData] based on the current [themeModeProvider].
///
/// This is the provider to pass as `theme` / `darkTheme` / `themeMode`
/// in MaterialApp when using ConsumerWidget/Consumer.
final currentThemeProvider = Provider<ThemeData>((ref) {
  final mode = ref.watch(themeModeProvider);
  final theme = ref.watch(hamburguesaThemeProvider);

  switch (mode) {
    case ThemeMode.dark:
      return theme.dark;
    case ThemeMode.light:
      return theme.light;
    case ThemeMode.system:
      // Fallback: the orchestrator can override this via platform brightness
      return theme.dark;
  }
});

/// Provider that exposes the complete [HamburguesaThemeData] (both modes)
/// so that widgets or screens that need to react to brightness changes
/// can access either mode directly.
final fullThemeProvider = Provider<HamburguesaThemeData>((ref) {
  return HamburguesaThemeData.instance;
});

/// Returns the recommended [ThemeMode] for a given user [role].
///
/// From PRD §15:
/// - Cocina → dark mode (default for kitchen screens)
/// - Redes, Domicilio, Admin, Mesero → light mode
ThemeMode defaultThemeForRole(String role) {
  switch (role.toLowerCase()) {
    case 'cocina':
      return ThemeMode.dark;
    case 'redes':
    case 'domicilio':
    case 'admin':
    case 'super_admin':
    case 'mesero':
    default:
      return ThemeMode.light;
  }
}

/// Updates [themeModeProvider] based on the user's role.
///
/// Call this after login/auth state resolves to apply the role-based default.
void setDefaultThemeForRole(WidgetRef ref, String role) {
  ref.read(themeModeProvider.notifier).state = defaultThemeForRole(role);
}
