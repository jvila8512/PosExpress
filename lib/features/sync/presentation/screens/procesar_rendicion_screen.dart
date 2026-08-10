import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:etecsa/core/services/sync_service.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProcesarRendicionScreen extends StatefulWidget {
  const ProcesarRendicionScreen({super.key});

  @override
  State<ProcesarRendicionScreen> createState() => _ProcesarRendicionScreenState();
}

class _ProcesarRendicionScreenState extends State<ProcesarRendicionScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, dynamic>? _rendicion;
  bool _loading = false;
  bool _applied = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _loading = true);
      try {
        final data = await SyncService.instance.importRendicion(result.files.single.path!);
        setState(() {
          _rendicion = data;
          _loading = false;
          _applied = false;
        });
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _applyRendicion() async {
    if (_rendicion == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
        title: const Text('¿Procesar rendición?'),
        content: Text(
          'Se creará una sesión de caja con las ventas de ${_rendicion!['vendedoraNombre'] ?? 'la vendedora'}. '
          'Esta acción no se puede deshacer desde aquí.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('PROCESAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final storage = const FlutterSecureStorage();
      final adminId = await storage.read(key: 'user_id') ?? 'admin';

      await SyncService.instance.applyRendicion(_rendicion!, adminId);
      setState(() {
        _loading = false;
        _applied = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Rendición procesada'),
                TextSpan(text: '\nCaja creada y cerrada automáticamente', style: TextStyle(fontSize: 12)),
              ]),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Agrupar ventas por producto para mostrar cards consistentes
  List<Map<String, dynamic>> _agruparVentasPorProducto(List<dynamic> ventas) {
    final agrupado = LinkedHashMap<String, Map<String, dynamic>>();
    for (final v in ventas) {
      final key = v['productoId'] as String? ?? v['productoNombre'] as String? ?? '';
      if (!agrupado.containsKey(key)) {
        agrupado[key] = {
          'productoId': key,
          'productoNombre': v['productoNombre'] as String? ?? '',
          'cantidad': 0.0,
          'total': 0.0,
        };
      }
      agrupado[key]!['cantidad'] = (agrupado[key]!['cantidad'] as double) + (v['cantidad'] as num? ?? 0).toDouble();
      agrupado[key]!['total'] = (agrupado[key]!['total'] as double) + (v['total'] as num? ?? 0).toDouble();
    }
    return agrupado.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final ventas = _rendicion?['ventas'] as List<dynamic>? ?? [];
    final devoluciones = _rendicion?['devoluciones'] as List<dynamic>? ?? [];
    final stockRestante = _rendicion?['stockRestante'] as List<dynamic>? ?? [];
    final transferencias = _rendicion?['transferencias'] as List<dynamic>? ?? [];
    final resumen = _rendicion?['resumen'] as Map<String, dynamic>? ?? {};

    final ventasAgrupadas = _agruparVentasPorProducto(ventas);
    final devolucionesAgrupadas = _agruparVentasPorProducto(devoluciones);

    // Calcular netos para la UI (resumen JSON tiene brutos para applyRendicion)
    double devEfectivo = 0;
    double devTransferencia = 0;
    for (final d in devoluciones) {
      final pm = (d['metodoPago'] as String? ?? 'efectivo').toLowerCase();
      final total = (d['total'] as num?)?.toDouble() ?? 0;
      if (pm == 'transferencia' || pm == 'transfer') {
        devTransferencia += total.abs();
      } else {
        devEfectivo += total.abs();
      }
    }
    final netEfectivo = ((resumen['totalEfectivo'] as num?)?.toDouble() ?? 0) - devEfectivo;
    final netTransferencia = ((resumen['totalTransferencia'] as num?)?.toDouble() ?? 0) - devTransferencia;
    final netGeneral = netEfectivo + netTransferencia;

    // Fallback: ventas por transferencia SOLO si no hay datos de pago en transferencias
    final salesByTransfer = transferencias.isEmpty
        ? ventas.where((v) => (v['metodoPago'] as String? ?? '').toLowerCase().contains('transferencia')).toList()
        : <Map<String, dynamic>>[];
    final totalTransferItems = transferencias.isNotEmpty ? transferencias.length : salesByTransfer.length;

    final hasVentas = ventasAgrupadas.isNotEmpty;
    final hasDevoluciones = devolucionesAgrupadas.isNotEmpty;
    final hasStock = stockRestante.isNotEmpty;
    final hasTransfers = transferencias.isNotEmpty || salesByTransfer.isNotEmpty;
    final tabCount = [hasVentas, hasDevoluciones, hasStock, hasTransfers].where((b) => b).length;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Procesar Rendición'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _rendicion == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_download, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('Seleccioná el archivo de rendición', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  FloatingActionButton.extended(
                    onPressed: _pickFile,
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.file_open),
                    label: const Text('IMPORTAR JSON'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Header resumen ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppColors.accent.withValues(alpha: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Rendición de: ${_rendicion!['vendedoraNombre'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Fecha: ${_formatFecha(_rendicion!['fecha'] as String?)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!_applied)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _rendicion = null;
                                  _applied = false;
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Cancelar'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSummaryCard('Efectivo', '\$${netEfectivo.toStringAsFixed(0)}', Icons.money),
                          const SizedBox(width: 8),
                          _buildSummaryCard('Transfer.', '\$${netTransferencia.toStringAsFixed(0)}', Icons.account_balance),
                          const SizedBox(width: 8),
                          _buildSummaryCard('Total', '\$${netGeneral.toStringAsFixed(0)}', Icons.attach_money),
                        ],
                      ),
                      // Alerta de transferencias
                      if (hasTransfers) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$totalTransferItems transferencia${totalTransferItems != 1 ? 's' : ''} - revisá los datos en la solapa "Transf."',
                                  style: TextStyle(fontSize: 12, color: Colors.purple.shade700, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Tabs ──
                Expanded(
                  child: DefaultTabController(
                    length: tabCount > 0 ? tabCount : 1,
                    child: Column(
                      children: [
                        TabBar(
                          tabs: [
                            if (hasVentas) Tab(text: 'Ventas (${ventasAgrupadas.length})'),
                            if (hasDevoluciones) Tab(text: 'Devoluc. (${devolucionesAgrupadas.length})'),
                            if (hasTransfers) Tab(text: 'Transf. ($totalTransferItems)'),
                            if (hasStock) Tab(text: 'Stock (${stockRestante.length})'),
                            if (!hasVentas && !hasDevoluciones && !hasTransfers && !hasStock) const Tab(text: 'Sin datos'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // ── Tab Ventas (cards) ──
                              if (hasVentas)
                                ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  itemCount: ventasAgrupadas.length,
                                  itemBuilder: (context, index) {
                                    final v = ventasAgrupadas[index];
                                    return _buildVentaProductoCard(v);
                                  },
                                ),

                              // ── Tab Devoluciones (cards) ──
                              if (hasDevoluciones)
                                ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  itemCount: devolucionesAgrupadas.length,
                                  itemBuilder: (context, index) => _buildDevolucionCard(devolucionesAgrupadas[index]),
                                ),

                              // ── Tab Transferencias (cards) ──
                              if (hasTransfers)
                                transferencias.isNotEmpty
                                  ? ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                      itemCount: transferencias.length,
                                      itemBuilder: (context, index) {
                                        final t = transferencias[index] as Map<String, dynamic>;
                                        return _buildTransferenciaCard(t);
                                      },
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                      itemCount: salesByTransfer.length,
                                      itemBuilder: (context, index) {
                                        final v = salesByTransfer[index];
                                        final total = (v['total'] as num?)?.toDouble() ?? 0;
                                        return Card(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              children: [
                                                Icon(Icons.swap_horiz, color: Colors.purple.shade400, size: 20),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(v['productoNombre'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                      Text('${_formatFecha(v['fecha'] as String?)} - Sin datos de pago',
                                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                                    ],
                                                  ),
                                                ),
                                                Text('\$${total.toStringAsFixed(0)}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                              // ── Tab Stock (cards) ──
                              if (hasStock)
                                ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                  itemCount: stockRestante.length,
                                  itemBuilder: (context, index) {
                                    final s = stockRestante[index] as Map<String, dynamic>;
                                    return _buildStockCard(s);
                                  },
                                ),

                              if (!hasVentas && !hasDevoluciones && !hasTransfers && !hasStock) const Center(child: Text('Sin datos')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bottom buttons ──
                if (!_applied)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: FloatingActionButton.extended(
                        onPressed: _applyRendicion,
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.check),
                        label: const Text('PROCESAR RENDICIÓN'),
                      ),
                    ),
                  )
                else
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Column(
                                  children: [
                                    Text('Rendición procesada', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    Text('Caja creada', style: TextStyle(color: Colors.green, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          FloatingActionButton.extended(
                            onPressed: () {
                              setState(() {
                                _rendicion = null;
                                _applied = false;
                              });
                            },
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            icon: const Icon(Icons.file_open),
                            label: const Text('IMPORTAR OTRA RENDICIÓN'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  // ── Summary card (header) ──
  Widget _buildSummaryCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ── Venta por Producto card ──
  Widget _buildVentaProductoCard(Map<String, dynamic> v) {
    final nombre = v['productoNombre'] as String;
    final cantidad = (v['cantidad'] as double).toInt();
    final total = v['total'] as double;

    // Buscar stock restante
    final stockList = _rendicion?['stockRestante'] as List<dynamic>? ?? [];
    final stockItem = stockList.firstWhere(
      (s) => (s as Map<String, dynamic>)['productoId'] == v['productoId'],
      orElse: () => null,
    );
    final stockRestante = stockItem != null ? (stockItem as Map<String, dynamic>)['cantidad'] as double : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Badge cantidad
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
              ),
            ),
            const SizedBox(width: 12),
            // Nombre + stock
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.inventory_2, size: 12, color: Colors.teal.shade600),
                      const SizedBox(width: 3),
                      Text('Stock: ${stockRestante.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: Colors.teal.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            // Total
            Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // ── Stock card ──
  Widget _buildStockCard(Map<String, dynamic> s) {
    final nombre = s['productoNombre'] as String;
    final cantidad = s['cantidad'] as double;

    Color stockColor;
    if (cantidad <= 0) {
      stockColor = Colors.red;
    } else if (cantidad <= 5) {
      stockColor = Colors.orange;
    } else {
      stockColor = Colors.teal;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.inventory_2, size: 18, color: stockColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(nombre, style: const TextStyle(fontSize: 13)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: stockColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${cantidad.toStringAsFixed(0)} uds',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: stockColor)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Transferencia card ──
  Widget _buildTransferenciaCard(Map<String, dynamic> t) {
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    final name = t['clientName'] as String? ?? '';
    final phone = t['clientPhone'] as String? ?? '';
    final bank = (t['bank'] as String? ?? '').trim();
    final bankDisplay = bank.isEmpty ? 'Bancaria' : bank;
    final txId = t['transactionId'] as String? ?? '';
    final ci = t['clientCI'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.swap_horiz, color: Colors.purple.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'Transferencia'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                Text('\$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 15)),
              ],
            ),
            if (phone.isNotEmpty || bankDisplay.isNotEmpty || txId.isNotEmpty || ci.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  if (phone.isNotEmpty) _transferChip(Icons.phone, phone),
                  _transferChip(Icons.account_balance, bankDisplay),
                  if (txId.isNotEmpty) _transferChip(Icons.receipt, txId),
                  if (ci.isNotEmpty) _transferChip(Icons.badge, 'CI: $ci'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _transferChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.purple.shade300),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDevolucionCard(Map<String, dynamic> v) {
    final nombre = v['productoNombre'] as String? ?? '';
    final cantidad = ((v['cantidad'] as num?)?.toDouble() ?? 0).toInt();
    final total = (v['total'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.undo, size: 20, color: Colors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Devuelto: $cantidad uds',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Text('\$${total.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
