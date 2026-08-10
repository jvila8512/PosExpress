import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'hamburguesa_theme.dart';
import 'theme_preferences.dart';

/// Provider for the current theme mode.
///
/// Defaults to light mode. A persisted user choice (see [ThemePreferenceStore])
/// is seeded into [ThemePrefs.initialMode] in `main()` before `runApp()`.
/// After login, call [setDefaultThemeForRole] to apply the role-based default.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemePrefs.initialMode ?? ThemeMode.light);

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
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark ? theme.dark : theme.light;
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

/// Returns the effective mode for a role, honoring a persisted explicit
/// choice first (the user's choice overrides the role default, per spec).
ThemeMode themeModeForRole(String role) =>
    ThemePrefs.initialMode ?? defaultThemeForRole(role);

/// Updates [themeModeProvider] based on the user's role.
///
/// Call this after login/auth state resolves to apply the role-based default.
void setDefaultThemeForRole(WidgetRef ref, String role) {
  ref.read(themeModeProvider.notifier).state = themeModeForRole(role);
}
