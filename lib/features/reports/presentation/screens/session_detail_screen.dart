import 'dart:convert';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool _isLoading = true;
  bool _isVendedor = false;
  Map<String, dynamic>? _data;
  String _saleSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = const FlutterSecureStorage();
    final role = await storage.read(key: 'user_role') ?? '';
    _isVendedor = role == 'vendedor';

    final db = AppDatabase.instance;
    final sessions = await (db.select(db.sessions)..where((s) => s.id.equals(widget.sessionId))).get();
    final session = sessions.first;

    final orders = await db.getPaidOrdersBySession(widget.sessionId);
    // Also load cancelled orders for display
    final cancelledOrders = await (db.select(db.orders)
          ..where((o) => o.sessionId.equals(widget.sessionId))
          ..where((o) => o.status.equals('cancelled'))
          ..orderBy([(o) => OrderingTerm.desc(o.paidAt)]))
        .get();
    final allOrdersForDisplay = [...orders, ...cancelledOrders];
    final items = <String, List<OrderItem>>{};

    for (final order in allOrdersForDisplay) {
      items[order.id] = await db.getOrderItems(order.id);
    }

    // Cargar pagos por orden (para datos del cliente)
    final paymentsByOrder = <String, List<OrderPayment>>{};
    for (final order in allOrdersForDisplay) {
      paymentsByOrder[order.id] = await db.getOrderPayments(order.id);
    }

    // Analyze products
    final productsData = <String, Map<String, dynamic>>{};
    double totalProfit = 0;

    // Cache de reglas de mayoreo por producto
    final wholesaleCache = <String, bool>{};

    for (final order in orders) {
      final orderItems = items[order.id] ?? [];
      for (final item in orderItems) {
        final name = item.productName;
        final venta = item.subtotal;
        final costo = item.costPrice * item.quantity;
        final ganancia = venta - costo;
        totalProfit += ganancia;

        // Detectar mayoreo: comparar unitPrice contra reglas de precio por mayor
        bool isWholesaleItem = false;
        if (!wholesaleCache.containsKey(item.productId)) {
          final rules = await db.getWholesaleRules(item.productId);
          bool found = false;
          for (final rule in rules) {
            final minQty = (rule['minQuantity'] as num).toDouble();
            final price = (rule['unitPrice'] as num).toDouble();
            if (item.quantity >= minQty && (price - item.unitPrice.abs()).abs() < 0.01) {
              found = true;
              break;
            }
          }
          wholesaleCache[item.productId] = found;
        }
        isWholesaleItem = wholesaleCache[item.productId]!;

        if (productsData.containsKey(name)) {
          productsData[name]!['quantity'] = (productsData[name]!['quantity'] as double) + item.quantity;
          productsData[name]!['venta'] = (productsData[name]!['venta'] as double) + venta;
          productsData[name]!['costo'] = (productsData[name]!['costo'] as double) + costo;
          productsData[name]!['ganancia'] = (productsData[name]!['ganancia'] as double) + ganancia;
          if (isWholesaleItem) productsData[name]!['esMayorista'] = true;
        } else {
          productsData[name] = {
            'quantity': item.quantity,
            'venta': venta,
            'costo': costo,
            'ganancia': ganancia,
            'esMayorista': isWholesaleItem,
          };
        }
      }
    }

    for (final key in productsData.keys) {
      final productGanancia = productsData[key]!['ganancia'] as double;
      final margen = totalProfit > 0 ? (productGanancia / totalProfit) * 100 : 0.0;
      productsData[key]!['margen'] = margen;
    }

    // Calcular ganancia real
    final profit = await db.getSessionProfit(widget.sessionId);

    // Cargar IPV snapshots (solo admin)
    InventorySnapshot? openSnapshot;
    InventorySnapshot? closeSnapshot;
    Map<String, double> entriesByProduct = {};
    if (!_isVendedor) {
      openSnapshot = await db.getSnapshotBySession(widget.sessionId);
      closeSnapshot = await db.getClosingSnapshotBySession(widget.sessionId);

      // Cargar movimientos de compra durante la sesión (entradas al PV)
      // Solo cuentan entradas las que van a 'pv' (o null para compatibilidad)
      // Los movimientos a 'almacen' NO son entradas al PV
      final allMovements = await (db.select(db.stockMovements)
            ..where((m) => m.movementType.equals('purchase'))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
          .get();
      // Filtrar: solo entradas al PV (excluir 'almacen') + rango de sesión
      final movements = allMovements.where((m) {
        // Excluir movimientos que van a almacen — no son entradas al PV
        if (m.toLocation == 'almacen') return false;
        if (m.createdAt.isBefore(session.openingTime)) return false;
        if (session.closingTime != null && m.createdAt.isAfter(session.closingTime!)) return false;
        return true;
      }).toList();
      for (final m in movements) {
        entriesByProduct[m.productId] =
            (entriesByProduct[m.productId] ?? 0) + m.quantity;
      }
    }

    // Cargar pagos de transferencia
    final allTransferPayments = <Map<String, dynamic>>[];
    for (final order in orders) {
      final payments = await db.getOrderPayments(order.id);
      for (final p in payments) {
        if (p.paymentMethod == 'transferencia' && p.amount > 0) {
          allTransferPayments.add({
            'clientName': p.clientName ?? '-',
            'clientPhone': p.clientPhone ?? '-',
            'clientCI': p.clientCI ?? '-',
            'transactionId': p.transactionId ?? '-',
            'purchaseId': p.purchaseId ?? '-',
            'bank': p.bank ?? '-',
            'amount': p.amount,
            'createdAt': p.createdAt,
          });
        }
      }
    }

    setState(() {
      _data = {
        'session': session,
        'orders': orders,
        'items': items,
        'productsData': productsData,
        'profit': profit,
        'snapshot': openSnapshot,
        'closeSnapshot': closeSnapshot,
        'entriesByProduct': entriesByProduct,
        'transferPayments': allTransferPayments,
        'paymentsByOrder': paymentsByOrder,
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Caja'),
        backgroundColor: AppTheme.colorCeleste,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar',
            onSelected: (val) => _export(val),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'excel', child: Text('Exportar Excel (Caja)')),
              const PopupMenuItem(value: 'pdf', child: Text('Exportar PDF (Caja)')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'ventas', child: Text('Reporte de Ventas (Excel)')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'transfer_excel', child: Text('Transferencias Excel (Todas)')),
              const PopupMenuItem(value: 'transfer_pdf_all', child: Text('Transferencias PDF (Todas)')),
              const PopupMenuItem(value: 'transfer_pdf_pago_linea', child: Text('Transferencias PDF (Pago en linea)')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'ipv_excel', child: Text('Exportar IPV Excel')),
              const PopupMenuItem(value: 'ipv_pdf', child: Text('Exportar IPV PDF')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final session = _data!['session'] as Session;
    final orders = _data!['orders'] as List<Order>;
    final orderItems = _data!['items'] as Map<String, List<OrderItem>>;
    final productsData = _data!['productsData'] as Map<String, Map<String, dynamic>>;
    final profit = _data!['profit'] as double;
    final isOpen = session.status == 'open';

    // Calcular efectivo esperado
    // totalCash ya es neto (efectivo de ventas - cambio entregado)
    final expectedCash = (session.openingCash ?? 0) + (session.totalCash ?? 0);
    final diff = session.closingCash != null ? session.closingCash! - expectedCash : null;

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOpen ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          session.status.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Abrió: ${session.userId}', style: const TextStyle(fontSize: 12)),
                  if (session.closingTime != null)
                    Text('Cerró: ${session.userId}', style: const TextStyle(fontSize: 12)),
                  Text('Apertura: ${_formatDateTime(session.openingTime)}'),
                  if (session.closingTime != null)
                    Text('Cierre: ${_formatDateTime(session.closingTime!)}'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // === RESUMEN ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.colorCeleste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.colorCeleste),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RESUMEN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.colorCeleste)),
                  const SizedBox(height: 12),
                  _buildRow('Ventas Totales', '\$${session.totalSales?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildRow('Efectivo (ventas)', '\$${session.totalCash?.toStringAsFixed(2) ?? '0.00'}'),
                  _buildRow('Transferencia (ventas)', '\$${session.totalTransfer?.toStringAsFixed(2) ?? '0.00'}'),
                  const Divider(),
                  _buildRow('Efectivo Inicial', '\$${session.openingCash?.toStringAsFixed(2) ?? '0.00'}'),
                  const Divider(),
                  _buildRowBold('Efectivo Esperado', '\$${expectedCash.toStringAsFixed(2)}'),
                  if (session.closingCash != null) ...[
                    _buildRow('Efectivo Real (arqueo)', '\$${session.closingCash!.toStringAsFixed(2)}'),
                    _buildRowBold(
                      'Diferencia',
                      '${diff! >= 0 ? '+' : ''}\$${diff.toStringAsFixed(2)}',
                    ),
                  ],
                  if (!_isVendedor) ...[
                    const Divider(),
                    _buildRow('Ganancia', '\$${profit.toStringAsFixed(2)}', Colors.green),
                  ],
                  const Divider(),
                  _buildRow('Pedidos', '${orders.length}'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // === VENTAS INDIVIDUALES (solo admin) ===
            if (!_isVendedor) ...[
              _buildIndividualSalesSection(),
              const SizedBox(height: 20),
            ],

            // === PRODUCTOS VENDIDOS === (solo admin ve costo y margen)
            const Text('PRODUCTOS VENDIDOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.grey.shade100,
                    child: _isVendedor
                        ? const Row(
                            children: [
                              Expanded(flex: 2, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(child: Text('Cant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                              Expanded(child: Text('Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                            ],
                          )
                        : const Row(
                            children: [
                              Expanded(flex: 2, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Expanded(child: Text('Cant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                              Expanded(child: Text('Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                              Expanded(child: Text('Costo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                              Expanded(child: Text('Marg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                            ],
                          ),
                  ),
                  // Rows (sorted alphabetically by product name)
                  ...(() {
                    final sorted = productsData.entries.toList()
                      ..sort((a, b) => a.key.compareTo(b.key));
                    return sorted.map((e) {
                      final p = e.value;
                      final qty = p['quantity'] as double;
                      final venta = p['venta'] as double;
                      final costo = p['costo'] as double;
                      final margen = p['margen'] as double;
                      final ganancia = p['ganancia'] as double;
                      final marginColor = ganancia >= 0 ? Colors.green : Colors.red;

                       final esMayorista = p['esMayorista'] == true;
                       final productLabel = Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Flexible(
                             child: Text(e.key, style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                           ),
                           if (esMayorista) ...[
                             const SizedBox(width: 3),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                               decoration: BoxDecoration(
                                 color: Colors.orange,
                                 borderRadius: BorderRadius.circular(3),
                               ),
                               child: const Text('M', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                           ],
                         ],
                       );

                       return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: _isVendedor
                            ? Row(
                                children: [
                                  Expanded(flex: 2, child: productLabel),
                                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(_fmtQty(qty), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center))),
                                   Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${venta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(flex: 2, child: productLabel),
                                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(_fmtQty(qty), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center))),
                                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${venta.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
                                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${costo.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right))),
                                  Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text('${margen.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, color: marginColor, fontWeight: FontWeight.bold), textAlign: TextAlign.right))),
                                ],
                              ),
                      );
                    });
                  }()),
                ],
              ),
            ),

            // === TRANSFERENCIAS ===
            _buildTransfersSection(),

            // === IPV (Inventario Físico Valorado) — solo admin ===
            if (!_isVendedor) ...[
              const SizedBox(height: 20),
              _buildIpvSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIpvSection() {
    final snapshot = _data!['snapshot'] as InventorySnapshot?;
    final closeSnapshot = _data!['closeSnapshot'] as InventorySnapshot?;
    final entriesByProduct = _data!['entriesByProduct'] as Map<String, double>;

    if (snapshot == null && closeSnapshot == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.assessment_outlined, size: 32, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text('Sin datos de inventario para esta sesión',
                  style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    // Parsear snapshots
    List<Map<String, dynamic>> openItems = [];
    try {
      if (snapshot != null) {
        final raw = jsonDecode(snapshot.snapshotData) as List<dynamic>;
        openItems = raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    List<Map<String, dynamic>> closeItems = [];
    try {
      if (closeSnapshot != null) {
        final raw = jsonDecode(closeSnapshot.snapshotData) as List<dynamic>;
        closeItems = raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    // Indexar por productId para buscar entradas
    final entriesByProductId = <String, double>{};
    // Mapear nombre -> productId desde los snapshots
    final nameToId = <String, String>{};
    for (final item in openItems) {
      final id = item['productId'] as String? ?? '';
      final name = item['name'] as String? ?? '';
      nameToId[name] = id;
    }
    for (final item in closeItems) {
      final id = item['productId'] as String? ?? '';
      final name = item['name'] as String? ?? '';
      nameToId[name] = id;
    }

    // Calcular movimientos por producto
    final movementByName = <String, Map<String, dynamic>>{};
    for (final item in openItems) {
      final name = item['name'] as String? ?? '';
      final openQty = (item['quantity'] as num?)?.toDouble() ?? 0;
      final costPerUnit = (item['costPerUnit'] as num?)?.toDouble() ?? 0;
      movementByName[name] = {
        'openQty': openQty,
        'closeQty': 0.0,
        'costPerUnit': costPerUnit,
        'totalValue': (item['totalValue'] as num?)?.toDouble() ?? 0,
        'salePrice': (item['salePrice'] as num?)?.toDouble() ?? 0,
      };
    }
    for (final item in closeItems) {
      final name = item['name'] as String? ?? '';
      final closeQty = (item['quantity'] as num?)?.toDouble() ?? 0;
      if (movementByName.containsKey(name)) {
        movementByName[name]!['closeQty'] = closeQty;
      } else {
        movementByName[name] = {
          'openQty': 0.0,
          'closeQty': closeQty,
          'costPerUnit': (item['costPerUnit'] as num?)?.toDouble() ?? 0,
          'totalValue': (item['totalValue'] as num?)?.toDouble() ?? 0,
          'salePrice': (item['salePrice'] as num?)?.toDouble() ?? 0,
        };
      }
    }

    // Totales
    double totalOpenQty = 0;
    double totalCloseQty = 0;
    double totalEntriesQty = 0;
    double totalOpenCost = 0;
    double totalCloseCost = 0;
    for (final e in movementByName.entries) {
      final m = e.value;
      final openQty = m['openQty'] as double;
      final closeQty = m['closeQty'] as double;
      final productId = nameToId[e.key] ?? '';
      final entries = entriesByProduct[productId] ?? 0;
      totalOpenQty += openQty;
      totalCloseQty += closeQty;
      totalEntriesQty += entries;
      totalOpenCost += openQty * (m['costPerUnit'] as double);
      totalCloseCost += closeQty * (m['costPerUnit'] as double);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: AppTheme.colorCeleste, size: 18),
                const SizedBox(width: 6),
                const Text('IPV',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),

            // Métricas resumen — compactas
            Row(
              children: [
                _ipMetric('Prod', '${movementByName.length}', Colors.blue),
                _ipMetric('Ini', _fmtQty(totalOpenQty), Colors.teal),
                _ipMetric('Ent', _fmtQty(totalEntriesQty), Colors.green),
                _ipMetric('Fin', _fmtQty(totalCloseQty), Colors.orange),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _ipMetric('Vend', _fmtQty(totalOpenQty - totalCloseQty + totalEntriesQty), Colors.red),
                _ipMetric('\$Vend', '\$${(totalOpenCost - totalCloseCost + totalEntriesQty * 0).toStringAsFixed(0)}', Colors.red.shade700),
                _ipMetric('\$Inv', '\$${totalCloseCost.toStringAsFixed(0)}', Colors.green),
              ],
            ),

            const Divider(height: 14),

            // Header de tabla — ultra compacto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9))),
                  Expanded(child: Text('Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center)),
                  Expanded(child: Text('Ent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center)),
                  Expanded(child: Text('Vend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center)),
                  Expanded(child: Text('Fin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9), textAlign: TextAlign.center)),
                ],
              ),
            ),

            // Filas — ultra compactas
            ...movementByName.entries.map((e) {
              final m = e.value;
              final openQty = m['openQty'] as double;
              final closeQty = m['closeQty'] as double;
              final productId = nameToId[e.key] ?? '';
              final entries = entriesByProduct[productId] ?? 0;
              final netQty = closeQty - openQty; // positivo = entró más
              final vendidos = openQty + entries - closeQty; // vendidos = ini + entradas - fin
              final costValue = closeQty * (m['costPerUnit'] as double);
              final hasEntries = entries > 0;

              // Color de fondo para Inicio si hubo entradas
              final inicioBg = hasEntries ? Colors.green.withValues(alpha: 0.1) : null;
              // Color del texto de Inicio
              final inicioColor = hasEntries ? Colors.green.shade700 : Colors.black87;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    // Producto
                    Expanded(flex: 3, child: Text(e.key, style: const TextStyle(fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    // Inicio — verde si hubo entradas
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      decoration: inicioBg != null ? BoxDecoration(color: inicioBg, borderRadius: BorderRadius.circular(2)) : null,
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text(_fmtQty(openQty), style: TextStyle(fontSize: 10, color: inicioColor, fontWeight: hasEntries ? FontWeight.bold : null), textAlign: TextAlign.center)),
                    )),
                    // Entradas — verde si > 0
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                      entries > 0 ? '+${_fmtQty(entries)}' : '-',
                      style: TextStyle(fontSize: 10, color: entries > 0 ? Colors.green.shade700 : Colors.grey.shade400, fontWeight: entries > 0 ? FontWeight.bold : null),
                      textAlign: TextAlign.center,
                    ))),
                    // Vendidos
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(
                      vendidos > 0 ? _fmtQty(vendidos) : '-',
                      style: TextStyle(fontSize: 10, color: vendidos > 0 ? Colors.red.shade700 : Colors.grey.shade400, fontWeight: vendidos > 0 ? FontWeight.bold : null),
                      textAlign: TextAlign.center,
                    ))),
                    // Final — verde si subió, rojo si bajó
                    Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: Text(_fmtQty(closeQty), style: TextStyle(fontSize: 10, color: netQty >= 0 ? Colors.green.shade700 : Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _ipMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ),
            Text(label, style: TextStyle(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Sección de ventas individuales (admin puede anular) ──
  Widget _buildIndividualSalesSection() {
    final orders = _data!['orders'] as List<Order>;
    final items = _data!['items'] as Map<String, List<OrderItem>>;
    final paymentsByOrder = _data!['paymentsByOrder'] as Map<String, List<OrderPayment>>;

    // Separate active and cancelled
    var activeOrders = orders.where((o) => o.status == 'paid').toList();
    final cancelledOrders = orders.where((o) => o.status == 'cancelled').toList();

    // Filtrar por búsqueda
    if (_saleSearchQuery.isNotEmpty) {
      final q = _saleSearchQuery.toLowerCase();
      activeOrders = activeOrders.where((order) {
        // Buscar por monto
        if (order.totalAmount.toString().contains(q)) return true;
        // Buscar por cliente
        final orderPayments = paymentsByOrder[order.id] ?? [];
        for (final p in orderPayments) {
          if (p.clientName?.toLowerCase().contains(q) == true) return true;
          if (p.clientPhone?.contains(q) == true) return true;
        }
        // Buscar por producto
        final orderItems = items[order.id] ?? [];
        for (final item in orderItems) {
          if (item.productName.toLowerCase().contains(q)) return true;
        }
        return false;
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 18),
            const SizedBox(width: 6),
            Text(
              'Ventas (${activeOrders.length})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade700),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Buscador
        SizedBox(
          height: 36,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por monto, cliente o producto...',
              hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400),
              suffixIcon: _saleSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: Colors.grey.shade400),
                      onPressed: () => setState(() => _saleSearchQuery = ''),
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) => setState(() => _saleSearchQuery = v),
          ),
        ),
        const SizedBox(height: 6),

        // Lista de ventas expandibles
        if (activeOrders.isEmpty && _saleSearchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No hay ventas en esta sesión', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        else if (activeOrders.isEmpty && _saleSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No se encontraron resultados', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          )
        else
          ...activeOrders.map((order) {
            final orderItems = items[order.id] ?? [];
            final orderPayments = paymentsByOrder[order.id] ?? [];
            final timeStr = order.paidAt != null ? _formatDateTime(order.paidAt!) : '-';
            // Get client data
            String? clientName;
            String? clientPhone;
            String? clientCI;
            String? paymentMethod;
            String? transactionId;
            String? bank;
            for (final p in orderPayments) {
              if (p.clientName?.isNotEmpty == true) clientName = p.clientName;
              if (p.clientPhone?.isNotEmpty == true) clientPhone = p.clientPhone;
              if (p.clientCI?.isNotEmpty == true) clientCI = p.clientCI;
              if (p.paymentMethod.isNotEmpty) paymentMethod = p.paymentMethod;
              if (p.transactionId?.isNotEmpty == true) transactionId = p.transactionId;
              if (p.bank?.isNotEmpty == true) bank = p.bank;
            }

            // Detectar si es mixto (efectivo + transferencia)
            final methods = orderPayments.map((p) => p.paymentMethod).toSet();
            final isMixed = methods.length > 1;

            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.orange.shade100,
                  child: Text(
                    '${orderItems.length}',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      '\$${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(timeStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    if (isMixed) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(3)),
                        child: Text('Mix', style: TextStyle(fontSize: 8, color: Colors.purple.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: clientName != null
                    ? Text('👤 $clientName${clientPhone != null ? ' 📱 $clientPhone' : ''}',
                        style: TextStyle(fontSize: 10, color: Colors.blue.shade600))
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (paymentMethod != null)
                      Icon(
                        paymentMethod == 'efectivo' ? Icons.money : Icons.account_balance,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    IconButton(
                      icon: Icon(Icons.cancel_outlined, color: Colors.red.shade300, size: 18),
                      tooltip: 'Anular',
                      onPressed: () => _showCancelSaleDialog(order),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                children: [
                  // Detalle de productos
                  ...orderItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Text('x${_fmtQty(item.quantity)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        const SizedBox(width: 8),
                        Text('\$${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
                  // Datos de transferencia si existen
                  if (transactionId != null && transactionId != '-') ...[
                    const Divider(height: 8),
                    Row(
                      children: [
                        Icon(Icons.payment, size: 12, color: Colors.purple.shade400),
                        const SizedBox(width: 4),
                        Text('TX: $transactionId', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                        if (bank != null && bank != '-') ...[
                          const SizedBox(width: 8),
                          Text(bank!, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),

        // Ventas anuladas (colapsadas)
        if (cancelledOrders.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Anuladas (${cancelledOrders.length})', style: TextStyle(fontSize: 11, color: Colors.red.shade300, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...cancelledOrders.map((order) {
            final timeStr = order.paidAt != null ? _formatDateTime(order.paidAt!) : '-';
            return Card(
              margin: const EdgeInsets.only(bottom: 3),
              color: Colors.red.shade50,
              child: ListTile(
                dense: true,
                leading: Icon(Icons.cancel, size: 14, color: Colors.red.shade300),
                title: Text(
                  '\$${order.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade300, decoration: TextDecoration.lineThrough),
                ),
                subtitle: Text('$timeStr - ANULADA', style: TextStyle(fontSize: 9, color: Colors.red.shade300)),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showCancelSaleDialog(Order order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            reasonController.addListener(() => setDialogState(() {}));
            return AlertDialog(
              title: const Text('Anular venta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Venta de \$${order.totalAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const Text('Motivo de anulación:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Precio incorrecto',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se restaurará el stock de todos los productos.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: reasonController.text.trim().isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _cancelOrder(order, reasonController.text.trim());
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('ANULAR VENTA'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => reasonController.dispose());
  }

  Future<void> _cancelOrder(Order order, String reason) async {
    try {
      final storage = const FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id') ?? '';
      final db = AppDatabase.instance;
      await db.cancelOrder(
        orderId: order.id,
        reason: reason,
        cancelledByUserId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Venta de \$${order.totalAmount.toStringAsFixed(2)} anulada - stock restaurado'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al anular: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTransfersSection() {
    final transferPayments = _data!['transferPayments'] as List<Map<String, dynamic>>;
    if (transferPayments.isEmpty) return const SizedBox.shrink();

    final totalTransfer = transferPayments.fold<double>(0, (sum, t) => sum + (t['amount'] as double));

    // Agrupar por tipo (campo bank)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in transferPayments) {
      final rawBank = (t['bank'] as String? ?? '').trim();
      final tipo = rawBank.isEmpty ? 'Bancaria' : rawBank;
      grouped.putIfAbsent(tipo, () => []).add(t);
    }
    final sortedTypes = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.account_balance, color: Colors.purple.shade700, size: 20),
            const SizedBox(width: 8),
            Text(
              'Transferencias (${transferPayments.length})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple.shade700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...sortedTypes.map((tipo) {
          final items = grouped[tipo]!;
          final subTotal = items.fold<double>(0, (sum, t) => sum + (t['amount'] as double));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sub-header por tipo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Text(
                  tipo,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade800),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purple.shade200!),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.purple.shade50,
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(child: Text('Celular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('No. Transaccion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('Monto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                        ],
                      ),
                    ),
                    // Rows
                    ...items.map((t) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.purple.shade100!)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text('${t['clientName']}', style: const TextStyle(fontSize: 11))),
                            Expanded(child: Text('${t['clientPhone']}', style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: Text('${t['transactionId']}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center))),
                            Expanded(flex: 2, child: FittedBox(fit: BoxFit.scaleDown, child: Text('\$${(t['amount'] as double).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                          ],
                        ),
                      );
                    }),
                    // Sub-total
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.purple.shade50,
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            'Subtotal:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade700),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\$${subTotal.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
        // Total general
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.purple.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              const Spacer(),
              Text(
                '\$${totalTransfer.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _export(String format) async {
    if (_data == null) return;
    final session = _data!['session'] as Session;

    try {
      String filePath;
      String shareText;

      if (format == 'ventas') {
        filePath = await ExportService.instance.exportReporteVentasExcel(session);
        shareText = 'Reporte de Ventas';
      } else if (format == 'transfer_excel') {
        filePath = await ExportService.instance.exportSessionTransferExcel(session);
        shareText = 'Transferencias Excel';
      } else if (format == 'transfer_pdf_all') {
        filePath = await ExportService.instance.exportSessionTransferPdfAll(session);
        shareText = 'Transferencias PDF (Todas)';
      } else if (format == 'transfer_pdf_pago_linea') {
        filePath = await ExportService.instance.exportSessionTransferPdfPagoEnLinea(session);
        shareText = 'Transferencias PDF (Pago en linea)';
      } else if (format == 'ipv_excel' || format == 'ipv_pdf') {
        final snapshot = _data!['snapshot'] as InventorySnapshot?;
        final closeSnapshot = _data!['closeSnapshot'] as InventorySnapshot?;
        if (snapshot == null && closeSnapshot == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No hay datos de inventario para exportar'), backgroundColor: Colors.orange),
            );
          }
          return;
        }
        if (format == 'ipv_excel') {
          filePath = await ExportService.instance.exportSessionIpvExcel(session, snapshot, closeSnapshot: closeSnapshot);
        } else {
          filePath = await ExportService.instance.exportSessionIpvPdf(session, snapshot, closeSnapshot: closeSnapshot);
        }
        shareText = 'IPV Caja ${_formatDateTime(session.openingTime)}';
      } else {
        filePath = format == 'excel'
            ? await ExportService.instance.exportSessionExcel(session)
            : await ExportService.instance.exportSessionPdf(session);
        shareText = 'Informe de Caja';
      }

      // Archivo ya guardado en Exportaciones (interno) - mostrar opciones
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: shareText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRowBold(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.colorCeleste)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day}/${dt.month}/${dt.year} $hour:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
