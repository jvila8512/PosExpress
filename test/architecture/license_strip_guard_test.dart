import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for `adaptar-prd-hamburguezas`.
///
/// The license domain is stripped work-unit by work-unit. Each group pins
/// one work unit's end state (spec R1–R3, R6–R8) so a later refactor cannot
/// resurrect license gates in the boot, auth, login or splash paths, and so
/// the preserved scaffolding (SMS receiver, theme seeding, fail-open fence)
/// is not deleted along with the license code.
void main() {
  String source(String path) => File(path).readAsStringSync();
  int count(String haystack, String needle) =>
      haystack.split(needle).length - 1;

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

  group('T4 — splash route decision without license steps (R1)', () {
    late String splashSrc;

    setUpAll(() {
      splashSrc = source(
        'lib/features/shared/presentation/screens/splash_screen.dart',
      );
    });

    test('splash_screen.dart has no license steps in the route decision', () {
      expect(splashSrc.contains('core/security/license_service.dart'), isFalse,
          reason: 'license service import must be gone from the splash');
      expect(splashSrc.contains('initDefaultPlans'), isFalse,
          reason: 'plan seeding is license-domain and must not run at boot');
      expect(splashSrc.contains('CHECK - LICENSE FLOW'), isFalse);
      expect(splashSrc.contains('license-read'), isFalse);
      expect(splashSrc.contains('license-validate'), isFalse);
      expect(splashSrc.contains('fingerprint'), isFalse);
      expect(splashSrc.contains('license-revoke'), isFalse);
      expect(splashSrc.contains('activated_license'), isFalse);
      expect(splashSrc.contains('license_key'), isFalse);
      expect(splashSrc.contains('/license-expired'), isFalse);
      expect(splashSrc.contains('Verificando licencia'), isFalse,
          reason: 'loader copy must not mention licenses');
      expect(splashSrc.toLowerCase().contains('licen'), isFalse,
          reason: 'R7: no license residue may survive in the splash');
    });

    test('splash_screen.dart keeps the startup and fail-open scaffolding', () {
      expect(splashSrc.contains('const _startupTimeout'), isTrue);
      expect(splashSrc.contains('const _routeStepTimeout'), isTrue);
      expect(splashSrc.contains('_boundedRouteStep'), isTrue);
      expect(splashSrc.contains('_goFallback'), isTrue);
      expect(splashSrc.contains('_initApp'), isTrue);
      expect(splashSrc.contains('runStartupFlow'), isTrue);
      expect(splashSrc.contains('TIMEOUT colgado en'), isTrue);
      expect(splashSrc.contains('flutter_secure_storage'), isTrue);
      expect(splashSrc.contains('const _secureStorage'), isTrue);
      expect(splashSrc.contains('startupSteps'), isTrue);
      expect(splashSrc.contains('hasUsersOverride'), isTrue);
      expect(splashSrc.contains('usersQueryOverride'), isTrue);
      expect(splashSrc.contains("'Iniciando...'"), isTrue,
          reason: 'loader copy switches to the neutral startup text');
      expect(splashSrc.contains('createDefaultAdmin'), isTrue);
      expect(splashSrc.contains('createDefaultJefe'), isTrue);
    });
  });

  group('T5 — couplings, side menu and sections without license (R5/R7/R9)', () {
    late String menuSrc;
    late String homeSrc;
    late String settingsSrc;
    late String helpSrc;
    late String productsSrc;

    setUpAll(() {
      menuSrc = source('lib/features/shared/widgets/side_menu.dart');
      homeSrc = source('lib/features/home/presentation/screens/home_screen.dart');
      settingsSrc = source(
        'lib/features/settings/presentation/screens/settings_screen.dart',
      );
      helpSrc = source('lib/features/help/presentation/screens/help_screen.dart');
      productsSrc = source(
        'lib/features/products/presentation/providers/products_provider.dart',
      );
    });

    test('side menu lists exactly Usuarios and Configuracion for all roles', () {
      expect(count(menuSrc, 'AppMenuItem(icon:'), 2,
          reason: 'R5: one list, two navigation entries for every role');
      expect(
        menuSrc.contains(
          "AppMenuItem(icon: Icons.people_alt, label: 'Usuarios', route: '/workers')",
        ),
        isTrue,
      );
      expect(
        menuSrc.contains(
          "AppMenuItem(icon: Icons.settings_outlined, label: 'Configuración', route: '/settings')",
        ),
        isTrue,
      );
      expect(menuSrc.contains("'Inicio'"), isFalse);
      expect(menuSrc.contains('Nuevo Pedido'), isFalse,
          reason: 'R5: Nuevo Pedido lives on the dashboard, not the menu');
      expect(menuSrc.contains('Mi Licencia'), isFalse);
      expect(menuSrc.contains('Gestión de Licencias'), isFalse);
      expect(menuSrc.contains('Exportar/Importar'), isFalse);
      expect(menuSrc.toLowerCase().contains('licen'), isFalse,
          reason: 'R7: no license strings or comments in the menu');
    });

    test('side menu keeps the drawer chrome', () {
      expect(menuSrc.contains('class SideMenu'), isTrue);
      expect(menuSrc.contains('_currentMenuItems'), isTrue);
      expect(menuSrc.contains('_roleTitle'), isTrue);
      expect(menuSrc.contains('Cerrar sesión'), isTrue);
      expect(menuSrc.contains('Hamburguesa Express'), isTrue);
      expect(menuSrc.contains('_appVersion'), isTrue);
    });

    test('home dashboard keeps the Nuevo Pedido shortcut, drops the banner', () {
      expect(homeSrc.contains('license_alerts_banner'), isFalse);
      expect(homeSrc.contains('LicenseAlertsBanner'), isFalse);
      expect(homeSrc.contains('Nuevo Pedido'), isTrue,
          reason: 'R5: the dashboard action shortcut must survive');
    });

    test('settings keeps backup and drops license copy (R9)', () {
      expect(settingsSrc.toLowerCase().contains('licen'), isFalse,
          reason: 'R7: no license copy in the data-clear/backup sections');
      expect(settingsSrc.contains('DatabaseBackupService'), isTrue,
          reason: 'R9: backup/restore must stay intact');
      expect(settingsSrc.contains('clearAllDataAdmin'), isTrue);
    });

    test('help keeps export sections and drops license sections (R9)', () {
      expect(helpSrc.toLowerCase().contains('licen'), isFalse,
          reason: 'R7: license sections and tips must be gone');
      expect(helpSrc.contains('Exportaciones'), isTrue,
          reason: 'R9: export help must stay');
      expect(helpSrc.contains('📂 Exportaciones'), isTrue,
          reason: 'R9: the export section itself must survive intact');
      expect(helpSrc.contains('Contacto Soporte'), isTrue,
          reason: 'non-license sections stay in place');
    });

    test('products provider has no plan-based product limits (R7)', () {
      expect(productsSrc.contains('license_plan'), isFalse);
      expect(productsSrc.toLowerCase().contains('licen'), isFalse);
      expect(productsSrc.contains('canAddProduct'), isFalse,
          reason: 'plan-limit check removed from create');
      expect(productsSrc.contains('Future<void> addProduct('), isTrue);
      expect(productsSrc.contains('Future<void> loadProducts()'), isTrue);
    });
  });

  group('T6 — dead license and analysis files removed (R8)', () {
    const deadPaths = <String>[
      'lib/features/license',
      'lib/features/auth/presentation/screens/activation_screen.dart',
      'lib/features/auth/presentation/screens/licenses_admin_screen.dart',
      'lib/features/reports',
      'lib/features/shared/presentation/screens/exports_screen.dart',
      'lib/features/auth/presentation/screens/login_screen_etecsa.dart',
      'lib/features/auth/infrastructure/mappers/user_mapper copy.dart',
    ];

    test('every dead path listed by R8 is gone', () {
      for (final path in deadPaths) {
        expect(
          FileSystemEntity.typeSync(path, followLinks: false),
          FileSystemEntityType.notFound,
          reason: 'R8: $path must be deleted',
        );
      }
    });

    test('license service and its fingerprint test survive until T7c', () {
      expect(
        File('lib/core/security/license_service.dart').existsSync(),
        isTrue,
        reason: 'app_database.dart still imports it until T7c',
      );
      expect(
        File('test/core/security/license_service_fingerprint_test.dart')
            .existsSync(),
        isTrue,
        reason: 'deleted together with the service in T7c',
      );
    });

    test('no surviving source references a deleted path', () {
      const needles = <String>[
        'features/license/',
        'licenses_admin_screen',
        'activation_screen',
        'features/reports/',
        'exports_screen',
        'login_screen_etecsa',
        'user_mapper copy',
      ];
      final offenders = <String>[];
      for (final root in ['lib', 'test']) {
        final dartFiles = Directory(root)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        for (final file in dartFiles) {
          // This guard file names the deleted paths on purpose.
          if (file.path.endsWith('license_strip_guard_test.dart')) continue;
          final content = file.readAsStringSync();
          for (final needle in needles) {
            if (content.contains(needle)) {
              offenders.add('${file.path} → "$needle"');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'R8: surviving importers must be fixed, not left '
              'dangling: $offenders');
    });
  });
}
