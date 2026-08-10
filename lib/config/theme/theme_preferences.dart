import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's explicit theme-mode choice.
///
/// Single key (`theme_mode`) shared across roles: an explicit user choice
/// overrides the role-based default, matching the product spec. Absence of a
/// saved value means "no explicit choice" and the role default applies.
abstract final class ThemePreferenceStore {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  /// Reads the persisted choice. Returns null when the user never chose one.
  static Future<ThemeMode?> read() async {
    final value = await _storage.read(key: _key);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static Future<void> write(ThemeMode mode) async {
    await _storage.write(key: _key, value: mode.name);
  }
}

/// Holds the theme mode resolved in `main()` before `runApp()`.
///
/// Seeded from [ThemePreferenceStore.read] so the very first frame already uses
/// the persisted choice (no flash of the wrong theme) without provider churn.
abstract final class ThemePrefs {
  static ThemeMode? initialMode;
}