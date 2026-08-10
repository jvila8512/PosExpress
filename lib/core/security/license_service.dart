import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LicenseService {
  static const String _secretKey = 'PosJVL2024SecretKey1234';
  static const _storage = FlutterSecureStorage();

  // ================================================================
  // CONSTANTES PARA LICENCIAS
  // ================================================================
  static const String ACTIVATION_DATE_KEY = 'license_activation_date';
  static const String LAST_LOGIN_DATE_KEY = 'license_last_login';
  static const String LICENSE_DURATION_DAYS = 'license_duration_days';
  static const int DEFAULT_FREE_DURATION_DAYS = 15;
  static const int DEFAULT_NEGOCIO_DURATION_DAYS = 31;
  static const int DEFAULT_PRO_DURATION_DAYS = 90;
  static const int DEFAULT_MAX_DURATION_DAYS = 180;
  static const int DEFAULT_MAXPRO_DURATION_DAYS = 365;

  // WhatsApp de contacto
  static const String JAVIER_WHATSAPP = '+5352046805';

  // ================================================================
  // MÉTODOS DE ALMACENAMIENTO SEGURO (ANTI-TAMPERING)
  // ================================================================

  /// Guardar fecha de activación de la licencia
  static Future<void> saveActivationDate(DateTime date) async {
    await _storage.write(key: ACTIVATION_DATE_KEY, value: date.toIso8601String());
  }

  /// Obtener fecha de activación de la licencia
  static Future<DateTime?> getActivationDate() async {
    final dateStr = await _storage.read(key: ACTIVATION_DATE_KEY);
    if (dateStr != null) {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  /// Guardar última fecha de inicio de sesión (para detección de manipulación)
  static Future<void> saveLastLoginDate(DateTime date) async {
    await _storage.write(key: LAST_LOGIN_DATE_KEY, value: date.toIso8601String());
  }

  /// Obtener última fecha de inicio de sesión
  static Future<DateTime?> getLastLoginDate() async {
    final dateStr = await _storage.read(key: LAST_LOGIN_DATE_KEY);
    if (dateStr != null) {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  /// Guardar duración de la licencia en días
  static Future<void> saveLicenseDuration(int days) async {
    await _storage.write(key: LICENSE_DURATION_DAYS, value: days.toString());
  }

  /// Obtener duración de la licencia en días
  static Future<int> getLicenseDuration() async {
    final daysStr = await _storage.read(key: LICENSE_DURATION_DAYS);
    if (daysStr != null) {
      return int.tryParse(daysStr) ?? DEFAULT_PRO_DURATION_DAYS;
    }
    return DEFAULT_PRO_DURATION_DAYS;
  }

  // ================================================================
  // VALIDACIÓN CON PROTECCIÓN ANTI-MANIPULACIÓN DE RELOJ
  // ================================================================

  /// Validar licencia con protección contra manipulación del reloj
  /// Este método detecta si el usuario cambió la hora del dispositivo
  static Future<LicenseValidationResult> validateLicenseWithTamperProtection(
    dynamic db,
  ) async {
    try {
      // 1. Obtener código de licencia activado desde secure storage
      final licenseCode = await getActivatedLicenseCode();
      if (licenseCode == null || licenseCode.isEmpty) {
        return LicenseValidationResult.noLicense();
      }

      // 2. Buscar en la base de datos
      final licenses = await db.getAllLicenses();
      dynamic license;

      // Buscar por licenseKey o código
      for (final l in licenses) {
        if (l.licenseKey == licenseCode) {
          license = l;
          break;
        }
      }

      if (license == null) {
        // Buscar en licencias de cliente
        final clientLicenses = await db.getAllLicenciasCliente();
        for (final l in clientLicenses) {
          if (l.codigo == licenseCode) {
            // Convertir a formato compatible
            return LicenseValidationResult.valid(
              plan: _getPlanFromString(l.plan),
              expiresAt: l.fechaExpiracion,
              activatedAt: l.fechaCreacion,
              isFromClientTable: true,
            );
          }
        }
        
        // Si no se encuentra en la BD, usar datos del secure storage
        // El código ya fue validado en el momento de la activación
        print('⚠️[LICENSE] Licencia no encontrada en BD, usando datos de secure storage');
        return _validateFromSecureStorage(licenseCode);
      }

      // 3. Obtener fecha de activación o usar fecha de inicio de la licencia
      DateTime activationDate = license.fechaInicio;

      // Si tenemos fecha guardada, usarla (más confiable)
      final savedActivationDate = await getActivationDate();
      if (savedActivationDate != null) {
        activationDate = savedActivationDate;
      }

      // 4. Obtener última fecha de login
      final lastLoginDate = await getLastLoginDate();
      final currentTime = DateTime.now();

      // 5. Detectar manipulación del reloj
      DateTime referenceDate = currentTime;

      // Si hay una fecha de último login previa
      if (lastLoginDate != null) {
        // Si el tiempo actual es MENOR que el último login
        // → Alguien manipuló el reloj hacia atrás
        if (currentTime.isBefore(lastLoginDate)) {
          // Usar la última fecha de login como referencia (el tiempo no puede ir hacia atrás)
          referenceDate = lastLoginDate;
          print('⚠️[LICENSE] Posible manipulación detectada: reloj modificado hacia atrás');
        }
      }

      // 6. Calcular días transcurridos desde activación
      final daysElapsed = referenceDate.difference(activationDate).inDays;

      // 7. Obtener duración de la licencia
      final durationDays = await getLicenseDuration();

      // 8. Verificar si la licencia ha expirado
      if (daysElapsed > durationDays) {
        print('⚠️[LICENSE] Licencia vencida: $daysElapsed días > $durationDays días');
        return LicenseValidationResult.expired(
          message: 'Licencia vencida',
          expiredDate: activationDate.add(Duration(days: durationDays)),
          daysElapsed: daysElapsed,
          durationDays: durationDays,
        );
      }

      // 9. Verificar también la fecha de fin de la licencia en BD
      if (license.fechaFin.isBefore(currentTime)) {
        return LicenseValidationResult.expired(
          message: 'Licencia vencida según fecha de expiración',
          expiredDate: license.fechaFin,
          daysElapsed: daysElapsed,
          durationDays: durationDays,
        );
      }

      // 10. Actualizar última fecha de login
      await saveLastLoginDate(currentTime);

      // 11. Determinar el plan
      final plan = _getPlanFromLicense(license);

      return LicenseValidationResult.valid(
        plan: plan,
        expiresAt: license.fechaFin,
        activatedAt: activationDate,
        isFromClientTable: false,
      );

    } catch (e) {
      print('Error validando licencia: $e');
      return LicenseValidationResult.invalid(message: 'Error: $e');
    }
  }

  /// Validar licencia usando datos del secure storage (cuando no está en la BD)
  /// El código ya fue validado en el momento de la activación
  /// AHORA también parsea el plan y fecha desde el código original si no hay datos en storage
  static Future<LicenseValidationResult> _validateFromSecureStorage(String licenseCode) async {
    try {
      // 0. Parsear plan y fecha desde el código de licencia original
      // Formato: TIPO-PLAN-FECHA-HASH (ej: ADMIN-PRO-2027-12-31-0A07ABA4)
      LicensePlan? plan;
      DateTime? expiresAt;
      
    final codeParts = licenseCode.toUpperCase().split('-');
    if (codeParts.length >= 6) {
      // Nuevo formato: TIPO-PLAN-FECHA-ANDROIDID-HASH
      // codeParts[0] = TIPO (ADMIN, VENDEDOR, etc)
      // codeParts[1] = PLAN (PRO, NEGOCIO, FREE)
      // codeParts[2], [3], [4] = FECHA (2027-12-31)
      // codeParts[5..N-1] = ANDROID_ID (puede contener guiones)
      // codeParts[N-1] = HASH
      plan = _getPlanFromString(codeParts.length > 1 ? codeParts[1] : null);
      try {
        final fechaStr = '${codeParts[2]}-${codeParts[3]}-${codeParts[4]}';
        expiresAt = DateTime.parse(fechaStr);
      } catch (e) {
        print('⚠️[LICENSE] No se pudo parsear fecha del código: $e');
      }

      // Extraer device ID: todo entre posicion 5 y el ultimo segmento (hash)
      // Ej: ADMIN-FREE-2026-07-23-VVOB35.78-66-A2951FA6
      //   -> deviceId = VVOB35.78-66, hash = A2951FA6
      final deviceIdFromCode = codeParts.length > 6
          ? codeParts.sublist(5, codeParts.length - 1).join('-')
          : (codeParts.length > 5 ? codeParts[5] : '');

      // Verificar que el Android ID del código coincida con el dispositivo actual
      if (deviceIdFromCode.isNotEmpty && deviceIdFromCode != 'DEV') {
        final currentDeviceId = await getDeviceFingerprint();
        if (deviceIdFromCode != currentDeviceId.toUpperCase()) {
          return LicenseValidationResult.invalid(
            message: 'Esta licencia no corresponde a este dispositivo',
          );
        }
      }
    } else if (codeParts.length >= 5) {
      // Formato antiguo (sin Android ID) — compatibilidad hacia atrás
      plan = _getPlanFromString(codeParts.length > 1 ? codeParts[1] : null);
      try {
        final fechaStr = '${codeParts[2]}-${codeParts[3]}-${codeParts[4]}';
        expiresAt = DateTime.parse(fechaStr);
      } catch (e) {
        print('⚠️[LICENSE] No se pudo parsear fecha del código: $e');
      }
    }
      
      // Si tenemos la fecha del código, usarla directamente
      if (expiresAt != null) {
        final currentTime = DateTime.now();
        final isExpired = expiresAt.isBefore(currentTime);
        
        // Obtener última fecha de login para protección anti-manipulación
        final lastLoginDate = await getLastLoginDate();
        
        // Actualizar última fecha de login
        await saveLastLoginDate(currentTime);
        
        if (isExpired) {
          return LicenseValidationResult.expired(
            message: 'Licencia vencida según fecha del código',
            expiredDate: expiresAt,
            daysElapsed: currentTime.difference(expiresAt).inDays.abs(),
            durationDays: currentTime.difference(expiresAt).inDays.abs(),
          );
        }
        
        return LicenseValidationResult.valid(
          plan: plan ?? LicensePlan.pro,
          expiresAt: expiresAt,
          activatedAt: null,
          isFromClientTable: false,
        );
      }
      
      // Fallback: usar datos del secure storage si no se pudo parsear del código
      // 1. Obtener el plan desde secure storage
      final planStr = await _storage.read(key: 'license_plan');
      plan = _getPlanFromString(planStr ?? 'free');
      
      // 2. Obtener fecha de activación
      final activationDate = await getActivationDate();
      if (activationDate == null) {
        // Si no hay fecha de activación, usar la fecha actual como inicio
        return LicenseValidationResult.valid(
          plan: plan,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          activatedAt: DateTime.now(),
          isFromClientTable: false,
        );
      }
      
      // 3. Obtener duración de la licencia
      final durationDays = await getLicenseDuration();
      
      // 4. Obtener última fecha de login para protección anti-manipulación
      final lastLoginDate = await getLastLoginDate();
      final currentTime = DateTime.now();
      
      // 5. Detectar manipulación del reloj
      DateTime referenceDate = currentTime;
      if (lastLoginDate != null && currentTime.isBefore(lastLoginDate)) {
        referenceDate = lastLoginDate;
        print('⚠️[LICENSE] Posible manipulación detectada: reloj modificado hacia atrás');
      }
      
      // 6. Calcular días transcurridos desde activación
      final daysElapsed = referenceDate.difference(activationDate).inDays;
      
      // 7. Verificar si la licencia ha expirado
      if (daysElapsed > durationDays) {
        print('⚠️[LICENSE] Licencia vencida (secure storage): $daysElapsed días > $durationDays días');
        return LicenseValidationResult.expired(
          message: 'Licencia vencida',
          expiredDate: activationDate.add(Duration(days: durationDays)),
          daysElapsed: daysElapsed,
          durationDays: durationDays,
        );
      }
      
      // 8. Calcular fecha de expiración
      expiresAt = activationDate.add(Duration(days: durationDays));
      
      // 9. Actualizar última fecha de login
      await saveLastLoginDate(currentTime);
      
      return LicenseValidationResult.valid(
        plan: plan,
        expiresAt: expiresAt,
        activatedAt: activationDate,
        isFromClientTable: false,
      );
    } catch (e) {
      print('Error validando desde secure storage: $e');
      return LicenseValidationResult.invalid(message: 'Error: $e');
    }
  }

  /// Obtener plan desde string
  static LicensePlan _getPlanFromString(String? planStr) {
    if (planStr == null) return LicensePlan.free;
    switch (planStr.toLowerCase()) {
      case 'free':
        return LicensePlan.free;
      case 'negocio':
        return LicensePlan.negocio;
      case 'pro':
        return LicensePlan.pro;
      case 'max':
        return LicensePlan.max;
      case 'maxpro':
        return LicensePlan.maxpro;
      default:
        return LicensePlan.free;
    }
  }

  /// Obtener plan desde licencia
  static LicensePlan _getPlanFromLicense(dynamic license) {
    // Determinar plan basado en el licenseKey o tipo
    final licenseKey = license.licenseKey?.toUpperCase() ?? '';
    if (licenseKey.contains('MAXPRO')) {
      return LicensePlan.maxpro;
    } else if (licenseKey.contains('MAX')) {
      return LicensePlan.max;
    } else if (licenseKey.contains('PRO')) {
      return LicensePlan.pro;
    } else if (licenseKey.contains('NEGOCIO')) {
      return LicensePlan.negocio;
    }
    return LicensePlan.free;
  }

  /// Obtener días restantes de licencia
  static Future<int> getLicenseRemainingDays(dynamic db) async {
    final result = await validateLicenseWithTamperProtection(db);
    if (result.isValid && result.expiresAt != null) {
      final remaining = result.expiresAt!.difference(DateTime.now()).inDays;
      return remaining > 0 ? remaining : 0;
    }
    return 0;
  }

  /// Actualizar fecha de último login (llamar en cada inicio de sesión)
  static Future<void> updateLastLoginDate() async {
    await saveLastLoginDate(DateTime.now());
  }

  /// Obtener el código de licencia activado desde secure storage
  static Future<String?> getActivatedLicenseCode() async {
    return await _storage.read(key: 'activated_license');
  }

  static Future<String> getDeviceFingerprint() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    return deviceInfo.id; // Android ID — unique per device+app
  }

  /// Versión no-fatal de [getDeviceFingerprint]: si el canal de plataforma
  /// cuelga o tira, devuelve `null` en lugar de propagar — la huella se
  /// trata como "no disponible" y el arranque sigue. Útil para el splash,
  /// que no debe quedarse colgado esperando el DeviceInfoPlugin.
  ///
  /// Inyectable para tests: [source] reemplaza la llamada real.
  static Future<String?> getDeviceFingerprintOrNull({
    Duration timeout = const Duration(seconds: 3),
    Future<String> Function()? source,
  }) async {
    try {
      return await (source ?? getDeviceFingerprint)().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  static Future<LicenseResult> activateLicense(String code, dynamic db) async {
    final result = validateLicense(code);
    if (!result.isValid) return result;
    
    final deviceId = await getDeviceFingerprint();
    final licenseKey = _generateLicenseKey(
      result.userType!.name,
      result.plan!.name,
      result.expiresAt!,
      deviceId,
    );
    
    try {
      await db.into(db.licenses).insert(
        db.LicensesCompanion.insert(
          id: const Uuid().v4(),
          licenseKey: licenseKey,
          tipo: result.userType!.name.toLowerCase(),
          fechaInicio: DateTime.now(),
          fechaFin: result.expiresAt!,
          dispositivoId: Value(deviceId),
        ),
      );
      
      await _storage.write(key: 'license_key', value: licenseKey);
      await _storage.write(key: 'license_type', value: result.userType!.name);
      
      return result;
    } catch (e) {
      return LicenseResult.invalid('Error al guardar: $e');
    }
  }

  static Future<LicenseResult> checkActiveLicense(dynamic db) async {
    try {
      final cachedKey = await _storage.read(key: 'license_key');
      if (cachedKey == null) {
        return LicenseResult.noActivada();
      }
      
      final license = await (db.select(db.licenses)
            ..where((l) => l.licenseKey.equals(cachedKey)))
          .getSingleOrNull();
      
      if (license == null) {
        await _storage.delete(key: 'license_key');
        return LicenseResult.noActivada();
      }
      
      if (license.fechaFin.isBefore(DateTime.now())) {
        return LicenseResult.expired('Licencia vencida');
      }
      
      final deviceId = await getDeviceFingerprint();
      if (license.dispositivoId != null && license.dispositivoId != deviceId) {
        return LicenseResult.invalid('Dispositivo no autorizado');
      }
      
      final userType = UserType.values.firstWhere(
        (e) => e.name.toUpperCase() == license.tipo.toUpperCase(),
        orElse: () => UserType.vendedor,
      );
      
      return LicenseResult.valid(
        userType: userType,
        plan: _getPlanFromLicense(license),
        expiresAt: license.fechaFin,
      );
    } catch (e) {
      return LicenseResult.invalid('Error: $e');
    }
  }

  static String _generateLicenseKey(String tipo, String plan, DateTime fecha, String deviceId) {
    final data = 'POSJVL-$tipo-$plan-${fecha.toIso8601String()}-$deviceId-$_secretKey';
    return _generateHash(data);
  }

  static bool _isDevCode(String code) {
    final devCodes = [
      'ADMIN-FREE-2027-12-31-DEV-DEV',
      'ADMIN-NEGOCIO-2099-12-31-DEV-DEV',
      'ADMIN-PRO-2027-12-31-DEV-DEV',
      'VENDEDOR-PRO-2027-12-31-DEV-DEV',
      'ADMIN-MAX-2027-12-31-DEV-DEV',
      'ADMIN-MAXPRO-2027-12-31-DEV-DEV',
    ];
    return devCodes.contains(code.toUpperCase());
  }

  static LicenseResult validateLicense(String code, {String? deviceAndroidId}) {
    try {
      final parts = code.trim().toUpperCase().split('-');

      if (parts.length < 6) {
        return LicenseResult.invalid('Código inválido — debe incluir ID de dispositivo');
      }

      final tipo = parts[0];
      final plan = parts[1];
      final fechaExp = parts[2] + '-' + parts[3] + '-' + parts[4];
      // Device ID puede contener guiones (ej: VVOB35.78-66)
      // Hash es siempre el ultimo segmento
      final androidIdInCode = parts.length > 6
          ? parts.sublist(5, parts.length - 1).join('-')
          : parts[5];
      final hashRecibido = parts.last;

      if (!['ADMIN', 'VENDEDOR', 'ALMACENERO'].contains(tipo)) {
        return LicenseResult.invalid('Tipo de licencia inválido');
      }

      if (!['FREE', 'NEGOCIO', 'PRO', 'MAX', 'MAXPRO'].contains(plan)) {
        return LicenseResult.invalid('Plan de licencia inválido');
      }

    final fechaVencimiento = DateTime.tryParse(fechaExp);
    if (fechaVencimiento == null) {
      return LicenseResult.invalid('Fecha inválida');
    }
    if (fechaVencimiento.isBefore(DateTime.now())) {
      return LicenseResult.expired('Licencia vencida');
    }

    // Si es código DEV, saltar verificaciones de dispositivo y hash
    final isDevCode = _isDevCode(code);
    if (isDevCode) {
      final userType = UserType.values.firstWhere(
        (e) => e.name == tipo,
        orElse: () => UserType.vendedor,
      );
      final licensePlan = LicensePlan.values.firstWhere(
        (e) => e.name == plan,
        orElse: () => LicensePlan.free,
      );
      return LicenseResult.valid(
        userType: userType,
        plan: licensePlan,
        expiresAt: fechaVencimiento,
      );
    }

    // Verificar que el Android ID del código coincida con el dispositivo
    if (deviceAndroidId != null && deviceAndroidId.isNotEmpty) {
      if (androidIdInCode != deviceAndroidId.toUpperCase()) {
        return LicenseResult.invalid('Esta licencia no corresponde a este dispositivo');
      }
    }

    final dataToHash = '$tipo-$plan-$fechaExp-$androidIdInCode-$_secretKey';
    final hashEsperado = _generateHash(dataToHash);

    if (hashRecibido != hashEsperado) {
      return LicenseResult.invalid('Código no autorizado');
    }

      final userType = UserType.values.firstWhere(
        (e) => e.name == tipo,
        orElse: () => UserType.vendedor,
      );

      final licensePlan = LicensePlan.values.firstWhere(
        (e) => e.name == plan,
        orElse: () => LicensePlan.free,
      );

      return LicenseResult.valid(
        userType: userType,
        plan: licensePlan,
        expiresAt: fechaVencimiento,
      );
    } catch (e) {
      return LicenseResult.invalid('Error al validar: $e');
    }
  }

  static String _generateHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// Generar código de licencia para un dispositivo específico (uso admin)
  static String generateLicenseCode(String tipo, String plan, DateTime fechaExpiracion, String androidId) {
    final fechaStr = '${fechaExpiracion.year}-${fechaExpiracion.month.toString().padLeft(2, '0')}-${fechaExpiracion.day.toString().padLeft(2, '0')}';
    final dataToHash = '${tipo.toUpperCase()}-${plan.toUpperCase()}-$fechaStr-${androidId.toUpperCase()}-$_secretKey';
    final hash = _generateHash(dataToHash);
    return '${tipo.toUpperCase()}-${plan.toUpperCase()}-$fechaStr-${androidId.toUpperCase()}-$hash';
  }
}

/// Resultado de validación de licencia con protección anti-manipulación
class LicenseValidationResult {
  final bool isValid;
  final bool isExpired;
  final bool hasLicense;
  final LicensePlan? plan;
  final DateTime? expiresAt;
  final DateTime? activatedAt;
  final String? errorMessage;
  final DateTime? expiredDate;
  final int? daysElapsed;
  final int? durationDays;
  final bool isFromClientTable;

  LicenseValidationResult._({
    required this.isValid,
    this.isExpired = false,
    this.hasLicense = true,
    this.plan,
    this.expiresAt,
    this.activatedAt,
    this.errorMessage,
    this.expiredDate,
    this.daysElapsed,
    this.durationDays,
    this.isFromClientTable = false,
  });

  factory LicenseValidationResult.valid({
    required LicensePlan plan,
    required DateTime expiresAt,
    DateTime? activatedAt,
    bool isFromClientTable = false,
  }) {
    return LicenseValidationResult._(
      isValid: true,
      plan: plan,
      expiresAt: expiresAt,
      activatedAt: activatedAt,
      isFromClientTable: isFromClientTable,
    );
  }

  factory LicenseValidationResult.expired({
    required String message,
    DateTime? expiredDate,
    int? daysElapsed,
    int? durationDays,
  }) {
    return LicenseValidationResult._(
      isValid: false,
      isExpired: true,
      hasLicense: true,
      errorMessage: message,
      expiredDate: expiredDate,
      daysElapsed: daysElapsed,
      durationDays: durationDays,
    );
  }

  factory LicenseValidationResult.noLicense() {
    return LicenseValidationResult._(
      isValid: false,
      hasLicense: false,
      errorMessage: 'No hay licencia activada',
    );
  }

  factory LicenseValidationResult.invalid({required String message}) {
    return LicenseValidationResult._(
      isValid: false,
      errorMessage: message,
    );
  }

  int get remainingDays {
    if (expiresAt == null) return 0;
    final remaining = expiresAt!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  String get planName {
    switch (plan) {
      case LicensePlan.free:
        return 'FREE';
      case LicensePlan.negocio:
        return 'NEGOCIO';
      case LicensePlan.pro:
        return 'PRO';
      case LicensePlan.max:
        return 'MAX';
      case LicensePlan.maxpro:
        return 'MAXPRO';
      default:
        return 'FREE';
    }
  }
}

class LicenseResult {
  final bool isValid;
  final bool isExpired;
  final UserType? userType;
  final LicensePlan? plan;
  final DateTime? expiresAt;
  final String? errorMessage;

  LicenseResult._({
    required this.isValid,
    this.isExpired = false,
    this.userType,
    this.plan,
    this.expiresAt,
    this.errorMessage,
  });

  factory LicenseResult.valid({
    required UserType userType,
    required LicensePlan plan,
    required DateTime expiresAt,
  }) {
    return LicenseResult._(
      isValid: true,
      userType: userType,
      plan: plan,
      expiresAt: expiresAt,
    );
  }

  factory LicenseResult.expired(String message) {
    return LicenseResult._(
      isValid: false,
      isExpired: true,
      errorMessage: message,
    );
  }

  factory LicenseResult.invalid(String message) {
    return LicenseResult._(
      isValid: false,
      errorMessage: message,
    );
  }

  factory LicenseResult.noActivada() {
    return LicenseResult._(
      isValid: false,
      errorMessage: 'Licencia no activada',
    );
  }

  bool get canAddProduct {
    if (plan == LicensePlan.negocio || plan == LicensePlan.pro || plan == LicensePlan.max || plan == LicensePlan.maxpro) return true;
    return true;
  }

  bool get canAddWorker {
    if (plan == LicensePlan.negocio || plan == LicensePlan.pro || plan == LicensePlan.max || plan == LicensePlan.maxpro) return true;
    return true;
  }

  bool get hasEncryption {
    return plan == LicensePlan.pro || plan == LicensePlan.negocio || plan == LicensePlan.max || plan == LicensePlan.maxpro;
  }

  bool get hasFullReports {
    return plan == LicensePlan.pro || plan == LicensePlan.negocio || plan == LicensePlan.max || plan == LicensePlan.maxpro;
  }
}

enum UserType { admin, vendedor, almacenero }
enum LicensePlan { free, negocio, pro, max, maxpro }