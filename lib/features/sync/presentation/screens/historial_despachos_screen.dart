import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class HistorialDespachosScreen extends StatefulWidget {
  const HistorialDespachosScreen({super.key});

  @override
  State<HistorialDespachosScreen> createState() => _HistorialDespachosScreenState();
}

class _HistorialDespachosScreenState extends State<HistorialDespachosScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<DespachosEnviado> _despachos = [];
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
    _loadDespachos();
  }

  Future<void> _loadDespachos({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _despachos = [];
        _currentPage = 0;
        _hasMore = true;
      });
    }

    final db = AppDatabase.instance;
    final offset = reset ? 0 : _currentPage * _pageSize;

    final despachos = await db.getDespachosPaginated(
      limit: _pageSize,
      offset: offset,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final count = await db.countDespachos(fromDate: _fromDate, toDate: _toDate);

    if (mounted) {
      setState(() {
        if (reset) {
          _despachos = despachos;
          _loading = false;
        } else {
          _despachos.addAll(despachos);
          _loadingMore = false;
        }
        _totalCount = count;
        _hasMore = despachos.length == _pageSize;
        _currentPage = reset ? 1 : _currentPage + 1;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadDespachos(reset: false);
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
      await _loadDespachos();
    }
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadDespachos();
  }

  Future<void> _exportExcel() async {
    try {
      final filePath = await ExportService.instance.exportDespachosExcel(
        despachos: _despachos,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Despachos');
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
      final filePath = await ExportService.instance.exportDespachosPdf(
        despachos: _despachos,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Despachos');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetail(DespachosEnviado despacho) {
    Map<String, dynamic>? raw;
    try {
      raw = jsonDecode(despacho.rawJson) as Map<String, dynamic>;
    } catch (_) {}

    final productos = raw?['productos'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Despacho para ${despacho.vendedoraNombre}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(DateFormat('dd/MM/yyyy HH:mm').format(despacho.fechaEnvio), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('${despacho.productosCount} productos', style: const TextStyle(fontSize: 13, color: AppColors.accent)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      Navigator.pop(ctx);
                      try {
                        String filePath;
                        if (val == 'excel') {
                          filePath = await ExportService.instance.exportSingleDespachoExcel(despacho);
                        } else {
                          filePath = await ExportService.instance.exportSingleDespachoPdf(despacho);
                        }
                        if (mounted) {
                          ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Despacho ${despacho.vendedoraNombre}');
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
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: productos.length,
                itemBuilder: (_, i) {
                  final p = productos[i] as Map<String, dynamic>;
                  return ListTile(
                    dense: true,
                    title: Text(p['nombre'] as String? ?? ''),
                    subtitle: Text('Costo: \$${(p['precioCosto'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                    trailing: Text('${p['cantidad']} x \$${(p['precioVenta'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                  );
                },
              ),
            ),
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
        title: const Text('Historial Despachos'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(
            icon: Icon(Icons.date_range, color: filtered ? AppColors.accent : null),
            onPressed: _pickDateRange,
            tooltip: 'Filtrar por fecha',
          ),
          if (_despachos.isNotEmpty)
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
                        '$_totalCount despacho${_totalCount != 1 ? 's' : ''}${filtered ? ' en rango' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _despachos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('No hay despachos enviados', style: TextStyle(fontSize: 16)),
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
                            onRefresh: () => _loadDespachos(),
                            child: ListView.builder(
                              itemCount: _despachos.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _despachos.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }
                                final d = _despachos[index];
                                final esReposicion = d.tipo == 'reposicion';
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: esReposicion
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : AppColors.accent.withValues(alpha: 0.1),
                                      child: Icon(
                                        esReposicion ? Icons.add_circle : Icons.send,
                                        color: esReposicion ? Colors.orange : AppColors.accent,
                                        size: 20,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(child: Text(d.vendedoraNombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: esReposicion ? Colors.orange.shade50 : AppColors.accent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: esReposicion ? Colors.orange.shade200 : AppColors.accent.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            esReposicion ? 'Reposición' : 'Despacho',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: esReposicion ? Colors.orange.shade700 : AppColors.accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(d.fechaEnvio)),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('${d.productosCount} prod.', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
                                      ],
                                    ),
                                    onTap: () => _showDetail(d),
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
