import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for `adaptar-prd-hamburguezas`.
///
/// The license domain is stripped work-unit by work-unit. Each group pins
/// one work unit's end state (spec R1–R3, R7) so a later refactor cannot
/// resurrect license gates in the boot, auth, login or splash paths, and so
/// the preserved scaffolding (SMS receiver, theme seeding, fail-open fence)
/// is not deleted along with the license code.
void main() {
  String source(String path) => File(path).readAsStringSync();

  group('T2 — boot and auth without license gates (R2)', () {
    late String mainSrc;
    late String authSrc;

    setUpAll(() {
      mainSrc = source('lib/main.dart');
      authSrc = source('lib/features/auth/presentation/providers/auth_provider.dart');
    });

    test('main.dart has no license bootstrap code', () {
      expect(mainSrc.contains('_crearLicenciaPrueba'), isFalse,
          reason: '_crearLicenciaPrueba must be removed from boot');
      expect(mainSrc.contains('_CREAR_LICENCIA_PRUEBA'), isFalse);
      expect(mainSrc.contains('_LICENSE_KEY_PRUEBA'), isFalse);
      expect(mainSrc.contains('flutter_secure_storage'), isFalse,
          reason: 'only the license _storage used secure storage in main');
      expect(mainSrc.contains('package:uuid/uuid.dart'), isFalse,
          reason: 'only _crearLicenciaPrueba used uuid');
      expect(mainSrc.contains("license_key"), isFalse);
    });

    test('main.dart keeps SMS receiver and orientation setup', () {
      expect(mainSrc.contains('_initSmsReceiver'), isTrue,
          reason: 'SMS receiver init must survive the license strip');
      expect(mainSrc.contains('SystemChrome.setPreferredOrientations'), isTrue);
      expect(mainSrc.contains('ThemePreferenceStore.read'), isTrue,
          reason: 'theme seed must survive the license strip');
    });

    test('auth_provider.dart has no license gate', () {
      expect(authSrc.contains('validateLicenseWithTamperProtection'), isFalse);
      expect(authSrc.contains('getActivatedLicenseCode'), isFalse);
      expect(authSrc.contains('core/security/license_service.dart'), isFalse);
      expect(authSrc.contains('Activa tu licencia'), isFalse);
    });

    test('auth_provider.dart keeps credential error semantics', () {
      expect(authSrc.contains('on WrongCredentials'), isTrue);
      expect(authSrc.contains('Usuario o contraseña incorrectos'), isTrue);
      expect(authSrc.contains('_isFirstTimeLogin'), isTrue);
      expect(authSrc.contains('_createDefaultAdmin'), isTrue);
      expect(authSrc.contains('_applyThemeForUser'), isTrue);
      expect(authSrc.contains('class AuthState'), isTrue);
    });
  });
}
