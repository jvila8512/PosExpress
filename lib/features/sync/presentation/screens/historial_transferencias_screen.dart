import 'package:flutter/material.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:intl/intl.dart';

class HistorialTransferenciasScreen extends StatefulWidget {
  final bool isAdmin;
  const HistorialTransferenciasScreen({super.key, this.isAdmin = false});

  @override
  State<HistorialTransferenciasScreen> createState() =>
      _HistorialTransferenciasScreenState();
}

class _HistorialTransferenciasScreenState
    extends State<HistorialTransferenciasScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<_SessionGroup> _sessions = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  static const int _pageSize = 20;
  final _expandedSessions = <String>{};

  // Filtro por fecha
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _sessions = [];
        _currentPage = 0;
        _hasMore = true;
      });
    }

    final db = AppDatabase.instance;
    final offset = reset ? 0 : _currentPage * _pageSize;

    final sessions = await db.getSessionsPaginated(
      limit: _pageSize,
      offset: offset,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    // Load paid orders for these sessions
    final allOrders = await db.getAllPaidOrders(limit: 9999, offset: 0);

    // Build transfer map (only for loaded sessions)
    final sessionIds = sessions.map((s) => s.id).toSet();
    final sessionTransferMap = <String, List<_TransferDisplay>>{};

    for (final order in allOrders) {
      if (!sessionIds.contains(order.sessionId)) continue;
      final payments = await db.getOrderPayments(order.id);
      for (final payment in payments) {
        if (payment.paymentMethod == 'transferencia') {
          sessionTransferMap.putIfAbsent(order.sessionId, () => []);
          sessionTransferMap[order.sessionId]!.add(_TransferDisplay(
            orderId: order.id,
            sessionId: order.sessionId,
            amount: payment.amount,
            transactionId: payment.transactionId,
            purchaseId: payment.purchaseId,
            clientName: payment.clientName,
            clientPhone: payment.clientPhone,
            clientCI: payment.clientCI,
            transferDate: payment.transferDate,
            bank: payment.bank,
            reference: payment.reference,
            createdAt: payment.createdAt,
          ));
        }
      }
    }

    // Build groups
    final groups = <_SessionGroup>[];
    for (final session in sessions) {
      final transfers = sessionTransferMap[session.id];
      if (transfers != null && transfers.isNotEmpty) {
        transfers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        groups.add(_SessionGroup(session: session, transfers: transfers));
      }
    }

    if (mounted) {
      setState(() {
        if (reset) {
          _sessions = groups;
          _loading = false;
        } else {
          _sessions.addAll(groups);
          _loadingMore = false;
        }
        _hasMore = sessions.length == _pageSize;
        _currentPage = reset ? 1 : _currentPage + 1;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _loadTransfers(reset: false);
  }

  void _toggleSession(String sessionId) {
    setState(() {
      if (_expandedSessions.contains(sessionId)) {
        _expandedSessions.remove(sessionId);
      } else {
        _expandedSessions.add(sessionId);
      }
    });
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
      await _loadTransfers();
    }
  }

  void _clearFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadTransfers();
  }

  Future<void> _exportSessionToExcel(_SessionGroup group) async {
    try {
      final rows = <Map<String, dynamic>>[];
      for (final t in group.transfers) {
        rows.add(<String, dynamic>{
          'sessionOpening': group.session.openingTime.toIso8601String(),
          'createdAt': t.createdAt,
          'amount': t.amount,
          'transactionId': t.transactionId,
          'purchaseId': t.purchaseId,
          'clientName': t.clientName,
          'clientPhone': t.clientPhone,
          'clientCI': t.clientCI,
          'transferDate': t.transferDate,
          'bank': t.bank,
          'reference': t.reference,
        });
      }
      final filePath = await ExportService.instance.exportTransfersExcel(
        transfers: rows,
        fileNameSuffix:
            '_caja_${DateFormat('yyyy-MM-dd_HHmm').format(group.session.openingTime)}',
      );
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Transferencias');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al exportar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAllToExcel() async {
    try {
      final rows = <Map<String, dynamic>>[];
      for (final group in _sessions) {
        for (final t in group.transfers) {
          rows.add(<String, dynamic>{
            'sessionOpening': group.session.openingTime.toIso8601String(),
            'createdAt': t.createdAt,
            'amount': t.amount,
            'transactionId': t.transactionId,
            'purchaseId': t.purchaseId,
            'clientName': t.clientName,
            'clientPhone': t.clientPhone,
            'clientCI': t.clientCI,
            'transferDate': t.transferDate,
            'bank': t.bank,
            'reference': t.reference,
          });
        }
      }
      final filePath = await ExportService.instance.exportTransfersExcel(transfers: rows);
      if (mounted) {
        ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Historial de Transferencias');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al exportar: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDetail(_TransferDisplay t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text('Detalle Transferencia',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(t.createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 16),
                _detailRow(
                    Icons.attach_money, 'Monto', '\$${t.amount.toStringAsFixed(2)}'),
                if (t.transactionId != null)
                  _detailRow(Icons.tag, 'No. Transaccion', t.transactionId!),
                if (t.purchaseId != null)
                  _detailRow(Icons.receipt, 'Id Compra', t.purchaseId!),
                if (t.clientName != null)
                  _detailRow(Icons.person, 'Nombre', t.clientName!),
                if (t.clientPhone != null)
                  _detailRow(Icons.phone, 'Celular', t.clientPhone!),
                if (t.clientCI != null)
                  _detailRow(Icons.badge, 'CI', t.clientCI!),
                if (t.transferDate != null)
                  _detailRow(Icons.calendar_today, 'Fecha Transf.', t.transferDate!),
                if (t.bank != null)
                  _detailRow(Icons.account_balance, 'Banco', t.bank!),
                if (t.reference != null)
                  _detailRow(Icons.link, 'Referencia', t.reference!),
                _detailRow(Icons.receipt_long, 'Order ID', t.orderId),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.colorCeleste),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          Flexible(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalTransfers =
        _sessions.fold(0, (sum, g) => sum + g.transfers.length);
    final filtered = _fromDate != null || _toDate != null;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Historial Transferencias'),
        leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          // Filtro por fecha
          IconButton(
            icon: Icon(Icons.date_range,
                color: filtered ? AppTheme.colorCeleste : null),
            onPressed: _pickDateRange,
            tooltip: 'Filtrar por fecha',
          ),
          if (totalTransfers > 0)
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _exportAllToExcel,
              tooltip: 'Exportar todo a Excel',
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        '$totalTransfers transferencia${totalTransfers != 1 ? 's' : ''} en ${_sessions.length} caja${_sessions.length != 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.swap_horiz,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text('No hay transferencias registradas',
                                  style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (scrollInfo) {
                            if (scrollInfo.metrics.pixels ==
                                    scrollInfo.metrics.maxScrollExtent &&
                                _hasMore &&
                                !_loadingMore) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: RefreshIndicator(
                            onRefresh: () => _loadTransfers(),
                            child: ListView.builder(
                              itemCount:
                                  _sessions.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _sessions.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                }

                                final group = _sessions[index];
                                final isExpanded =
                                    _expandedSessions.contains(group.session.id);
                                final sessionTotal = group.transfers.fold(
                                    0.0, (sum, t) => sum + t.amount);
                                final session = group.session;
                                final statusColor =
                                    session.status == 'open'
                                        ? Colors.green
                                        : Colors.grey;
                                final statusLabel =
                                    session.status == 'open'
                                        ? 'Abierta'
                                        : 'Cerrada';

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: Column(
                                    children: [
                                      // Session header
                                      InkWell(
                                        onTap: () =>
                                            _toggleSession(session.id),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: AppTheme.colorCeleste,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Caja ${DateFormat('dd/MM/yy HH:mm').format(session.openingTime)}',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 14),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                      .symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2),
                                                          decoration: BoxDecoration(
                                                              color: statusColor
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4)),
                                                          child: Text(
                                                            statusLabel,
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    statusColor),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${group.transfers.length} transf. • Total: \$${sessionTotal.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Export per session
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.file_download,
                                                    size: 18,
                                                    color: Colors.purple),
                                                tooltip: 'Exportar esta caja',
                                                onPressed: () =>
                                                    _exportSessionToExcel(group),
                                              ),
                                              Text(
                                                '\$${sessionTotal.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Transfer items
                                      if (isExpanded) ...[
                                        const Divider(height: 1),
                                        ...group.transfers.map((t) {
                                          final hasData = t.transactionId !=
                                                  null ||
                                              t.clientPhone != null;
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: (hasData
                                                      ? Colors.purple
                                                      : Colors.grey)
                                                  .withValues(alpha: 0.1),
                                              child: Icon(Icons.swap_horiz,
                                                  color: hasData
                                                      ? Colors.purple
                                                      : Colors.grey,
                                                  size: 16),
                                            ),
                                            title: Text(
                                              t.clientName ??
                                                  t.clientPhone ??
                                                  'Sin datos de cliente',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13),
                                            ),
                                            subtitle: Text(
                                              '${t.transactionId ?? "Sin TX ID"} • ${DateFormat('dd/MM/yy HH:mm').format(t.createdAt)}',
                                              style:
                                                  const TextStyle(fontSize: 11),
                                            ),
                                            trailing: Text(
                                              '\$${t.amount.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple,
                                                  fontSize: 12),
                                            ),
                                            onTap: () => _showDetail(t),
                                          );
                                        }),
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

class _SessionGroup {
  final Session session;
  final List<_TransferDisplay> transfers;
  _SessionGroup({required this.session, required this.transfers});
}

class _TransferDisplay {
  final String orderId;
  final String? sessionId;
  final double amount;
  final String? transactionId;
  final String? purchaseId;
  final String? clientName;
  final String? clientPhone;
  final String? clientCI;
  final String? transferDate;
  final String? bank;
  final String? reference;
  final DateTime createdAt;

  _TransferDisplay({
    required this.orderId,
    this.sessionId,
    required this.amount,
    this.transactionId,
    this.purchaseId,
    this.clientName,
    this.clientPhone,
    this.clientCI,
    this.transferDate,
    this.bank,
    this.reference,
    required this.createdAt,
  });
}
