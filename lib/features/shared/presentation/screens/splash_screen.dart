import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/theme_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/core/security/license_service.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/database_backup_service.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/core/services/startup_flow.dart';

const _secureStorage = FlutterSecureStorage();

/// Timeout global del arranque: si pasa sin completar el flujo, fail-open
/// a login/register en lugar de quedar colgado en el loader.
const _startupTimeout = Duration(seconds: 10);

/// Tiempo máximo que esperamos por la consulta de usuarios en el fallback
/// cuando el arranque hizo timeout (para saber si vamos a register o login).
const _fallbackUsersTimeout = Duration(seconds: 2);

/// Timeout por paso de la decisión de ruta: si un await de la secuencia
/// (users-query / license-read / license-validate / fingerprint /
/// session-read) se cuelga, este fence lo corta y hace fail-open a
/// login/register en vez de dejar el splash colgado para siempre.
/// Constante nombrada (rollback flag), igual que el fence de arranque.
const _routeStepTimeout = Duration(seconds: 10);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.startupSteps,
    this.hasUsersOverride,
    this.usersQueryOverride,
  });

  /// Steps de arranque alternativos (solo tests): reemplazan la cadena real.
  @visibleForTesting
  final List<StartupStep>? startupSteps;

  /// Fuente de "¿hay usuarios?" (solo tests): evita tocar la DB real y permite
  /// verificar el destino del fail-open de forma determinista.
  @visibleForTesting
  final Future<bool> Function()? hasUsersOverride;

  /// Consulta de usuarios de la decisión de ruta (solo tests): reemplaza la
  /// llamada real a la DB en `_decideRoute`. Permite simular un paso colgado
  /// (future que nunca completa) para verificar el fence de la secuencia de
  /// ruta. Solo se consume `isEmpty` del resultado.
  @visibleForTesting
  final Future<List<Object>> Function()? usersQueryOverride;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final steps = widget.startupSteps ?? _buildStartupSteps();
    final result = await runStartupFlow(
      timeout: _startupTimeout,
      log: (m) => debugPrint('[splash] $m'),
      steps: steps,
    );

    if (!mounted) return;
    if (result.timedOut) {
      debugPrint(
        '[splash] TIMEOUT colgado en ${result.hangingStep} -> fail-open',
      );
      _goFallback();
      return;
    }

    _decideRoute();
  }

  /// Cadena de arranque real: pasos aislados + fence de 10s (spec R1/R2).
  /// El último paso resuelve la decisión de ruta a partir de datos ya
  /// capturados; las side-effects (revocar licencia, tema por rol) se
  /// aplican después, fuera del fence, en [_applyDecision].
  List<StartupStep> _buildStartupSteps() => [
    (
      name: 'db-init',
      run: () async {
        final db = AppDatabase.instance;
        await db.createDefaultAdmin();
        await db.createDefaultJefe();
        await db.initDefaultPlans();
      },
    ),
    (
      name: 'backup-init',
      run: () async {
        await DatabaseBackupService.instance.initAutoBackup();
      },
    ),
    (
      name: 'exports-cleanup',
      run: () async {
        ExportService.instance.weeklyCleanupExports();
      },
    ),
  ];

  Future<void> _decideRoute() async {
    try {
      debugPrint('[splash] === CHECK - LICENSE FLOW ===');

      final db = AppDatabase.instance;

      // 1. Usuarios existentes
      final users = await _boundedRouteStep(
        'users-query',
        widget.usersQueryOverride?.call() ?? db.getAllUsers(),
      );
      if (!mounted) return;
      if (users.isEmpty) {
        debugPrint('[splash] Va a Registro (sin usuarios)');
        context.go('/register');
        return;
      }

      // 2. Licencia activada en secure_storage
      final activatedLicense = await _boundedRouteStep(
        'license-read',
        LicenseService.getActivatedLicenseCode(),
      );
      if (!mounted) return;
      if (activatedLicense == null || activatedLicense.isEmpty) {
        debugPrint('[splash] Va a Login (sin licencia activada)');
        context.go('/login');
        return;
      }

      // 3. Validación con protección anti-manipulación
      final validationResult = await _boundedRouteStep(
        'license-validate',
        LicenseService.validateLicenseWithTamperProtection(db),
      );
      if (!mounted) return;

      // 4. Licencia vencida -> pantalla dedicada
      if (validationResult.isExpired) {
        debugPrint('[splash] Va a LicenseExpiredScreen');
        context.go(
          '/license-expired',
          extra: {
            'expiredDate': validationResult.expiredDate,
            'daysElapsed': validationResult.daysElapsed,
            'durationDays': validationResult.durationDays,
          },
        );
        return;
      }

      // 5. Licencia inválida (otro error) -> login (desde ahí puede activar)
      if (!validationResult.isValid) {
        debugPrint(
          '[splash] Licencia inválida: ${validationResult.errorMessage}',
        );
        context.go('/login');
        return;
      }

      // 6. Verificar vínculo Android ID (no-fatal, 3s máximo interno)
      final deviceAndroidId = await _boundedRouteStep(
        'fingerprint',
        LicenseService.getDeviceFingerprintOrNull(),
      );
      if (!mounted) return;

      if (deviceAndroidId != null) {
        final licenseParts = activatedLicense.split('-');
        final deviceIdFromLicense = licenseParts.length > 6
            ? licenseParts.sublist(5, licenseParts.length - 1).join('-')
            : (licenseParts.length > 5 ? licenseParts[5] : '');
        if (deviceIdFromLicense.isNotEmpty && deviceIdFromLicense != 'DEV') {
          if (deviceIdFromLicense != deviceAndroidId) {
            debugPrint(
              '[splash] Android ID mismatch! Licencia vinculada a '
              '$deviceIdFromLicense, dispositivo actual: $deviceAndroidId',
            );
            // Revocar licencia — fue generada para otro dispositivo
            await _boundedRouteStep('license-revoke', () async {
              await _secureStorage.delete(key: 'activated_license');
              await _secureStorage.delete(key: 'license_key');
            }());
            if (mounted) {
              context.go('/login');
            }
            return;
          }
          debugPrint(
            '[splash] Android ID verificado: coincide con la licencia',
          );
        }
      } else {
        debugPrint(
          '[splash] Huella no disponible: se omite la verificación de vínculo',
        );
      }

      // 7. Sesión activa (< 24h)
      final (sessionToken, sessionTime) = await _boundedRouteStep(
        'session-read',
        () async {
          final token = await _secureStorage.read(key: 'session_token');
          final time = await _secureStorage.read(key: 'session_time');
          return (token, time);
        }(),
      );
      if (!mounted) return;

      var sessionActive = false;
      if (sessionToken != null &&
          sessionToken.isNotEmpty &&
          sessionTime != null) {
        final lastLogin = DateTime.tryParse(sessionTime);
        if (lastLogin != null) {
          sessionActive = DateTime.now().difference(lastLogin).inHours < 24;
        }
      }

      debugPrint('[splash] Session activa: $sessionActive');

      // 8. Sesión activa -> Home (con tema por rol antes del primer frame)
      if (sessionActive) {
        final savedRole =
            (await _boundedRouteStep(
              'role-read',
              _secureStorage.read(key: 'user_role'),
            )) ??
            '';
        if (mounted && savedRole.isNotEmpty) {
          setDefaultThemeForRole(ref, savedRole);
        }
        if (mounted) {
          context.go('/');
        }
        return;
      }

      // 9. Sin sesión activa -> Login
      debugPrint('[splash] Va a Login (sin sesión activa)');
      context.go('/login');
    } catch (e) {
      debugPrint('[splash] Error splash: $e');
      if (mounted) {
        // Fail-open: respeta si hay usuarios (register en primera vez).
        await _goFallback();
      }
    }
  }

  /// Ejecuta un paso de la decisión de ruta con su propio fence de tiempo y
  /// logging `[splash] STEP ok|fail`: loguea START antes, OK al resolver y
  /// FAIL si el paso lanza o excede [_routeStepTimeout] (re-lanzando la
  /// excepción para que el caller haga fail-open).
  Future<T> _boundedRouteStep<T>(String name, Future<T> future) async {
    debugPrint('[splash] [STEP] START $name');
    try {
      final value = await future.timeout(_routeStepTimeout);
      debugPrint('[splash] [STEP] OK $name');
      return value;
    } catch (e) {
      debugPrint('[splash] [STEP] FAIL $name: $e');
      rethrow;
    }
  }

  /// Fallback fail-open tras timeout global: sabe si hay usuarios para decidir
  /// entre /register y /login. Si la consulta falla, va a /login (el router
  /// real redirige a /register cuando el sistema está en primera vez).
  Future<void> _goFallback() async {
    if (!mounted) return;

    var hasUsers = true;
    try {
      if (widget.hasUsersOverride != null) {
        hasUsers = await widget.hasUsersOverride!().timeout(
          _fallbackUsersTimeout,
        );
      } else {
        final users = await AppDatabase.instance.getAllUsers().timeout(
          _fallbackUsersTimeout,
        );
        hasUsers = users.isNotEmpty;
      }
    } catch (e) {
      debugPrint(
        '[splash] Fallback: no se pudo consultar usuarios ($e) -> login',
      );
      hasUsers = true;
    }

    if (!mounted) return;
    debugPrint('[splash] Fail-open -> ${hasUsers ? '/login' : '/register'}');
    context.go(hasUsers ? '/login' : '/register');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.store_rounded,
                    color: AppColors.accent,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ExpressPos',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Punto de Venta',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Verificando licencia...',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
