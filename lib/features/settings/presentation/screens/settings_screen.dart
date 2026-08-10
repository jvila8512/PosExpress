import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/features/shared/shared.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/config/theme/theme_preferences.dart';
import 'package:etecsa/config/theme/theme_provider.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/database_backup_service.dart';
import 'package:etecsa/core/services/test_data_generator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

/// Keys para preferencias
const _kioscoModeKey = 'kiosco_mode_enabled';
const _kioscoPinKey = 'kiosco_mode_pin';
const _businessNameKey = 'business_name';
const _businessPhoneKey = 'business_phone';
const _warehouseModeKey = 'warehouse_mode_enabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _storage = KeyValueStorageService();
  final _backupService = DatabaseBackupService.instance;
  bool _kioscoMode = false;
  bool _prefacturaMode = false;
  bool _warehouseMode = false;
  bool _isLoading = true;
  String _businessName = '';
  String _businessPhone = '';
  String _userRole = '';
  String _appVersion = '';

  // Backup state
  bool _autoBackupEnabled = false;
  int _autoBackupFrequencyHours = 24;
  DateTime? _autoBackupLastRun;
  List<BackupInfo> _backups = [];
  bool _backupLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _storage.getValue(_kioscoModeKey);
    final prefacturaEnabled = await _storage.getValue('prefactura_mode_enabled');
    final warehouseEnabled = await _storage.getValue(_warehouseModeKey);
    final name = await _storage.getValue(_businessNameKey);
    final phone = await _storage.getValue(_businessPhoneKey);
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role') ?? '';

    // Get app version
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version} (${info.buildNumber})';
    } catch (_) {
      _appVersion = '1.0.0';
    }

    // Load backup config
    final backupConfig = await _backupService.getAutoBackupConfig();
    final backups = await _backupService.listBackups();

    setState(() {
      _kioscoMode = enabled == 'true';
      _prefacturaMode = prefacturaEnabled == 'true';
      _warehouseMode = warehouseEnabled == 'true';
      _businessName = name ?? '';
      _businessPhone = phone ?? '';
      _userRole = role;
      _autoBackupEnabled = backupConfig.enabled;
      _autoBackupFrequencyHours = backupConfig.frequencyHours;
      _autoBackupLastRun = backupConfig.lastRun;
      _backups = backups;
      _isLoading = false;
    });
  }

  bool get _isVendedor => _userRole == 'vendedor';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
    body: _isLoading
    ? const Center(child: CircularProgressIndicator())
      : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App version
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'ExpressPos v$_appVersion',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
          ),
          // Vendedor: SOLO puede cambiar contraseña
        if (_isVendedor) ...[
          const Text('Cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar Contraseña'),
            subtitle: const Text('Actualiza tu contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(),
          ),
        ] else ...[
        // Admin/SuperAdmin: ven todo
                // Sección Tema
                const Text('Tema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Modo de color de la app. "Sistema" sigue el brillo del teléfono.'),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    return SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Oscuro'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('Sistema'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) async {
                        final mode = selection.first;
                        ref.read(themeModeProvider.notifier).state = mode;
                        await ThemePreferenceStore.write(mode);
                      },
                    );
                  },
                ),
                const Divider(height: 32),
                // Sección Modo Kiosco
                const Text('Modo Kiosco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Bloquea la navegación de Android cuando estás en el POS. El vendedor no podrá salir de la app.'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Activar Modo Kiosco'),
                  subtitle: const Text('Evita que toquen la navegación de Android'),
                  value: _kioscoMode,
                  activeColor: AppColors.accent,
                  onChanged: (value) async {
                    if (value) {
                      // Pedir confirmación con PIN
                      final pin = await _showPinDialog('PIN de activación:');
                      if (pin != null && pin.length == 4) {
                        await _storage.setKeyValue(_kioscoPinKey, pin);
                        await _storage.setKeyValue(_kioscoModeKey, 'true');
                        setState(() => _kioscoMode = true);
                        _showSnackBar('Modo Kiosco activado');
                      }
                    } else {
                      // Pedir PIN para desactivar
                      final pin = await _showPinDialog('PIN:');
                      final savedPin = await _storage.getValue(_kioscoPinKey);
                      if (pin == savedPin) {
                        await _storage.setKeyValue(_kioscoModeKey, 'false');
                        setState(() => _kioscoMode = false);
                        _showSnackBar('Modo Kiosco desactivado');
                      } else {
                        _showSnackBar('PIN incorrecto', isError: true);
                      }
                    }
                  },
                ),
                // Botón para recuperar PIN
                TextButton.icon(
                  onPressed: () => _showResetPinDialog(),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text('¿Olvidaste tu PIN?'),
                ),
                const Divider(height: 32),
                // Sección Modo Prefactura
                const Text('Modo Prefactura', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Genera prefacturas sin registrar ventas ni descontar stock. Agrega "Prefactura" al menú lateral.'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Activar Modo Prefactura'),
                  subtitle: const Text('Agrega "Prefactura" al menú lateral'),
                  value: _prefacturaMode,
                  activeColor: AppColors.accent,
                  onChanged: (value) async {
                    await _storage.setKeyValue('prefactura_mode_enabled', value ? 'true' : 'false');
                    setState(() => _prefacturaMode = value);
                    _showSnackBar(value ? 'Modo Prefactura activado' : 'Modo Prefactura desactivado');
                  },
                ),
                const Divider(height: 32),
                // Sección Almacén
                const Text('Almacén', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Separa el inventario en Almacén (compras) y Punto de Venta. Las compras van al almacén y necesitás trasladar al PV para vender.'),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Usar Almacén separado'),
                  subtitle: Text(_warehouseMode
                    ? 'Activo: compras → almacén, ventas → PV'
                    : 'Desactivado: todo va al PV'),
                  value: _warehouseMode,
                  activeColor: AppColors.accent,
                  onChanged: (value) async {
                    if (value) {
                      // Activar almacén
                      await _storage.setKeyValue(_warehouseModeKey, 'true');
                      setState(() => _warehouseMode = true);
                      _showSnackBar('Almacén activado. Las compras van al almacén.');
                      if (mounted) _showWarehouseActivatedDialog();
                    } else {
                      // Desactivar almacén — migrar stock de almacen → pv
                      final db = AppDatabase.instance;
                      final migrated = await db.migrateAlmacenToPv();
                      await _storage.setKeyValue(_warehouseModeKey, 'false');
                      setState(() => _warehouseMode = false);
                      if (migrated > 0) {
                        _showSnackBar('Almacén desactivado. $migrated productos migrados al PV.');
                      } else {
                        _showSnackBar('Almacén desactivado. Las compras van al PV.');
                      }
                    }
                  },
                ),
                const Divider(height: 32),
                // Sección Empresa
                const Text('Empresa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
  ListTile(
  leading: const Icon(Icons.store),
  title: const Text('Nombre de la empresa'),
  subtitle: Text(_businessName.isEmpty ? 'No configurado' : _businessName),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _showEditBusinessField(
    title: 'Nombre de la empresa',
    value: _businessName,
    key: _businessNameKey,
    onSaved: (val) => setState(() => _businessName = val),
  ),
),
ListTile(
  leading: const Icon(Icons.phone),
  title: const Text('Teléfono'),
  subtitle: Text(_businessPhone.isEmpty ? 'No configurado' : _businessPhone),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _showEditBusinessField(
    title: 'Teléfono de la empresa',
    value: _businessPhone,
    key: _businessPhoneKey,
    onSaved: (val) => setState(() => _businessPhone = val),
    isPhone: true,
  ),
),
        const Divider(height: 32),
        // Sección Base de Datos
        const Text('Base de Datos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Crear Backup
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Crear Backup'),
          subtitle: const Text('Copia de seguridad de la base de datos'),
          trailing: _backupLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          enabled: !_backupLoading,
          onTap: () => _createBackup(),
        ),
        // Backups Guardados
        ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text('Backups Guardados (${_backups.length})'),
          subtitle: _backups.isEmpty
              ? const Text('No hay backups')
              : Text('Último: ${_backups.first.dateFormatted}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showBackupsList(),
        ),
        // Importar Backup
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Importar Backup'),
          subtitle: const Text('Restaurar desde un archivo .db'),
          trailing: _backupLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          enabled: !_backupLoading,
          onTap: () => _importBackup(),
        ),
        // Eliminar todos los backups
        if (_backups.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            title: const Text('Eliminar todos los backups', style: TextStyle(color: Colors.red)),
            trailing: _backupLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right, color: Colors.red),
            enabled: !_backupLoading,
            onTap: () => _deleteAllBackups(),
          ),
        const SizedBox(height: 8),
        // Auto-Backup
        SwitchListTile(
          title: const Text('Auto-Backup'),
          subtitle: Text(_autoBackupEnabled
              ? _autoBackupLastRun != null
                  ? '$_autoBackupFrequencyLabel • Último: ${_formatBackupDate(_autoBackupLastRun!)}'
                  : _autoBackupFrequencyLabel
              : 'Desactivado'),
          value: _autoBackupEnabled,
          activeColor: AppColors.accent,
          onChanged: (value) async {
            await _backupService.setAutoBackupConfig(
              enabled: value,
              frequencyHours: _autoBackupFrequencyHours,
            );
            setState(() => _autoBackupEnabled = value);
            _showSnackBar(value ? 'Auto-backup activado' : 'Auto-backup desactivado');
          },
        ),
        if (_autoBackupEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: DropdownButtonFormField<int>(
              value: _autoBackupFrequencyHours,
              decoration: const InputDecoration(
                labelText: 'Frecuencia',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 24, child: Text('Diario')),
                DropdownMenuItem(value: 48, child: Text('Cada 2 días')),
                DropdownMenuItem(value: 168, child: Text('Semanal')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await _backupService.setAutoBackupConfig(
                  enabled: true,
                  frequencyHours: value,
                );
                setState(() => _autoBackupFrequencyHours = value);
                _showSnackBar('Frecuencia actualizada');
              },
            ),
          ),
        // Sección Google Drive
        const Divider(height: 32),
        Row(
          children: [
            Icon(Icons.cloud_outlined, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const Text('Subir backup a Drive'),
          subtitle: const Text('Guarda una copia en tu Google Drive'),
          trailing: _backupLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          enabled: !_backupLoading,
          onTap: () => _uploadBackupToDrive(),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: const Text('Descargar backup de Drive'),
          subtitle: const Text('Restaura desde un archivo en tu Google Drive'),
          trailing: _backupLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          enabled: !_backupLoading,
          onTap: () => _restoreFromDrive(),
        ),
        const Divider(height: 32),
        // Sección Cuenta
                const Text('Cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
  ListTile(
  leading: const Icon(Icons.lock_outline),
  title: const Text('Cambiar Contraseña'),
  subtitle: const Text('Actualiza tu contraseña'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => _showChangePasswordDialog(),
  ),

  // Borrar todo y reiniciar — admin y super_admin
  if (_userRole == 'admin' || _userRole == 'super_admin') ...[
    const Divider(height: 32),
    const Text('Zona Peligrosa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
    const SizedBox(height: 8),
    ListTile(
      leading: const Icon(Icons.science_outlined, color: Colors.orange),
      title: const Text('Generar datos de prueba'),
      subtitle: const Text('Crea 2 meses de ventas, gastos, despachos y rendiciones'),
      trailing: _backupLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chevron_right),
      enabled: !_backupLoading,
      onTap: () => _generateTestData(),
    ),
    const SizedBox(height: 8),
    ListTile(
      leading: const Icon(Icons.replay, color: Colors.orange),
      title: const Text('Reiniciar ciclo (ventas)', style: TextStyle(color: Colors.orange)),
      subtitle: const Text('Borra ventas, pedidos y sesiones. Conserva productos e inventario.'),
      trailing: const Icon(Icons.chevron_right, color: Colors.orange),
      onTap: () => _showReiniciarCicloDialog(),
    ),
    const SizedBox(height: 8),
    ListTile(
      leading: const Icon(Icons.inventory_2_outlined, color: Colors.blue),
      title: const Text('Poner stock de 10000 a todos', style: TextStyle(color: Colors.blue)),
      subtitle: const Text('Resetea el inventario de todos los productos a 10000 unidades'),
      trailing: const Icon(Icons.chevron_right, color: Colors.blue),
      onTap: () => _showSetStockDialog(),
    ),
    const SizedBox(height: 8),
    ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('Borrar todo y reiniciar', style: TextStyle(color: Colors.red)),
      subtitle: const Text('Elimina todos los datos de negocio. Usuarios y licencias se conservan.'),
      trailing: const Icon(Icons.chevron_right, color: Colors.red),
      onTap: () => _showBorrarTodoDialog(),
    ),
  ],
  ], // fin else admin
      ],
            ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cambiar Contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña Actual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la contraseña actual';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa la nueva contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma la nueva contraseña';
                    }
                    if (value != newPasswordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (!isLoading) ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    setDialogState(() => isLoading = true);
                    
                    // Verificar contraseña actual
                    final storage = const FlutterSecureStorage();
                    final userId = await storage.read(key: 'user_id');
                    
                    if (userId == null) {
                      setDialogState(() => isLoading = false);
                      _showSnackBar('Error: No se encontró el usuario', isError: true);
                      return;
                    }
                    
                    final db = AppDatabase.instance;
                    final users = await db.getAllUsers();
                    final currentUser = users.where((u) => u.id == userId).firstOrNull;
                    
                    if (currentUser == null) {
                      setDialogState(() => isLoading = false);
                      _showSnackBar('Error: Usuario no encontrado', isError: true);
                      return;
                    }
                    
                    // Verificar contraseña actual usando el método de la BD
                    final user = await db.login(currentUser.username, currentPasswordController.text);
                    if (user == null) {
                      setDialogState(() => isLoading = false);
                      _showSnackBar('Contraseña actual incorrecta', isError: true);
                      return;
                    }
                    
                    // Actualizar contraseña
                    await db.updatePassword(userId, newPasswordController.text);
                    
                    if (ctx.mounted) {
                      Navigator.pop(ctx, {'success': 'true'});
                    }
                  }
                },
                child: const Text('Cambiar'),
              ),
            ] else ...[
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );

    if (result != null) {
      _showSnackBar('Contraseña cambiada exitosamente');
    }
  }

  Future<void> _showBorrarTodoDialog() async {
    final confirmController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // Usamos StatefulBuilder para que el botón se actualice al escribir
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('⚠️ Borrar todo y reiniciar', style: TextStyle(color: Colors.red)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta acción eliminará TODOS los datos de negocio:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Ventas, órdenes y sesiones'),
                  const Text('• Productos y categorías'),
                  const Text('• Inventario, lotes y movimientos de stock'),
                  const Text('• Gastos y ajustes'),
                  const Text('• Despachos y rendiciones'),
                  const Text('• Configuraciones de la app'),
                  const SizedBox(height: 12),
                  const Text(
                    'Se conservan: usuarios, licencias y planes de licencia.',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Escribí BORRAR para confirmar:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'BORRAR',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}), // actualiza el botón
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: confirmController.text.trim().toUpperCase() == 'BORRAR'
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('BORRAR TODO'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      try {
        final db = AppDatabase.instance;
        await db.clearAllDataAdmin();
        if (mounted) {
          _showSnackBar('Todos los datos fueron eliminados. Usuarios y licencias se conservaron.');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error al borrar datos: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showReiniciarCicloDialog() async {
    final confirmController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('🔄 Reiniciar ciclo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se eliminarán:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Ventas, órdenes y pagos'),
                  const Text('• Sesiones de caja'),
                  const SizedBox(height: 12),
                  const Text(
                    'Se conservan:',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Productos y categorías'),
                  const Text('• Inventario y lotes de stock'),
                  const Text('• Compras y facturas'),
                  const Text('• Gastos'),
                  const Text('• Despachos y rendiciones'),
                  const SizedBox(height: 16),
                  const Text('Escribí REINICIAR para confirmar:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'REINICIAR',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: confirmController.text.trim().toUpperCase() == 'REINICIAR'
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('REINICIAR CICLO'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      try {
        final db = AppDatabase.instance;
        await db.clearSalesData();
        if (mounted) {
          _showSnackBar('Ciclo reiniciado. Productos e inventario conservados.');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error al reiniciar ciclo: $e', isError: true);
        }
      }
    }
  }

  Future<void> _showSetStockDialog() async {
    final confirmController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('📦 Poner stock de 10000 a todos'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Esta acción:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Resetea el stock de TODOS los productos a 10000 unidades'),
                  const Text('• Elimina los lotes existentes y crea uno nuevo de 10000'),
                  const Text('• El costo unitario se mantiene el mismo de cada producto'),
                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ Los lotes anteriores se eliminarán permanentemente.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Escribí STOCK para confirmar:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'STOCK',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: confirmController.text.trim().toUpperCase() == 'STOCK'
                    ? () => Navigator.pop(ctx, true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: const Text('PONER STOCK 10000'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      try {
        setState(() => _backupLoading = true);
        final db = AppDatabase.instance;
        await db.setAllStockTo10000();
        if (mounted) {
          setState(() => _backupLoading = false);
          _showSnackBar('Stock de todos los productos puesto en 10000');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _backupLoading = false);
          _showSnackBar('Error al actualizar stock: $e', isError: true);
        }
      }
    }
  }

  Future<String?> _showPinDialog(String message) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(message),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBusinessField({
    required String title,
    required String value,
    required String key,
    required void Function(String) onSaved,
    bool isPhone = false,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
            prefixIcon: Icon(isPhone ? Icons.phone : Icons.store),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null) {
      final trimmed = result.trim();
      await _storage.setKeyValue(key, trimmed);
      onSaved(trimmed);
      _showSnackBar('Guardado');
    }
  }

  void _showWarehouseActivatedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warehouse, size: 48, color: AppColors.accent),
        title: const Text('Almacén Activado'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu inventario ahora tiene 2 ubicaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('📦 Almacén — donde van las compras nuevas'),
            SizedBox(height: 4),
            Text('🏪 Punto de Venta — donde se vende'),
            SizedBox(height: 12),
            Text('Para empezar a vender:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('1. Comprá mercadería (va al Almacén)'),
            Text('2. Trasladá al PV desde Inventario → Traslados'),
            Text('3. El POS vende solo del PV'),
            SizedBox(height: 12),
            Text(
              'Si ya tenés stock, aparece todo en el Almacén. Hacé un Traslado al PV para vender.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _showResetPinDialog() async {
    // Mostrar diálogo de recuperación con opción de admin
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar PIN'),
        content: const Text('¿Eres admin? wantes resetear el PIN del Modo Kiosco?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Soy Admin'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Resetear PIN - generar nuevo
      final newPin = await _showPinDialog('Ingresa tu nuevo PIN (4 dígitos):');
      if (newPin != null && newPin.length == 4) {
        await _storage.setKeyValue(_kioscoPinKey, newPin);
        _showSnackBar('PIN reseteado correctamente');
      } else {
        _showSnackBar('PIN debe tener 4 dígitos', isError: true);
      }
    }
  }

  // ============================================================
  // BACKUP / RESTORE METHODS
  // ============================================================

  String get _autoBackupFrequencyLabel {
    switch (_autoBackupFrequencyHours) {
      case 24:
        return 'Diario';
      case 48:
        return 'Cada 2 días';
      case 168:
        return 'Semanal';
      default:
        return 'Cada $_autoBackupFrequencyHours horas';
    }
  }

  String _formatBackupDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$min';
  }

  Future<void> _createBackup() async {
    setState(() => _backupLoading = true);
    final path = await _backupService.createBackup();
    if (!mounted) return;
    setState(() => _backupLoading = false);

    if (path == null) {
      _showSnackBar('Error al crear backup', isError: true);
      return;
    }

    // Refresh list
    final backups = await _backupService.listBackups();
    setState(() => _backups = backups);

    // Opciones: Guardar local / Compartir / Cancelar
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup creado'),
        content: const Text('¿Qué querés hacer con el backup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cerrar'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(ctx, 'save'),
            icon: const Icon(Icons.save_alt, size: 18),
            label: const Text('Guardar local'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'share'),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Compartir'),
          ),
        ],
      ),
    );

    if (action == 'save') {
      // Usar share del sistema para guardar (más confiable que FilePicker.saveFile en Android)
      final file = File(path);
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        text: 'Backup base de datos POS',
      );
      if (mounted) {
        _showSnackBar('Elegí "Guardar en archivos" o "Descargas" del share');
      }
    } else if (action == 'share') {
      await _backupService.exportBackup(path);
    }
  }

  Future<void> _importBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Backup'),
        content: const Text(
          'Seleccioná un archivo .db para restaurar.\n\n'
          '⚠️ ATENCIÓN: Esto reemplazará TODA la base de datos actual. '
          'Los datos actuales se perderán. Asegurate de tener un backup antes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _backupLoading = true);
    final success = await _backupService.importBackup();
    if (!mounted) return;
    setState(() => _backupLoading = false);

    if (success) {
      _showSnackBar('Backup importado y restaurado');
      // Navigate to login — the session is invalid after DB replacement
      await _navigateToLoginAfterRestore();
    } else {
      _showSnackBar('Error al importar backup', isError: true);
    }
  }

  Future<void> _uploadBackupToDrive() async {
    setState(() => _backupLoading = true);

    // 1. Crear backup local
    final path = await _backupService.createBackup();
    if (!mounted) return;
    setState(() => _backupLoading = false);

    if (path == null) {
      _showSnackBar('Error al crear backup', isError: true);
      return;
    }

    // 2. Usar share del sistema (incluye Google Drive si está configurado en el celular)
    final file = File(path);
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: 'Backup base de datos POS',
    );
    if (mounted) {
      _showSnackBar('Elegí "Guardar en Drive" u otra opción del share');
    }
  }

  Future<void> _restoreFromDrive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar desde Drive'),
        content: const Text(
          'Elegí un archivo .db desde Google Drive.\n\n'
          '⚠️ ATENCIÓN: Esto reemplazará TODA la base de datos actual. '
          'Los datos actuales se perderán.\n\n'
          'Tip: si tu Google Drive está configurado en el teléfono, '
          'el archivo aparecerá directamente en el selector.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _backupLoading = true);

    // 1. Seleccionar archivo .db desde cualquier lugar (incluido Google Drive)
    final success = await _backupService.importBackup();
    if (!mounted) return;
    setState(() => _backupLoading = false);

    if (success) {
      _showSnackBar('Backup restaurado desde Drive');
      await _navigateToLoginAfterRestore();
    } else {
      _showSnackBar('Error al restaurar', isError: true);
    }
  }

  Future<void> _generateTestData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar datos de prueba'),
        content: const Text(
          'Se van a crear 2 meses de datos ficticios:\n\n'
          '• 20 productos con categorías\n'
          '• ~150 ventas diarias con efectivo y transferencia\n'
          '• ~80 gastos operativos\n'
          '• Despachos a 2 vendedoras con rendiciones\n'
          '• Sesiones de caja con cierre\n\n'
          '⚠️ Los datos actuales NO se borran. Se agregan encima.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _backupLoading = true);

    try {
      final db = AppDatabase.instance;

      // Obtener el admin actual
      final storage = const FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id') ?? 'admin-default';

      final stats = await TestDataGenerator.generate(db, userId);
      if (!mounted) return;
      setState(() => _backupLoading = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('✅ Datos generados'),
          content: Text(
            'Productos: ${stats['products']}\n'
            'Categorías: ${stats['categories']}\n'
            'Vendedoras: ${stats['vendedoras']}\n'
            'Ventas: ${stats['sales']}\n'
            'Gastos: ${stats['expenses']}\n'
            'Despachos: ${stats['despachos']}\n'
            'Período: ${stats['days']} días',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _backupLoading = false);
      _showSnackBar('Error al generar datos: $e', isError: true);
    }
  }

  Future<void> _deleteAllBackups() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar todos los backups'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _backupLoading = true);
    final success = await _backupService.deleteAllBackups();
    if (!mounted) return;
    final backups = await _backupService.listBackups();
    setState(() {
      _backupLoading = false;
      _backups = backups;
    });

    if (success) {
      _showSnackBar('Todos los backups eliminados');
    } else {
      _showSnackBar('Error al eliminar backups', isError: true);
    }
  }

  void _showBackupsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) => Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Backups Guardados',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_backups.length}',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: _backups.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.backup_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('No hay backups guardados'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _backups.length,
                        itemBuilder: (ctx, index) {
                          final backup = _backups[index];
                          return Dismissible(
                            key: ValueKey(backup.path),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (_) => _confirmDeleteBackup(backup),
                            onDismissed: (_) async {
                              await _backupService.deleteBackup(backup.path);
                              final updated = await _backupService.listBackups();
                              setState(() => _backups = updated);
                              setSheetState(() {});
                            },
                            child: ListTile(
                              leading: const Icon(Icons.storage_outlined),
                              title: Text(backup.dateFormatted),
                              subtitle: Text(backup.sizeFormatted),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Export
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined, size: 20),
                                    tooltip: 'Exportar',
                                    onPressed: () async {
                                      await _backupService.exportBackup(backup.path);
                                    },
                                  ),
                                  // Restore
                                  IconButton(
                                    icon: const Icon(Icons.restore_outlined, size: 20),
                                    tooltip: 'Restaurar',
                                    onPressed: () async {
                                      final confirm = await _confirmRestore(backup);
                                      if (confirm == true) {
                                        Navigator.pop(ctx); // Close bottom sheet
                                        setState(() => _backupLoading = true);
                                        final success = await _backupService.restoreBackup(backup.path);
                                        if (!mounted) return;
                                        setState(() => _backupLoading = false);
                                        if (success) {
                                          _showSnackBar('Backup restaurado');
                                          await _navigateToLoginAfterRestore();
                                        } else {
                                          _showSnackBar('Error al restaurar backup', isError: true);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDeleteBackup(BackupInfo backup) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar backup'),
        content: Text('¿Eliminar el backup del ${backup.dateFormatted}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmRestore(BackupInfo backup) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: Text(
          '¿Restaurar el backup del ${backup.dateFormatted}?\n\n'
          '⚠️ Esto reemplazará TODA la base de datos actual. '
          'Se cerrará la sesión y volverás al login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToLoginAfterRestore() async {
    // Clear session data so the redirect logic sends user to login
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'user_id');
    await storage.delete(key: 'user_role');
    await storage.delete(key: 'username');

    // IMPORTANTE: Después de restaurar, los providers de Riverpod
    // siguen apuntando a la instancia vieja (cerrada) de la DB.
    // Navegar a /login NO resuelve esto porque el _authDataSourceProvider
    // ya fue creado con la DB vieja.
    // La solución más confiable: cerrar y reiniciar la app completa.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restaurado. Reiniciando app...'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      // Esperar un momento para que el usuario vea el mensaje
      await Future.delayed(const Duration(seconds: 2));
      exit(0); // Forzar restart limpio — el usuario reabre la app
    }
  }
}