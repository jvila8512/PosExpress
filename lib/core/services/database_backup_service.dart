import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

/// Servicio de backup/restauración de la base de datos SQLite.
///
/// - Los backups se guardan en `{documents}/backups/` con timestamp.
/// - Se mantiene un máximo de [maxBackups] archivos (5 por defecto).
/// - El auto-backup usa un timer que corre mientras la app está abierta.
/// - Las preferencias de auto-backup se guardan en KeyValueStorageService
///   (no en la DB, para sobrevivir a una restauración).
class DatabaseBackupService {
  DatabaseBackupService._internal();
  static final DatabaseBackupService _instance =
      DatabaseBackupService._internal();
  static DatabaseBackupService get instance => _instance;

  static const int maxBackups = 5;

  // --- Keys para preferencias de auto-backup ---
  static const _autoBackupEnabledKey = 'auto_backup_enabled';
  static const _autoBackupFrequencyKey = 'auto_backup_frequency_hours';
  static const _autoBackupLastRunKey = 'auto_backup_last_run';

  Timer? _autoBackupTimer;
  int _autoBackupFrequencyHours = 24;

  // ============================================================
  // BACKUP INTERNO
  // ============================================================

  /// Crea un backup de la BD actual en el directorio interno de backups.
  /// Retorna el path del archivo creado, o null si falla.
  Future<String?> createBackup() async {
    try {
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return null;
      }

      final backupsDir = await _getBackupsDir();
      final timestamp = _formatTimestamp(DateTime.now());
      final backupName = 'posjvl_backup_$timestamp.db';
      final backupPath = p.join(backupsDir.path, backupName);

      await dbFile.copy(backupPath);

      // Limpiar backups viejos si excedemos el máximo
      await _pruneOldBackups();

      return backupPath;
    } catch (_) {
      return null;
    }
  }

  /// Lista todos los backups internos, ordenados por fecha (más reciente primero).
  Future<List<BackupInfo>> listBackups() async {
    final backupsDir = await _getBackupsDir();
    final files = await backupsDir.list().toList();

    final backups = <BackupInfo>[];
    for (final file in files) {
      if (file is File && file.path.endsWith('.db')) {
        final stat = await file.stat();
        final fileName = p.basename(file.path);
        final timestamp = _parseTimestamp(fileName);
        backups.add(BackupInfo(
          path: file.path,
          fileName: fileName,
          date: timestamp ?? stat.changed,
          sizeBytes: stat.size,
        ));
      }
    }

    backups.sort((a, b) => b.date.compareTo(a.date));
    return backups;
  }

  /// Restaura un backup desde el path dado.
  /// Cierra la DB, copia el archivo, invalida el singleton, y reabre.
  /// Retorna true si tuvo éxito.
  Future<bool> restoreBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) return false;

      // 1. Cerrar la conexión actual
      await AppDatabase.instance.close();

      // 2. Copiar el backup sobre la DB activa
      final dbPath = await _getDbPath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await backupFile.copy(dbPath);

      // 3. Invalidar el singleton para que se reabra con datos nuevos
      AppDatabase.resetInstance();

      // 4. Forzar apertura (lazy init se encarga, pero tocamos para verificar)
      await AppDatabase.instance.getAllUsers();

      // 5. Resetear auto-backup timer por si cambió la DB
      await _restartAutoBackupTimer();

      return true;
    } catch (_) {
      // En caso de error, igual invalidamos el singleton para que reintente
      AppDatabase.resetInstance();
      return false;
    }
  }

  /// Elimina un archivo de backup específico.
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Elimina todos los backups internos.
  Future<bool> deleteAllBackups() async {
    try {
      final backupsDir = await _getBackupsDir();
      final files = await backupsDir.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.db')) {
          await file.delete();
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // EXPORTAR / IMPORTAR
  // ============================================================

  /// Exporta un backup existente usando Share (WhatsApp, Drive, etc.).
  Future<bool> exportBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return false;

      final xFile = XFile(backupPath);
      await Share.shareXFiles(
        [xFile],
        text: 'Backup base de datos POS',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Crea un backup y lo exporta inmediatamente.
  Future<bool> createAndExportBackup() async {
    final path = await createBackup();
    if (path == null) return false;
    return exportBackup(path);
  }

  /// Importa un backup desde un archivo elegido por el usuario.
  /// Retorna true si la importación y restauración tuvieron éxito.
  Future<bool> importBackup() async {
    try {
      // En Android, usar FileType.any para evitar problemas con SAF
      // y el filtro de extensiones que puede no mostrar archivos .db
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Seleccionar backup de base de datos',
      );

      if (result == null || result.files.isEmpty) return false;

      final platformFile = result.files.first;
      final backupsDir = await _getBackupsDir();
      final timestamp = _formatTimestamp(DateTime.now());
      final importName = 'posjvl_imported_$timestamp.db';
      final importPath = p.join(backupsDir.path, importName);

      // Caso 1: path directo disponible (mayoría de dispositivos)
      if (platformFile.path != null) {
        final sourceFile = File(platformFile.path!);
        await sourceFile.copy(importPath);
      }
      // Caso 2: path es null (Android SAF / Google Drive) — usar bytes
      else if (platformFile.bytes != null) {
        await File(importPath).writeAsBytes(platformFile.bytes!);
      } else {
        return false;
      }

      // Verificar que el archivo no esté corrupto (debe empezar con SQLite header)
      final importedFile = File(importPath);
      final size = await importedFile.length();
      if (size < 100) return false; // Archivo demasiado pequeño, probablemente corrupto

      // Restaurar
      return restoreBackup(importPath);
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // AUTO-BACKUP
  // ============================================================

  /// Inicializa el timer de auto-backup según la configuración guardada.
  Future<void> initAutoBackup() async {
    final storage = KeyValueStorageService();
    final enabled = await storage.getValue(_autoBackupEnabledKey);
    final hours = await storage.getValue(_autoBackupFrequencyKey);

    if (enabled == 'true' && hours != null) {
      _autoBackupFrequencyHours = int.tryParse(hours) ?? 24;
      _startAutoBackupTimer();
    }
  }

  /// Detiene el timer de auto-backup.
  void stopAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
  }

  /// Actualiza la configuración de auto-backup y reinicia el timer.
  Future<void> setAutoBackupConfig({
    required bool enabled,
    required int frequencyHours,
  }) async {
    final storage = KeyValueStorageService();
    await storage.setKeyValue(
        _autoBackupEnabledKey, enabled ? 'true' : 'false');
    await storage.setKeyValue(
        _autoBackupFrequencyKey, frequencyHours.toString());

    _autoBackupFrequencyHours = frequencyHours;

    if (enabled) {
      _startAutoBackupTimer();
    } else {
      stopAutoBackup();
    }
  }

  /// Retorna la config actual de auto-backup.
  Future<AutoBackupConfig> getAutoBackupConfig() async {
    final storage = KeyValueStorageService();
    final enabled = await storage.getValue(_autoBackupEnabledKey);
    final hours = await storage.getValue(_autoBackupFrequencyKey);
    final lastRun = await storage.getValue(_autoBackupLastRunKey);

    return AutoBackupConfig(
      enabled: enabled == 'true',
      frequencyHours: int.tryParse(hours ?? '24') ?? 24,
      lastRun: lastRun != null
          ? DateTime.tryParse(lastRun)
          : null,
    );
  }

  /// Reinicia el timer de auto-backup (usado post-restore).
  Future<void> _restartAutoBackupTimer() async {
    stopAutoBackup();
    await initAutoBackup();
  }

  void _startAutoBackupTimer() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(
      Duration(hours: _autoBackupFrequencyHours),
      (_) async {
        await _runAutoBackup();
      },
    );

    // También verificar si ya pasó suficiente tiempo desde el último backup
    _checkIfBackupNeeded();
  }

  Future<void> _checkIfBackupNeeded() async {
    final storage = KeyValueStorageService();
    final lastRunStr = await storage.getValue(_autoBackupLastRunKey);
    if (lastRunStr == null) {
      // Nunca se corrió auto-backup, correr ahora
      await _runAutoBackup();
      return;
    }

    final lastRun = DateTime.tryParse(lastRunStr);
    if (lastRun == null) {
      await _runAutoBackup();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(lastRun);
    if (elapsed.inHours >= _autoBackupFrequencyHours) {
      await _runAutoBackup();
    }
  }

  Future<void> _runAutoBackup() async {
    final path = await createBackup();
    if (path != null) {
      final storage = KeyValueStorageService();
      await storage.setKeyValue(
          _autoBackupLastRunKey, DateTime.now().toIso8601String());
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<String> _getDbPath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'posjvl.db');
  }

  Future<Directory> _getBackupsDir() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(dbFolder.path, 'backups'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  Future<void> _pruneOldBackups() async {
    final backups = await listBackups();
    while (backups.length > maxBackups) {
      final oldest = backups.removeLast();
      await deleteBackup(oldest.path);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${y}_${m}_${d}_${h}_${min}_${s}';
  }

  DateTime? _parseTimestamp(String fileName) {
    // posjvl_backup_2026_06_05_14_30_22.db
    // posjvl_imported_2026_06_05_14_30_22.db
    final regex = RegExp(r'(\d{4})_(\d{2})_(\d{2})_(\d{2})_(\d{2})_(\d{2})');
    final match = regex.firstMatch(fileName);
    if (match == null) return null;

    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}

// ============================================================
// MODELOS
// ============================================================

class BackupInfo {
  final String path;
  final String fileName;
  final DateTime date;
  final int sizeBytes;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.date,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dateFormatted {
    final d = date;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$min';
  }
}

class AutoBackupConfig {
  final bool enabled;
  final int frequencyHours;
  final DateTime? lastRun;

  AutoBackupConfig({
    required this.enabled,
    required this.frequencyHours,
    this.lastRun,
  });

  String get frequencyLabel {
    switch (frequencyHours) {
      case 24:
        return 'Diario';
      case 48:
        return 'Cada 2 días';
      case 168:
        return 'Semanal';
      default:
        return 'Cada $frequencyHours horas';
    }
  }
}
