import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/auth/presentation/screens/login_screen.dart';

/// WCAG contrast ratio between two colors (≥3:1 is required for large text /
/// UI components; we enforce a minimum of 3:1 for login field labels).
double _contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    final channels = [c.r, c.g, c.b].map((v) {
      // Normaliza ambos rangos de la API de Color (0-255 legacy / 0.0-1.0).
      final s = v > 1.0 ? v / 255.0 : v;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4);
    }).toList();
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
  }

  final lighter = math.max(luminance(a), luminance(b));
  final darker = math.min(luminance(a), luminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

/// Compone un color translúcido sobre su fondo.
Color _over(Color fg, Color bg, double alpha) => Color.lerp(bg, fg, alpha)!;

/// Réplica de las reglas de relleno del `InputDecorationTheme` de
/// hamburguesa_theme.dart usando los tokens puros (sin google_fonts).
Color _fillFor(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return AppColors.darkSurface.withValues(alpha: 0.5);
  }
  return Colors.white;
}

Color _labelFor(Brightness brightness) =>
    AppColors.forBrightness(brightness).textSecondary;

Color _scaffoldBgFor(Brightness brightness) =>
    AppColors.forBrightness(brightness).bg;

/// Tema mínimo y fiel al diseño para los widget tests (sin google_fonts).
ThemeData _testTheme(Brightness brightness) {
  final colors = AppColors.forBrightness(brightness);
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _fillFor(brightness),
      labelStyle: TextStyle(color: colors.textSecondary),
    ),
  );
}

void main() {
  group('Login field legibility', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      test('label vs fill contrast >= 3:1 in ${brightness.name} mode', () {
        final fill = _fillFor(brightness);
        // El fill translúcido del dark mode se compone sobre el fondo real.
        final effectiveFill = fill.a < 1.0
            ? _over(fill, _scaffoldBgFor(brightness), fill.a)
            : fill;

        expect(
          _contrastRatio(_labelFor(brightness), effectiveFill),
          greaterThanOrEqualTo(3.0),
          reason: 'Label de campo debe ser legible en ${brightness.name} mode',
        );
      });
    }
  });

  group('LoginScreen theme regression', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
          '${brightness.name} mode: scaffold uses brand bg (not white)'
          ' and fields do not force legacy fills', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: LoginScreen(),
              theme: _testTheme(Brightness.light),
              darkTheme: _testTheme(Brightness.dark),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
            ),
          ),
        );
        await tester.pump();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        // El Scaffold ya NO fuerza Colors.white: o está sin color (hereda del
        // tema, null) o usa el fondo de marca. En ningún caso blanco.
        expect(scaffold.backgroundColor, isNot(Colors.white));
        if (scaffold.backgroundColor != null) {
          expect(scaffold.backgroundColor, _scaffoldBgFor(brightness));
        }

        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields, isNotEmpty);
        for (final field in fields) {
          expect(field.decoration?.fillColor, isNot(Colors.grey.shade50));
          expect(field.decoration?.fillColor, isNot(Colors.white));
        }
      });
    }
  });
}