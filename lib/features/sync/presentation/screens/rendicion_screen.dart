import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/sync_service.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RendicionScreen extends StatefulWidget {
  const RendicionScreen({super.key});

  @override
  State<RendicionScreen> createState() => _RendicionScreenState();
}

class _RendicionScreenState extends State<RendicionScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = false;
  bool _exporting = false;
  Map<String, dynamic>? _rendicion;

  String _formatFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  /// Extraer orderId del saleId del POS.
  String? _extractOrderId(String saleId) {
    if (saleId.startsWith('SR')) return saleId.substring(2);
    if (saleId.startsWith('S')) return saleId.substring(1);
    return null;
  }

  /// Selector de sesión/caja para elegir de cuál generar la rendición
  Future<Session?> _showSessionPicker() async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: 'user_id') ?? '';
    final db = AppDatabase.instance;
    final sessions = await db.getSessionsByUser(userId);

    if (!mounted || sessions.isEmpty) return null;

    return showDialog<Session>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Elegí la caja'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final s = sessions[index];
              final isOpen = s.status == 'open';
              final dateStr = DateFormat('dd/MM/yyyy').format(s.openingTime);
              final timeStr = DateFormat('HH:mm').format(s.openingTime);
              return ListTile(
                leading: Icon(
                  isOpen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isOpen ? Colors.green : Colors.grey,
                  size: 20,
                ),
                title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Apertura: $timeStr - \$${s.openingCash.toStringAsFixed(0)}'
                  '${isOpen ? ' (abierta)' : ' (cerrada)'}',
                  style: TextStyle(fontSize: 12, color: isOpen ? Colors.green.shade700 : Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(ctx, s),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Genera la preview — ahora recibe la sesión elegida por el vendedor
  Future<void> _generatePreview({Session? selectedSession}) async {
    // Si no se pasó sesión, mostrar selector
    if (selectedSession == null) {
      final chosen = await _showSessionPicker();
      if (chosen == null) return; // usuario canceló
      selectedSession = chosen;
    }

    setState(() => _loading = true);

    try {
      final storage = const FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id') ?? '';
      final userName = await storage.read(key: 'user_name') ?? 'Vendedora';

      final db = AppDatabase.instance;
      final session = selectedSession;

      // Usar fechas de la sesión elegida
      final sessionStart = session.openingTime;
      final sessionEnd = session.closingTime ?? DateTime.now();

      final sales = await db.getSalesInRangeIncludingReturns(
        sessionStart,
        sessionEnd,
      );

      final ventas = <Map<String, dynamic>>[];
      final devoluciones = <Map<String, dynamic>>[];
      // Totales brutos para el JSON (sin restar devoluciones)
      double grossEfectivo = 0;
      double grossTransferencia = 0;
      int totalItems = 0;

      // Usar openingCash de la sesión elegida
      final openingCash = session.openingCash;

      for (final sale in sales) {
        final items = await db.getSaleItemsBySaleId(sale.id);
        final isDevolucion = sale.totalAmount < 0;
        for (final item in items) {
          final product = await db.getProductById(item.productId);
          String productName = product?.name ?? '';
          if (productName.isEmpty) {
            final orderItemName = await db.getOrderItemNameByProductId(item.productId);
            productName = orderItemName ?? item.productId;
          }

          final entry = {
            'saleId': sale.id,
            'fecha': sale.saleDate.toIso8601String(),
            'productoId': item.productId,
            'productoNombre': productName,
            'cantidad': item.quantity,
            'precioUnitario': item.unitPrice,
            'costoUnitario': item.costPriceAtSale,
            'total': item.subtotal,
            'metodoPago': sale.paymentMethod,
          };

          if (isDevolucion) {
            devoluciones.add(entry);
          } else {
            ventas.add(entry);
            totalItems += item.quantity.ceil();
          }
        }

        // Sumar al resumen: siempre sumar (bruto)
        // Las devoluciones se processan aparte en applyRendicion con venta negativa
        if (sale.paymentMethod.toLowerCase() == 'mixto') {
          // Pago mixto: buscar desglose real en OrderPayments
          final orderId = _extractOrderId(sale.id);
          if (orderId != null) {
            final payments = await db.getOrderPayments(orderId);
            for (final payment in payments) {
              if (payment.paymentMethod == 'efectivo') {
                final amount = payment.amount - payment.changeGiven;
                grossEfectivo += amount.abs();
              } else if (payment.paymentMethod == 'transferencia') {
                grossTransferencia += payment.amount.abs();
              }
            }
          } else {
            final half = sale.totalAmount.abs() * 0.5;
            grossEfectivo += half;
            grossTransferencia += half;
          }
        } else if (sale.paymentMethod == 'efectivo' || sale.paymentMethod == 'cash') {
          grossEfectivo += sale.totalAmount.abs();
        } else if (sale.paymentMethod == 'transferencia' || sale.paymentMethod == 'transfer') {
          grossTransferencia += sale.totalAmount.abs();
        } else {
          grossEfectivo += sale.totalAmount.abs();
        }
      }

      // Transferencias: solo órdenes de HOY
      final transferencias = <Map<String, dynamic>>[];
      final allOrders = await db.getAllPaidOrders(limit: 9999, offset: 0);
      for (final order in allOrders) {
        // Solo órdenes de esta sesión
        if (order.paidAt == null || order.paidAt!.isBefore(sessionStart)) continue;
        final payments = await db.getOrderPayments(order.id);
        for (final payment in payments) {
          if (payment.paymentMethod == 'transferencia') {
            transferencias.add({
              'orderId': order.id,
              'amount': payment.amount,
              'transactionId': payment.transactionId,
              'purchaseId': payment.purchaseId,
              'clientName': payment.clientName,
              'clientPhone': payment.clientPhone,
              'clientCI': payment.clientCI,
              'transferDate': payment.transferDate,
              'bank': payment.bank,
              'reference': payment.reference,
            });
          }
        }
      }

      final stockRestante = <Map<String, dynamic>>[];
      final products = await db.getAllProducts();
      for (final p in products) {
        final lots = await db.getActiveLots(p.id);
        double stock = 0;
        for (final lot in lots) {
          stock += lot.remainingQuantity;
        }
        if (stock > 0) {
          stockRestante.add({
            'productoId': p.id,
            'productoNombre': p.name,
            'cantidad': stock,
          });
        }
      }

      final now = DateTime.now();
      final rendicion = {
        'tipo': 'rendicion',
        'version': 3,
        'fecha': now.toIso8601String(),
        'vendedoraId': userId,
        'vendedoraNombre': userName,
        'openingCash': openingCash,
        'ventas': ventas,
        'devoluciones': devoluciones,
        'transferencias': transferencias,
        'stockRestante': stockRestante,
        'resumen': {
          'totalEfectivo': grossEfectivo,
          'totalTransferencia': grossTransferencia,
          'totalGeneral': grossEfectivo + grossTransferencia,
          'totalItems': totalItems,
        },
      };

      // Guardar localmente en Mis Rendiciones (reescribir si ya existe del mismo día)
      try {
        final existingRendiciones = await db.getAllRendicionesProcesadas();
        for (final existing in existingRendiciones) {
          if (existing.vendedoraId == userId &&
              existing.fechaRendicion.year == now.year &&
              existing.fechaRendicion.month == now.month &&
              existing.fechaRendicion.day == now.day) {
            await (db.delete(db.rendicionesProcesadas)
              ..where((r) => r.id.equals(existing.id))).go();
          }
        }
        await db.addRendicionProcesada(
          id: 'VEND-${now.millisecondsSinceEpoch}',
          vendedoraId: userId,
          vendedoraNombre: userName,
          fechaRendicion: now,
          totalEfectivo: grossEfectivo,
          totalTransferencia: grossTransferencia,
          totalGeneral: grossEfectivo + grossTransferencia,
          totalItems: totalItems,
          rawJson: const JsonEncoder.withIndent(' ').convert(rendicion),
          sessionId: null,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _rendicion = rendicion;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportRendicion() async {
    if (_rendicion == null || _exporting) return;

    final vendedoraNombre = _rendicion!['vendedoraNombre'] as String;
    setState(() => _exporting = true);
    try {
      final filePath = await SyncService.instance.exportRendicion(
        vendedoraId: _rendicion!['vendedoraId'],
        vendedoraNombre: vendedoraNombre,
        despachoFecha: '',
      );
      if (mounted) {
        ExportOptionsDialog.show(
          context,
          filePath: filePath,
          shareText: 'Rendición de $vendedoraNombre',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar datos'),
        content: const Text(
          'Esto eliminará productos, ventas e inventario. '
          'Tu historial de despachos y rendiciones se conservará. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('LIMPIAR'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await SyncService.instance.clearAllData();
        if (mounted) {
          setState(() {
            _loading = false;
            _rendicion = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos limpiados'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  WIDGETS — EXACTAMENTE IGUALES A procesar_rendicion_screen.dart
  // ══════════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _agruparVentasPorProducto(List<dynamic> ventas) {
    final agrupado = LinkedHashMap<String, Map<String, dynamic>>();
    for (final v in ventas) {
      final key = v['productoId'] as String? ?? '';
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
        title: const Text('Rendición'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rendicion == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Generá la vista previa de tu rendición',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 24),
                      FloatingActionButton.extended(
                        onPressed: _generatePreview,
                        backgroundColor: AppTheme.colorCeleste,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.preview),
                        label: const Text('VER VISTA PREVIA'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Header ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Rendición de: ${_rendicion!['vendedoraNombre'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Fecha: ${_formatFecha(_rendicion!['fecha'] as String?)}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() => _rendicion = null),
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
                              _buildSummaryCard('Efectivo',
                                  '\$${netEfectivo.toStringAsFixed(0)}', Icons.money),
                              const SizedBox(width: 8),
                              _buildSummaryCard('Transfer.',
                                  '\$${netTransferencia.toStringAsFixed(0)}', Icons.account_balance),
                              const SizedBox(width: 8),
                              _buildSummaryCard('Total',
                                  '\$${netGeneral.toStringAsFixed(0)}', Icons.attach_money),
                            ],
                          ),
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
                                      '$totalTransferItems transferencia${totalTransferItems != 1 ? 's' : ''} - revisá en la solapa "Transf."',
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
                                  if (hasVentas)
                                    ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                      itemCount: ventasAgrupadas.length,
                                      itemBuilder: (context, index) => _buildVentaProductoCard(ventasAgrupadas[index]),
                                    ),
                                  if (hasDevoluciones)
                                    ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                      itemCount: devolucionesAgrupadas.length,
                                      itemBuilder: (context, index) => _buildDevolucionCard(devolucionesAgrupadas[index]),
                                    ),
                                  if (hasTransfers)
                                    transferencias.isNotEmpty
                                        ? ListView.builder(
                                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                            itemCount: transferencias.length,
                                            itemBuilder: (context, index) => _buildTransferenciaCard(transferencias[index] as Map<String, dynamic>),
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
                                  if (hasStock)
                                    ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                                      itemCount: stockRestante.length,
                                      itemBuilder: (context, index) => _buildStockCard(stockRestante[index] as Map<String, dynamic>),
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
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FloatingActionButton.extended(
                                heroTag: 'export',
                                onPressed: _exporting ? null : _exportRendicion,
                                backgroundColor: _exporting ? Colors.grey : AppTheme.colorMorado,
                                foregroundColor: Colors.white,
                                icon: _exporting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.send),
                                label: Text(_exporting ? 'ENVIANDO...' : 'ENVIAR RENDICIÓN'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _clearData,
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                label: const Text('LIMPIAR DATOS (cierre de ciclo)', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
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

  // ── Widgets idénticos al admin ──

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
            Icon(icon, size: 20, color: AppTheme.colorCeleste),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildVentaProductoCard(Map<String, dynamic> v) {
    final nombre = v['productoNombre'] as String? ?? '';
    final cantidad = ((v['cantidad'] as num?)?.toDouble() ?? 0).toInt();
    final total = (v['total'] as num?)?.toDouble() ?? 0;

    final stockList = _rendicion?['stockRestante'] as List<dynamic>? ?? [];
    double stockRestante = 0;
    for (final s in stockList) {
      if ((s as Map<String, dynamic>)['productoId'] == v['productoId']) {
        stockRestante = (s['cantidad'] as num?)?.toDouble() ?? 0;
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.colorMorado.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text('$cantidad', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.colorMorado)),
              ),
            ),
            const SizedBox(width: 12),
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
            Text('\$${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard(Map<String, dynamic> s) {
    final nombre = s['productoNombre'] as String? ?? '';
    final cantidad = (s['cantidad'] as num?)?.toDouble() ?? 0;

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
            Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13))),
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

  Widget _buildTransferenciaCard(Map<String, dynamic> t) {
    final amount = (t['amount'] as num?)?.toDouble() ?? 0;
    final name = t['clientName'] as String? ?? '';
    final phone = t['clientPhone'] as String? ?? '';
    final rawBank = (t['bank'] as String? ?? '').trim();
    final bank = rawBank.isEmpty ? 'Bancaria' : rawBank;
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
            if (phone.isNotEmpty || bank.isNotEmpty || txId.isNotEmpty || ci.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  if (phone.isNotEmpty) _transferChip(Icons.phone, phone),
                  _transferChip(Icons.account_balance, bank),
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
