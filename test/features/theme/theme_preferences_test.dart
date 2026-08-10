import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/theme/theme_preferences.dart';
import 'package:etecsa/config/theme/theme_provider.dart';

void main() {
  group('defaultThemeForRole', () {
    test('cocina maps to dark mode', () {
      expect(defaultThemeForRole('cocina'), ThemeMode.dark);
    });

    test('cocina match is case-insensitive', () {
      expect(defaultThemeForRole('COCINA'), ThemeMode.dark);
    });

    test('redes maps to light mode', () {
      expect(defaultThemeForRole('redes'), ThemeMode.light);
    });

    test('domicilio maps to light mode', () {
      expect(defaultThemeForRole('domicilio'), ThemeMode.light);
    });

    test('admin maps to light mode', () {
      expect(defaultThemeForRole('admin'), ThemeMode.light);
    });

    test('super_admin maps to light mode', () {
      expect(defaultThemeForRole('super_admin'), ThemeMode.light);
    });

    test('mesero maps to light mode', () {
      expect(defaultThemeForRole('mesero'), ThemeMode.light);
    });

    test('unknown role falls back to light mode', () {
      expect(defaultThemeForRole('nobody'), ThemeMode.light);
    });
  });

  group('ThemePreferenceStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      ThemePrefs.initialMode = null;
    });

    test('read returns null when nothing was persisted', () async {
      expect(await ThemePreferenceStore.read(), isNull);
    });

    test('write then read round-trips light mode', () async {
      await ThemePreferenceStore.write(ThemeMode.light);
      expect(await ThemePreferenceStore.read(), ThemeMode.light);
    });

    test('write then read round-trips dark mode', () async {
      await ThemePreferenceStore.write(ThemeMode.dark);
      expect(await ThemePreferenceStore.read(), ThemeMode.dark);
    });

    test('write then read round-trips system mode', () async {
      await ThemePreferenceStore.write(ThemeMode.system);
      expect(await ThemePreferenceStore.read(), ThemeMode.system);
    });

    test('last write wins', () async {
      await ThemePreferenceStore.write(ThemeMode.dark);
      await ThemePreferenceStore.write(ThemeMode.light);
      expect(await ThemePreferenceStore.read(), ThemeMode.light);
    });
  });
}