import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/core/security/license_service.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/database_backup_service.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/license/presentation/screens/license_expired_screen.dart';

const _secureStorage = FlutterSecureStorage();

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final db = AppDatabase.instance;
      // Crear admin por defecto si no existe
      await db.createDefaultAdmin();
      // Crear usuario jefe hardcodeado
      await db.createDefaultJefe();
      // Inicializar planes de licencias por defecto
      await db.initDefaultPlans();
      // Inicializar auto-backup según configuración
      await DatabaseBackupService.instance.initAutoBackup();
      // Limpieza semanal de exportaciones (archivos >7 días)
      ExportService.instance.weeklyCleanupExports();
      debugPrint('=== APP INIT DONE ===');
    } catch (e) {
      debugPrint('Error init: $e');
    }
    // Luego verificar licencia
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      debugPrint('=== SPLASH CHECK - LICENSE FLOW ===');

      // 1. Verificar si hay usuarios
      final db = AppDatabase.instance;
      final users = await db.getAllUsers();
      final hasUsers = users.isNotEmpty;

      debugPrint('Has users: $hasUsers');

      // 2. Si NO hay usuarios -> Ir a registro
      if (!hasUsers) {
        debugPrint('Va a Registro (sin usuarios)');
        context.go('/register');
        return;
      }

      // 3. Verificar si hay licencia activada en secure_storage
      final activatedLicense = await LicenseService.getActivatedLicenseCode();
      debugPrint('Activated license: $activatedLicense');

      // 4. Si no hay licencia -> Ir a Login (mostrará "activar licencia")
      if (activatedLicense == null || activatedLicense.isEmpty) {
        debugPrint('Va a Login (sin licencia activada)');
        context.go('/login');
        return;
      }

      // 5. Si hay licencia -> Validar con protección anti-manipulación
      debugPrint('Validando licencia con protección...');
      final validationResult = await LicenseService.validateLicenseWithTamperProtection(db);

      debugPrint('License validation result: isValid=${validationResult.isValid}, isExpired=${validationResult.isExpired}');

      // 6. Si la licencia está vencida -> Mostrar pantalla de licencia vencida
      if (validationResult.isExpired) {
        debugPrint('Va a LicenseExpiredScreen');
        context.go('/license-expired', extra: {
          'expiredDate': validationResult.expiredDate,
          'daysElapsed': validationResult.daysElapsed,
          'durationDays': validationResult.durationDays,
        });
        return;
      }

    // 7. Si la licencia no es válida (otro error)
    if (!validationResult.isValid) {
      debugPrint('Licencia inválida: ${validationResult.errorMessage}');
      // Ir a login, desde ahí puede activar licencia
      context.go('/login');
      return;
    }

    // 7.5. Verificar que el Android ID del código coincida con el dispositivo
    final deviceAndroidId = await LicenseService.getDeviceFingerprint();
    final licenseParts = activatedLicense.split('-');
    // Device ID puede contener guiones: todo entre pos 5 y el ultimo (hash)
    final deviceIdFromLicense = licenseParts.length > 6
        ? licenseParts.sublist(5, licenseParts.length - 1).join('-')
        : (licenseParts.length > 5 ? licenseParts[5] : '');
    if (deviceIdFromLicense.isNotEmpty && deviceIdFromLicense != 'DEV') {
      if (deviceIdFromLicense != deviceAndroidId) {
        debugPrint('Android ID mismatch! Licencia vinculada a $deviceIdFromLicense, dispositivo actual: $deviceAndroidId');
        // Revocar licencia — fue generada para otro dispositivo
        await _secureStorage.delete(key: 'activated_license');
        await _secureStorage.delete(key: 'license_key');
        if (mounted) {
          context.go('/login');
        }
        return;
      }
      debugPrint('Android ID verificado: coincide con la licencia');
    }

    // 8. Licencia válida -> Verificar sesión activa (< 24h)
      final sessionToken = await _secureStorage.read(key: 'session_token');
      final sessionTime = await _secureStorage.read(key: 'session_time');

      bool sessionActiva = false;
      if (sessionToken != null && sessionToken.isNotEmpty && sessionTime != null) {
        final lastLogin = DateTime.tryParse(sessionTime);
        if (lastLogin != null) {
          final diff = DateTime.now().difference(lastLogin);
          if (diff.inHours < 24) {
            sessionActiva = true;
          }
        }
      }

      debugPrint('Session activa: $sessionActiva');

      // 9. Si sesión activa -> Ir a Home
      if (sessionActiva) {
        debugPrint('Va a Home (sesión activa)');
        context.go('/');
        return;
      }

      // 10. Si no hay sesión activa -> Ir a Login
      debugPrint('Va a Login (sin sesión activa)');
      context.go('/login');

    } catch (e) {
      debugPrint('Error splash: $e');
      if (mounted) {
        // En caso de error, ir a login
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colorCeleste,
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.store_rounded,
                    color: AppTheme.colorCeleste,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'PosJVL',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Punto de Venta',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Verificando licencia...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}