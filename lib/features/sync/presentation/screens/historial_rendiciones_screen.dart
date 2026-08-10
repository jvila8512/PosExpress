import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class HistorialRendicionesScreen extends StatefulWidget {
  const HistorialRendicionesScreen({super.key});

  @override
  State<HistorialRendicionesScreen> createState() => _HistorialRendicionesScreenState();
}

class _HistorialRendicionesScreenState extends State<HistorialRendicionesScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<RendicionesProcesada> _rendiciones = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 20;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadRendiciones();
  }

  Future<void> _loadRendiciones({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _rendiciones = [];
        _currentPage = 0;
        _hasMore = true;
      });
    }

    final db = AppDatabase.instance;
    final offset = reset ? 0 : _currentPage * _pageSize;

    final rendiciones = await db.getRendicionesPaginated(
      limit: _pageSize,
      offset: offset,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final count = await db.countRendiciones(fromDate: _fromDate, toDate: _toDate);

    if (mounted) {
      setState(() {
        if (reset) {
          _rendiciones = rendiciones;
          _loading = false;
        } else {
          _rendiciones.addAll(rendiciones);
          _loadingMore = false;
        }
        _totalCount = count;
        _hasMore = rendiciones.length == _pageSize;
        _currentPage = reset ? 1 : _currentPage + 1;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadRendiciones(reset: false);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      locale: const Locale('es'),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      await _loadRendiciones();
    }
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadRendiciones();
  }

  Future<void> _exportExcel() async {
    try {
      final filePath = await ExportService.instance.exportRendicionesExcel(
        rendiciones: _rendiciones,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Rendiciones');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportPDF() async {
    try {
      final filePath = await ExportService.instance.exportRendicionesPdf(
        rendiciones: _rendiciones,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Rendiciones');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _undoRendicion(RendicionesProcesada rendicion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deshacer Rendición'),
        content: Text(
          '¿Estás seguro de deshacer la rendición de ${rendicion.vendedoraNombre} '
          'del ${DateFormat('dd/MM/yyyy').format(rendicion.fechaRendicion)}?\n\n'
          'Se eliminará la sesión, ventas y órdenes creadas automáticamente.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deshacer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = AppDatabase.instance;
      await db.undoRendicion(rendicion.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendición deshecha'), backgroundColor: Colors.green),
        );
      }
      await _loadRendiciones();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetail(RendicionesProcesada rendicion) {
    Map<String, dynamic>? raw;
    try {
      raw = jsonDecode(rendicion.rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final ventas = raw?['ventas'] as List<dynamic>? ?? [];
    final stockRestante = raw?['stockRestante'] as List<dynamic>? ?? [];
    final transferencias = raw?['transferencias'] as List<dynamic>? ?? [];

    final hasVentas = ventas.isNotEmpty;
    final hasStock = stockRestante.isNotEmpty;
    final hasTransfers = transferencias.isNotEmpty;
    final tabCount = [hasVentas, hasStock, hasTransfers].where((b) => b).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rendición de ${rendicion.vendedoraNombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(rendicion.fechaRendicion), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      Navigator.pop(ctx);
                      try {
                        String filePath;
                        if (val == 'excel') {
                          filePath = await ExportService.instance.exportSingleRendicionExcel(rendicion);
                        } else {
                          filePath = await ExportService.instance.exportSingleRendicionPdf(rendicion);
                        }
                        if (mounted) {
                          ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Rendición ${rendicion.vendedoraNombre}');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'excel', child: Text('Exportar Excel')),
                      const PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
                    ],
                    icon: const Icon(Icons.file_download),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniCard('Efectivo', '\$${rendicion.totalEfectivo.toStringAsFixed(0)}', Icons.money),
                  const SizedBox(width: 8),
                  _miniCard('Transfer.', '\$${rendicion.totalTransferencia.toStringAsFixed(0)}', Icons.account_balance),
                  const SizedBox(width: 8),
                  _miniCard('Total', '\$${rendicion.totalGeneral.toStringAsFixed(0)}', Icons.attach_money),
                ],
              ),
              if (rendicion.sessionId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.point_of_sale, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Caja: ${rendicion.sessionId}', style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                    ],
                  ),
                ),
            ],
          ),
        ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: tabCount > 0 ? tabCount : 1,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        if (hasVentas) Tab(text: 'Ventas (${ventas.length})'),
                        if (hasTransfers) Tab(text: 'Transf. (${transferencias.length})'),
                        if (hasStock) Tab(text: 'Stock (${stockRestante.length})'),
                        if (!hasVentas && !hasTransfers && !hasStock) const Tab(text: 'Sin datos'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          if (hasVentas) _ventasList(ventas),
                          if (hasTransfers) _transferenciasList(transferencias),
                          if (hasStock) _stockList(stockRestante),
                          if (!hasVentas && !hasTransfers && !hasStock) const Center(child: Text('Sin datos')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ventasList(List<dynamic> ventas) {
    return ListView.builder(
      itemCount: ventas.length,
      itemBuilder: (_, i) {
        final v = ventas[i] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(v['productoNombre'] as String? ?? ''),
          subtitle: Text('${v['metodoPago'] ?? ''}'),
          trailing: Text('${v['cantidad']} × \$${(v['precioUnitario'] as num?)?.toStringAsFixed(0) ?? '0'}'),
        );
      },
    );
  }

  Widget _transferenciasList(List<dynamic> transferencias) {
    return ListView.builder(
      itemCount: transferencias.length,
      itemBuilder: (_, i) {
        final t = transferencias[i] as Map<String, dynamic>;
        final amount = (t['amount'] as num?)?.toDouble() ?? 0;
        final txId = t['transactionId'] as String? ?? '';
        final phone = t['clientPhone'] as String? ?? '';
        final name = t['clientName'] as String? ?? '';
        final bank = t['bank'] as String? ?? '';
        return ListTile(
          dense: true,
          leading: Icon(Icons.swap_horiz, color: Colors.purple.shade400, size: 20),
          title: Text(
            name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'Sin datos'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(
            '${txId.isNotEmpty ? txId : "Sin TX ID"}${bank.isNotEmpty ? " • $bank" : ""}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 12)),
        );
      },
    );
  }

  Widget _stockList(List<dynamic> stock) {
    return ListView.builder(
      itemCount: stock.length,
      itemBuilder: (_, i) {
        final s = stock[i] as Map<String, dynamic>;
        return ListTile(
          dense: true,
          title: Text(s['productoNombre'] as String? ?? ''),
          trailing: Text('${s['cantidad']}'),
        );
      },
    );
  }

  Widget _miniCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _fromDate != null || _toDate != null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Historial Rendiciones'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: filtered ? AppColors.accent : null),
            onPressed: _pickDateRange,
            tooltip: 'Filtrar por fecha',
          ),
          if (_rendiciones.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'excel') _exportExcel();
                if (val == 'pdf') _exportPDF();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'excel', child: Text('Exportar Excel')),
                const PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (filtered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: AppColors.accent.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd/MM/yy').format(_fromDate!)} - ${DateFormat('dd/MM/yy').format(_toDate!)}',
                            style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _clearFilter,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Quitar', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '$_totalCount rendición${_totalCount != 1 ? 'es' : ''}${filtered ? ' en rango' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _rendiciones.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('No hay rendiciones procesadas', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent &&
                                _hasMore &&
                                !_loadingMore) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: RefreshIndicator(
                            onRefresh: () => _loadRendiciones(),
                            child: ListView.builder(
                              itemCount: _rendiciones.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _rendiciones.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
      final r = _rendiciones[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: InkWell(
            onTap: () => _showDetail(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                    child: const Icon(Icons.assignment_return, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.vendedoraNombre,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${r.totalItems} items • ${DateFormat('dd/MM/yyyy HH:mm').format(r.fechaRendicion)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${r.totalGeneral.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        'E: \$${r.totalEfectivo.toStringAsFixed(0)}  T: \$${r.totalTransferencia.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.undo, size: 20),
                    color: Colors.red.shade400,
                    tooltip: 'Deshacer rendición',
                    onPressed: () => _undoRendicion(r),
                  ),
                ],
              ),
            ),
          ),
        );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
