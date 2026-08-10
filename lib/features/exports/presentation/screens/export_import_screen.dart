import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/exports/services/export_service.dart';
import 'package:etecsa/features/exports/services/import_service.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:google_fonts/google_fonts.dart';

/// Provider for a shared ExportService instance.
final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

/// Provider for a shared ImportService instance.
final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService();
});

/// Screen with two tabs: Exportar (JSON export) and Importar (JSON import).
///
/// Serves as an SMS fallback sync mechanism for days when there are many orders
/// and SMS costs (1 CUP per 160 chars) would be too high.
class ExportImportScreen extends ConsumerStatefulWidget {
  const ExportImportScreen({super.key});

  @override
  ConsumerState<ExportImportScreen> createState() =>
      _ExportImportScreenState();
}

class _ExportImportScreenState extends ConsumerState<ExportImportScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Export state
  bool _isExporting = false;
  String? _exportError;
  int _todayOrderCount = 0;
  double _estimatedSmsCost = 0;
  bool _ordersLoaded = false;

  // Import state
  bool _isImporting = false;
  String? _importResultMessage;
  ImportResult? _lastImportResult;

  @override
  void initState() {
    super.initState();
    _loadOrderCount();
  }

  Future<void> _loadOrderCount() async {
    try {
      final orderDS = OrderDatasource(AppDatabase.instance);
      final todayOrders = await orderDS.getTodayOrders();
      if (mounted) {
        setState(() {
          _todayOrderCount = todayOrders.length;
          // Each order = 1 PED + 1 ACK + 1 HEC + 1 ENT = 4 SMS × 1 CUP
          _estimatedSmsCost = todayOrders.length * 4.0;
          _ordersLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportError = 'Error al cargar pedidos: $e';
          _ordersLoaded = true;
        });
      }
    }
  }

  // ── Export ──────────────────────────────────────────────────

  Future<void> _onExport() async {
    setState(() {
      _isExporting = true;
      _exportError = null;
    });

    try {
      final exportService = ref.read(exportServiceProvider);
      final jsonContent = await exportService.exportTodayAsJson();
      await exportService.shareExportFile(jsonContent);
    } catch (e) {
      if (mounted) {
        setState(() => _exportError = 'Error al exportar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ── Import ──────────────────────────────────────────────────

  Future<void> _onSelectFile() async {
    setState(() {
      _isImporting = true;
      _importResultMessage = null;
      _lastImportResult = null;
    });

    try {
      final importService = ref.read(importServiceProvider);
      final result = await importService.pickAndImport();
      if (mounted) {
        if (result != null) {
          setState(() {
            _lastImportResult = result;
            _importResultMessage = _buildImportSummary(result);
          });
        } else {
          setState(() {
            _importResultMessage = null;
            _lastImportResult = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importResultMessage = 'Error al importar: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  String _buildImportSummary(ImportResult result) {
    final parts = <String>[];
    if (result.ordersImported > 0) {
      parts.add('${result.ordersImported} pedido(s) importado(s)');
    }
    if (result.ordersSkipped > 0) {
      parts.add('${result.ordersSkipped} pedido(s) duplicado(s) omitido(s)');
    }
    if (result.clientsImported > 0) {
      parts.add('${result.clientsImported} cliente(s) nuevo(s)');
    }
    if (result.clientsUpdated > 0) {
      parts.add('${result.clientsUpdated} cliente(s) actualizado(s)');
    }
    if (result.errors.isNotEmpty) {
      parts.add('${result.errors.length} error(es)');
    }
    return parts.isEmpty
        ? 'No se encontraron datos para importar.'
        : 'Importacion completada: ${parts.join(', ')}.';
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppColors.forBrightness(Theme.of(context).brightness);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SideMenu(scaffoldKey: _scaffoldKey),
        appBar: AppBar(
          title: const Text('Exportar / Importar'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.upload), text: 'Exportar'),
              Tab(icon: Icon(Icons.download), text: 'Importar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExportTab(colors),
            _buildImportTab(colors),
          ],
        ),
      ),
    );
  }

  // ── Export Tab ──────────────────────────────────────────────

  Widget _buildExportTab(AppColorsTheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'Exportacion JSON',
            description:
                'Exporta tus pedidos y clientes del dia de hoy como un archivo JSON. '
                'Compartilo con otros dispositivos via WhatsApp, Telegram, o guardalo '
                'como respaldo.',
          ),
          const SizedBox(height: 20),

          // Today's order stats
          _buildStatCard(
            title: 'Pedidos hoy',
            value: _ordersLoaded ? '$_todayOrderCount' : '...',
            icon: Icons.receipt_long,
            color: AppColors.accent,
          ),
          const SizedBox(height: 12),

          // SMS cost comparison
          _buildStatCard(
            title: 'Costo estimado en SMS',
            value: _ordersLoaded ? '$_estimatedSmsCost CUP' : '...',
            subtitle:
                '$_todayOrderCount pedidos × 4 SMS (PED+ACK+HEC+ENT) × 1 CUP',
            icon: Icons.monetization_on,
            color: colors.warning,
          ),
          const SizedBox(height: 20),

          // Export button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isExporting || _todayOrderCount == 0
                  ? null
                  : _onExport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_upload, size: 22),
              label: Text(
                _isExporting
                    ? 'Exportando...'
                    : 'Exportar JSON y compartir',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Savings summary
          if (_ordersLoaded && _todayOrderCount > 0)
            _buildSavingsCard(colors),

          // Error
          if (_exportError != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _exportError!,
                        style: TextStyle(color: colors.danger, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(AppColorsTheme colors) {
    final savings = _estimatedSmsCost;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.success,
            colors.success.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.savings, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Ahorraste $savings CUP en SMS usando JSON',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Import Tab ──────────────────────────────────────────────

  Widget _buildImportTab(AppColorsTheme colors) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          _buildInfoCard(
            icon: Icons.info_outline,
            title: 'Importacion JSON',
            description:
                'Selecciona un archivo .json exportado desde otro dispositivo '
                'con Hamburguesa Express. Los pedidos nuevos se agregaran y '
                'los clientes existentes se actualizaran.',
          ),
          const SizedBox(height: 20),

          // Select file button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isImporting ? null : _onSelectFile,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.folder_open, size: 22),
              label: Text(
                _isImporting
                    ? 'Importando...'
                    : 'Seleccionar archivo JSON',
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Result summary
          if (_importResultMessage != null) ...[
            _buildResultCard(
              result: _lastImportResult,
              message: _importResultMessage!,
              colors: colors,
            ),
          ],

          // Preview when no result yet
          if (_importResultMessage == null && !_isImporting)
            _buildImportPreview(colors),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required ImportResult? result,
    required String message,
    required AppColorsTheme colors,
  }) {
    final hasErrors = result != null && result.errors.isNotEmpty;
    final hasData = result != null && (result.totalOrders > 0 || result.totalClients > 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasErrors
            ? colors.danger.withValues(alpha: 0.1)
            : colors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasErrors ? colors.danger : colors.success,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.warning_amber_rounded : Icons.check_circle,
                color: hasErrors ? colors.danger : colors.success,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: hasErrors ? colors.danger : colors.success,
                  ),
                ),
              ),
            ],
          ),
          if (result != null && result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Errores:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...result.errors.map(
              (e) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $e',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          if (hasData) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _onSelectFile,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Importar otro archivo'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportPreview(AppColorsTheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona un archivo .json para importar',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Los archivos exportados tienen el formato\nhamburguesa_export_*.json',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forBrightness(Theme.of(context).brightness).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
