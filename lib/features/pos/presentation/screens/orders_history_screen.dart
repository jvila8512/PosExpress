import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dateFormat = DateFormat('dd/MM/yy HH:mm');

  List<Order> _orders = [];
  final Map<String, List<OrderItem>> _orderItemsCache = {};
  final Map<String, List<OrderPayment>> _orderPaymentsCache = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 30;

  String _searchQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// Formatea cantidad respetando decimales (1.5 -> "1.5", 2.0 -> "2")
  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final db = AppDatabase.instance;
    final orders = await db.getAllPaidOrders(limit: _pageSize, offset: 0);
    _orderItemsCache.clear();
    _orderPaymentsCache.clear();
    _offset = _pageSize;
    _hasMore = orders.length >= _pageSize;

    if (mounted) setState(() { _orders = orders; _isLoading = false; });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() { _isLoadingMore = true; });
    final db = AppDatabase.instance;
    final more = await db.getAllPaidOrders(limit: _pageSize, offset: _offset);
    _offset += _pageSize;
    _hasMore = more.length >= _pageSize;

    if (mounted) setState(() { _orders.addAll(more); _isLoadingMore = false; });
  }

  Future<void> _toggleOrderDetail(int index) async {
    final order = _orders[index];
    if (_orderItemsCache.containsKey(order.id)) {
      // Already loaded, toggle collapse
      setState(() {});
      return;
    }
    final db = AppDatabase.instance;
    final items = await db.getOrderItems(order.id);
    final payments = await db.getOrderPayments(order.id);
    setState(() {
      _orderItemsCache[order.id] = items;
      _orderPaymentsCache[order.id] = payments;
    });
  }

  List<Order> get _filteredOrders {
    var filtered = _orders;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        // Search by order id or item names
        final idMatch = o.id.toLowerCase().contains(q);
        final itemsMatch = (_orderItemsCache[o.id] ?? [])
            .any((i) => i.productName.toLowerCase().contains(q));
        return idMatch || itemsMatch;
      }).toList();
    }

    if (_dateFrom != null) {
      filtered = filtered.where((o) =>
        o.paidAt != null && o.paidAt!.isAfter(_dateFrom!)).toList();
    }
    if (_dateTo != null) {
      final end = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
      filtered = filtered.where((o) =>
        o.paidAt != null && o.paidAt!.isBefore(end)).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Historial de Pedidos'),
        backgroundColor: AppTheme.colorCeleste,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por producto o #pedido...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = ''))
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_dateFrom != null ? _dateFormat.format(_dateFrom!) : 'Desde', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: _dateFrom ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now());
                          if (picked != null) setState(() => _dateFrom = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(_dateTo != null ? _dateFormat.format(_dateTo!) : 'Hasta', style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: _dateTo ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime.now());
                          if (picked != null) setState(() => _dateTo = picked);
                        },
                      ),
                    ),
                    if (_dateFrom != null || _dateTo != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpiar filtros',
                        onPressed: () => setState(() { _dateFrom = null; _dateTo = null; }),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Text('${filtered.length} pedidos', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const Spacer(),
                if (_isLoadingMore)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay pedidos', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          ],
                        ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scroll) {
                          if (scroll.metrics.pixels >= scroll.metrics.maxScrollExtent - 200) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(filtered[index], index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, int index) {
    final items = _orderItemsCache[order.id];
    final payments = _orderPaymentsCache[order.id];
    final isExpanded = items != null;
    final isReturn = order.subtotal < 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        children: [
          // Header - always visible
          InkWell(
            onTap: () => _toggleOrderDetail(index),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isReturn ? Colors.orange.shade50 : AppTheme.colorCeleste.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReturn ? Icons.undo : Icons.receipt,
                      size: 20,
                      color: isReturn ? Colors.orange : AppTheme.colorCeleste,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReturn ? 'Devolución' : 'Pedido #${order.id.substring(order.id.length - 6)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.paidAt != null ? _dateFormat.format(order.paidAt!) : '-',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${order.totalAmount.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isReturn ? Colors.orange : AppTheme.colorMorado,
                        ),
                      ),
                      if (items != null)
                        Text(
                          '${items.length} items',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),

          // Detail - expanded
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  if (items!.isNotEmpty) ...[
                    const Text('Productos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.productName, style: const TextStyle(fontSize: 12))),
                          Text('${_fmtQty(item.quantity)} × \$${item.unitPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(width: 8),
                          Text('\$${item.subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                  ],

                  const SizedBox(height: 8),

                  // Payments
                  if (payments != null && payments.isNotEmpty) ...[
                    const Text('Pago:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...payments.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          Icon(p.paymentMethod == 'efectivo' ? Icons.money : Icons.account_balance, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(_paymentLabel(p.paymentMethod), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          const Spacer(),
                          Text('\$${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          if (p.changeGiven > 0) ...[
                            const SizedBox(width: 4),
                            Text('(cambio: \$${p.changeGiven.toStringAsFixed(0)})', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    )),
                  ],

                  // Seller
                  const SizedBox(height: 6),
                  Text('Vendedor: ${order.sellerId}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'efectivo': return 'Efectivo';
      case 'transferencia': return 'Transferencia';
      case 'mixto': return 'Mixto';
      default: return method;
    }
  }
}
