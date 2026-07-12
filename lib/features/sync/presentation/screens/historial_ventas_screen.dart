import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:intl/intl.dart';

class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Sale> _sales = [];
  Map<String, List<SaleItem>> _saleItems = {};
  Map<String, List<OrderPayment>> _transferPayments = {};
  Map<String, dynamic> _wholesaleRules = {};
  Map<String, String> _productNameCache = {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  int _totalCount = 0;
  static const int _pageSize = 20;

  // Filtro por fecha
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _sales = [];
        _saleItems = {};
        _transferPayments = {};
        _currentPage = 0;
        _hasMore = true;
      });
    }

    final db = AppDatabase.instance;
    final offset = reset ? 0 : _currentPage * _pageSize;

    final sales = await db.getSalesPaginated(
      limit: _pageSize,
      offset: reset ? 0 : _currentPage * _pageSize,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final count = await db.countSales(fromDate: _fromDate, toDate: _toDate);

    // Cargar reglas de precio por mayor (una vez)
    final wholesaleRules = await db.getAllWholesaleRules();

    // Load items and transfer payments for these sales
    final itemsMap = <String, List<SaleItem>>{};
    final transferMap = <String, List<OrderPayment>>{};
    final nameCache = <String, String>{};
    for (final sale in sales) {
      final items = await db.getSaleItemsBySaleId(sale.id);
      itemsMap[sale.id] = items;

      // Cache product names
      for (final item in items) {
        if (!nameCache.containsKey(item.productId)) {
          final product = await db.getProductById(item.productId);
          nameCache[item.productId] = product?.name ?? item.productId;
        }
      }

      // Load transfer payments for this specific sale's order
      final orderId = _extractOrderId(sale.id);
      if (orderId != null) {
        final orderPayments = await db.getOrderPayments(orderId);
        final tp = orderPayments
            .where((p) => p.paymentMethod == 'transferencia' && p.amount > 0)
            .toList();
        if (tp.isNotEmpty) {
          transferMap[sale.id] = tp;
        }
      }
    }

    if (mounted) {
      setState(() {
        if (reset) {
          _sales = sales;
          _saleItems = itemsMap;
          _transferPayments = transferMap;
          _wholesaleRules = wholesaleRules;
          _productNameCache = nameCache;
          _loading = false;
        } else {
          _sales.addAll(sales);
          _saleItems.addAll(itemsMap);
          _transferPayments.addAll(transferMap);
          _productNameCache.addAll(nameCache);
          _loadingMore = false;
        }
        _totalCount = count;
        _hasMore = sales.length == _pageSize;
        _currentPage = reset ? 1 : _currentPage + 1;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadData(reset: false);
  }

  /// Verifica si un item de venta fue a precio por mayor
  bool _isItemWholesale(SaleItem item) {
    if (item.unitPrice <= 0) return false;
    final rules = (_wholesaleRules[item.productId] as List<dynamic>?) ?? [];
    for (final rule in rules) {
      final minQty = (rule['minQuantity'] as num).toDouble();
      final price = (rule['unitPrice'] as num).toDouble();
      if (item.quantity >= minQty && (price - item.unitPrice.abs()).abs() < 0.01) {
        return true;
      }
    }
    return false;
  }

  /// Extraer orderId del saleId del POS (saleId = 'SR' + orderId)
  String? _extractOrderId(String saleId) {
    if (saleId.startsWith('SR')) return saleId.substring(2);
    if (saleId.startsWith('S')) return saleId.substring(1);
    return null;
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
      await _loadData();
    }
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadData();
  }

  Future<void> _exportExcel() async {
    try {
      final from = _fromDate ?? DateTime.now().subtract(const Duration(days: 365));
      final to = _toDate ?? DateTime.now();
      final filePath = await ExportService.instance.exportSalesExcel(from: from, to: to);
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Informe de Ventas');
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
      final from = _fromDate ?? DateTime.now().subtract(const Duration(days: 365));
      final to = _toDate ?? DateTime.now();
      final filePath = await ExportService.instance.exportSalesPdf(from: from, to: to);
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Informe de Ventas');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _fromDate != null || _toDate != null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Historial de Ventas'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          // Filtro por fecha
          IconButton(
            icon: Icon(Icons.date_range, color: filtered ? AppTheme.colorCeleste : null),
            onPressed: _pickDateRange,
            tooltip: 'Filtrar por fecha',
          ),
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
                // Filter chip
                if (filtered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: AppTheme.colorCeleste.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, size: 16, color: AppTheme.colorCeleste),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd/MM/yy').format(_fromDate!)} - ${DateFormat('dd/MM/yy').format(_toDate!)}',
                            style: TextStyle(fontSize: 13, color: AppTheme.colorCeleste, fontWeight: FontWeight.w600),
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

                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '$_totalCount venta${_totalCount != 1 ? 's' : ''}${filtered ? ' en rango' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _sales.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('No hay ventas registradas'),
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
                            onRefresh: () => _loadData(),
                            child: ListView.builder(
                              itemCount: _sales.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _sales.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }

                                final sale = _sales[index];
                                final items = _saleItems[sale.id] ?? [];
                                final transfers = _transferPayments[sale.id] ?? [];
                                final isReturn = sale.totalAmount < 0;
                                final hasTransfers = transfers.isNotEmpty;

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isReturn
                                          ? Colors.orange.shade100
                                          : hasTransfers
                                              ? Colors.purple.shade100
                                              : Colors.green.shade100,
                                      child: Icon(
                                        isReturn
                                            ? Icons.undo
                                            : hasTransfers
                                                ? Icons.swap_horiz
                                                : Icons.receipt,
                                        color: isReturn
                                            ? Colors.orange
                                            : hasTransfers
                                                ? Colors.purple
                                                : Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      '\$${sale.totalAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isReturn ? Colors.orange : Colors.green,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate)} | ${sale.paymentMethod}',
                                    ),
                                    children: [
                                      // Sale items
                                      ...items.map((item) {
                                        final isWholesale = _isItemWholesale(item);
                                        return ListTile(
                                          dense: true,
                                          title: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  _productNameCache[item.productId] ?? item.productId,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isWholesale) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'MAYORISTA',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: Text(
                                            '${item.quantity} x \$${item.unitPrice.toStringAsFixed(0)} = \$${item.subtotal.toStringAsFixed(0)}',
                                          ),
                                        );
                                      }),

                                      // Transfer payment details
                                      if (hasTransfers) ...[
                                        const Divider(height: 1, indent: 16, endIndent: 16),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                          child: Row(
                                            children: [
                                              Icon(Icons.swap_horiz, size: 16, color: Colors.purple.shade400),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Datos de Transferencia',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.purple.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...transfers.map((payment) => ListTile(
                                              dense: true,
                                              leading: Icon(Icons.payment, size: 16, color: Colors.purple.shade300),
                                              title: Text(
                                                '${payment.clientName ?? payment.clientPhone ?? "Sin datos"}',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                              ),
                                              subtitle: Text(
                                                '${payment.transactionId ?? "Sin TX"}'
                                                '${payment.bank?.isNotEmpty == true ? " • ${payment.bank}" : " • Bancaria"}'
                                                '${payment.transferDate != null ? " • ${payment.transferDate}" : ""}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                              trailing: Text(
                                                '\$${payment.amount.toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 12),
                                              ),
                                            )),
                                      ],
                                    ],
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
