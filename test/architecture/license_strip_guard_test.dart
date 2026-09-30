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

  group('T3a — login screen without license lookup logic (R2)', () {
    late String loginSrc;

    setUpAll(() {
      loginSrc = source('lib/features/auth/presentation/screens/login_screen.dart');
    });

    test('login_screen.dart has no license lookup logic', () {
      expect(loginSrc.contains('core/security/license_service.dart'), isFalse,
          reason: 'license service import must be gone from the login screen');
      expect(loginSrc.contains('_loadLicenseInfo'), isFalse);
      expect(loginSrc.contains('_loadAndroidId'), isFalse);
      expect(loginSrc.contains('LicenseService.'), isFalse);
      expect(loginSrc.contains('getDeviceFingerprint'), isFalse);
      expect(loginSrc.contains('getActivatedLicenseCode'), isFalse);
      expect(loginSrc.contains('validateLicenseWithTamperProtection'), isFalse);
    });

    test('login_screen.dart keeps the login form wiring', () {
      expect(loginSrc.contains('Widget _buildLoginForm'), isTrue);
      expect(loginSrc.contains('loginFormProvider'), isTrue);
      expect(loginSrc.contains('authProvider.notifier'), isTrue);
      expect(loginSrc.contains("'INICIAR SESIÓN'"), isTrue);
    });
  });

  group('T3b — login screen without license widgets (R2/R7)', () {
    late String loginSrc;

    setUpAll(() {
      loginSrc = source('lib/features/auth/presentation/screens/login_screen.dart');
    });

    test('login_screen.dart has zero license-domain residue', () {
      expect(loginSrc.toLowerCase().contains('licen'), isFalse,
          reason: 'R7: no license strings, fields or builders may survive');
      expect(loginSrc.contains('_licenseInfo'), isFalse);
      expect(loginSrc.contains('_checkingLicense'), isFalse);
      expect(loginSrc.contains('_androidId'), isFalse);
      expect(loginSrc.contains('_buildLicenseStatusCard'), isFalse);
      expect(loginSrc.contains('_buildNoLicenseCard'), isFalse);
      expect(loginSrc.contains('_buildActiveLicenseCard'), isFalse);
      expect(loginSrc.contains('_buildExpiredLicenseCard'), isFalse);
      expect(loginSrc.contains('_buildInvalidLicenseCard'), isFalse);
      expect(loginSrc.contains('_buildAndroidIdChip'), isFalse);
      expect(loginSrc.contains('AppDatabase'), isFalse);
      expect(loginSrc.contains('Clipboard'), isFalse);
    });

    test('login_screen.dart keeps the form and its scaffolding', () {
      expect(loginSrc.contains('Widget _buildLoginForm'), isTrue);
      expect(loginSrc.contains('initState'), isTrue);
      expect(loginSrc.contains('_obscurePassword'), isTrue);
      expect(loginSrc.contains('class _LoginScreenState'), isTrue);
    });
  });
}
