import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/shared.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late DateTime _fromDate;
  late DateTime _toDate;
  List<Sale> _sales = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  double _totalSales = 0;
  double _totalProfit = 0;
  double _totalExpenses = 0;
  double _totalOperatingExpenses = 0;
  Map<String, double> _operatingExpenseByCategory = {};
  int _totalTickets = 0;
  String _userRole = '';
  String _activeRangeLabel = 'Hoy';
  final _currencyFormat = NumberFormat.currency(symbol: '\$');

  static const _kpiDescriptions = <String, String>{
    'Ventas': 'Suma total de todas las ventas realizadas en el período seleccionado, sin descontar costos ni gastos.',
    'Ganancia': 'Ventas totales menos el costo de los productos vendidos. Es tu margen bruto real.',
    'Gastos/Compras': 'Total de facturas de compra registradas en el período (reposición de inventario para la venta).',
    'Gastos Operativos': 'Total de gastos operativos del período: transporte, alimentación, construcciones, inversiones, pago a trabajadores, tributos y otros. No incluye compras de mercancía.',
    'Rentabilidad %': 'Porcentaje de ganancia sobre las ventas. Arriba de 30% es saludable para un negocio minorista.',
    'Tickets': 'Cantidad total de transacciones (ventas) realizadas en el período.',
    'Ticket Prom.': 'Valor promedio por transacción. Se calcula dividiendo ventas totales entre cantidad de tickets.',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day);
    _toDate = DateTime(now.year, now.month, now.day + 1);
    _loadUserRole().then((_) => _loadSales());
  }

  Future<void> _loadUserRole() async {
    final role = await KeyValueStorageService().getValue('user_role');
    if (mounted) {
      setState(() => _userRole = role ?? '');
    }
  }

  bool get _isVendedor => _userRole == 'vendedor';

  String get _rangeLabel {
    if (_isRangeToday) return 'Hoy';
    if (_isRangeYesterday) return 'Ayer';
    if (_isRangeThisWeek) return 'Semana';
    if (_isRangeThisMonth) return 'Mes';
    return '${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate.subtract(const Duration(days: 1)))}';
  }

  bool get _isRangeToday {
    final now = DateTime.now();
    return _fromDate == DateTime(now.year, now.month, now.day) &&
        _toDate == DateTime(now.year, now.month, now.day + 1);
  }

  bool get _isRangeYesterday {
    final now = DateTime.now();
    final y = now.subtract(const Duration(days: 1));
    return _fromDate == DateTime(y.year, y.month, y.day) &&
        _toDate == DateTime(y.year, y.month, y.day + 1);
  }

  bool get _isRangeThisWeek {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _fromDate == DateTime(weekStart.year, weekStart.month, weekStart.day) &&
        _toDate == DateTime(now.year, now.month, now.day + 1);
  }

  bool get _isRangeThisMonth {
    final now = DateTime.now();
    return _fromDate == DateTime(now.year, now.month, 1) &&
        _toDate == DateTime(now.year, now.month, now.day + 1);
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      _sales = await db.getSalesByDateRange(_fromDate, _toDate);
      _totalSales = 0;
      _totalTickets = _sales.length;

      for (final s in _sales) {
        _totalSales += s.totalAmount;
      }

      // Load profit (admin only)
      if (!_isVendedor) {
        _totalProfit = await db.getProfitByDateRange(_fromDate, _toDate);
      } else {
        _totalProfit = 0;
      }

      // Load purchase invoices (compras de mercancía)
      final invoices = await db.getInvoicesByDateRange(
        from: _fromDate,
        to: _toDate,
      );
      _totalExpenses = 0;
      for (final invoice in invoices) {
        _totalExpenses += invoice.totalAmount;
      }

      // Load operating expenses (gastos operativos)
      final operatingExpenses = await db.getExpensesByDateRange(_fromDate, _toDate);
      _totalOperatingExpenses = 0;
      for (final e in operatingExpenses) {
        _totalOperatingExpenses += e.amount;
      }
      _operatingExpenseByCategory = await db.getExpensesByCategory(_fromDate, _toDate);

      if (mounted) {
        setState(() {
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _setQuickRange(String range) {
    final now = DateTime.now();
    setState(() {
      switch (range) {
        case 'today':
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = DateTime(now.year, now.month, now.day + 1);
          _activeRangeLabel = 'Hoy';
          break;
        case 'yesterday':
          final y = now.subtract(const Duration(days: 1));
          _fromDate = DateTime(y.year, y.month, y.day);
          _toDate = DateTime(y.year, y.month, y.day + 1);
          _activeRangeLabel = 'Ayer';
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _fromDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _toDate = DateTime(now.year, now.month, now.day + 1);
          _activeRangeLabel = 'Semana';
          break;
        case 'month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month, now.day + 1);
          _activeRangeLabel = 'Mes';
          break;
      }
    });
  }

  Future<void> _showDateFilterModal() async {
    DateTime tempFrom = _fromDate;
    DateTime tempTo = _toDate;
    String tempRange = _activeRangeLabel;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Seleccionar período',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Quick range chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _modalChip('Hoy', 'today', tempRange, (v) {
                    setModalState(() {
                      tempRange = 'Hoy';
                      final now = DateTime.now();
                      tempFrom = DateTime(now.year, now.month, now.day);
                      tempTo = DateTime(now.year, now.month, now.day + 1);
                    });
                  }),
                  _modalChip('Ayer', 'yesterday', tempRange, (v) {
                    setModalState(() {
                      tempRange = 'Ayer';
                      final now = DateTime.now();
                      final y = now.subtract(const Duration(days: 1));
                      tempFrom = DateTime(y.year, y.month, y.day);
                      tempTo = DateTime(y.year, y.month, y.day + 1);
                    });
                  }),
                  _modalChip('Semana', 'week', tempRange, (v) {
                    setModalState(() {
                      tempRange = 'Semana';
                      final now = DateTime.now();
                      final weekStart = now.subtract(Duration(days: now.weekday - 1));
                      tempFrom = DateTime(weekStart.year, weekStart.month, weekStart.day);
                      tempTo = DateTime(now.year, now.month, now.day + 1);
                    });
                  }),
                  _modalChip('Mes', 'month', tempRange, (v) {
                    setModalState(() {
                      tempRange = 'Mes';
                      final now = DateTime.now();
                      tempFrom = DateTime(now.year, now.month, 1);
                      tempTo = DateTime(now.year, now.month, now.day + 1);
                    });
                  }),
                ],
              ),
              const SizedBox(height: 16),

              // Custom date range
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: tempFrom,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempFrom = DateTime(picked.year, picked.month, picked.day);
                            tempRange = '';
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        'Desde ${DateFormat('dd/MM/yyyy').format(tempFrom)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('a'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: tempTo.subtract(const Duration(days: 1)),
                          firstDate: tempFrom,
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempTo = DateTime(picked.year, picked.month, picked.day + 1);
                            tempRange = '';
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        'Hasta ${DateFormat('dd/MM/yyyy').format(tempTo.subtract(const Duration(days: 1)))}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fromDate = tempFrom;
                    _toDate = tempTo;
                    _activeRangeLabel = tempRange;
                    _loadSales();
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Consultar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalChip(String label, String value, String currentRange, void Function(String) onSelected) {
    final isSelected = currentRange == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      onSelected: (_) => onSelected(value),
    );
  }

  Map<DateTime, double> _groupSalesByDay() {
    final map = <DateTime, double>{};
    for (final sale in _sales) {
      final day = DateTime(
        sale.saleDate.year,
        sale.saleDate.month,
        sale.saleDate.day,
      );
      map[day] = (map[day] ?? 0) + sale.totalAmount;
    }
    return map;
  }

  Map<String, int> _countSalesByPaymentMethod() {
    final map = <String, int>{};
    for (final sale in _sales) {
      final method = sale.paymentMethod;
      map[method] = (map[method] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Reportes'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_hasLoaded)
            PopupMenuButton<String>(
              icon: const Icon(Icons.download, size: 22),
              tooltip: 'Exportar',
              onSelected: (value) async {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exportando...'), duration: Duration(seconds: 1)),
                  );
                  final filePath = value == 'excel'
                      ? await ExportService.instance.exportSalesExcel(from: _fromDate, to: _toDate)
                      : await ExportService.instance.exportSalesPdf(from: _fromDate, to: _toDate);
                  if (mounted) {
                    ExportOptionsDialog.show(context, filePath: filePath, shareText: 'Informe de Ventas');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.table_chart, size: 20, color: Colors.black87), SizedBox(width: 8), Text('Excel (.xlsx)')])),
                const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, size: 20, color: Colors.black87), SizedBox(width: 8), Text('PDF')])),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasLoaded
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assessment_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'Cargando datos...',
                        style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSales,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Range selector chip (always visible)
                      _buildRangeChip(),
                      const SizedBox(height: 16),

                      // KPI Summary Cards
                      _buildKpiRows(),
                      const SizedBox(height: 16),

                      // Gastos Operativos
                      if (_operatingExpenseByCategory.isNotEmpty) ...[
                        _buildOperatingExpensesSection(),
                        const SizedBox(height: 16),
                      ],

                      // Charts
                      if (_sales.isNotEmpty) ...[
                        _buildDailySalesChart(),
                        const SizedBox(height: 16),
                        _buildPaymentMethodChart(),
                        const SizedBox(height: 16),
                      ],

                      // Sales detail list header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detalle de Ventas (${_sales.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _showDateFilterModal,
                            icon: const Icon(Icons.filter_list, size: 18),
                            label: const Text('Filtrar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_sales.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No hay ventas en este rango')),
                          ),
                        )
                      else
                        ..._sales.map((sale) => _saleCard(sale)),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDateFilterModal,
        tooltip: 'Cambiar período',
        child: const Icon(Icons.date_range),
      ),
    );
  }

  Widget _buildRangeChip() {
    return GestureDetector(
      onTap: _showDateFilterModal,
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _rangeLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              Icon(Icons.edit_calendar, size: 18, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiRow(List<_KpiItem> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: items.indexOf(item) > 0 ? 4 : 0,
                right: items.indexOf(item) < items.length - 1 ? 4 : 0,
              ),
              child: _kpiCard(item.title, item.value, item.icon, item.color, item.description),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiRows() {
    final double avgTicket = _totalTickets > 0 ? _totalSales / _totalTickets : 0;
    final double rentabilidad = _totalSales > 0 ? (_totalProfit / _totalSales) * 100 : 0;

    if (_isVendedor) {
      return Column(
        children: [
          _buildKpiRow([
            _KpiItem('Ventas', _currencyFormat.format(_totalSales), Icons.attach_money, Colors.green, _kpiDescriptions['Ventas']!),
            _KpiItem('Gastos/Compras', _currencyFormat.format(_totalExpenses), Icons.shopping_cart, Colors.orange, _kpiDescriptions['Gastos/Compras']!),
          ]),
          _buildKpiRow([
            _KpiItem('Tickets', _totalTickets.toString(), Icons.receipt, Colors.blue, _kpiDescriptions['Tickets']!),
            _KpiItem('Ticket Prom.', _currencyFormat.format(avgTicket), Icons.trending_up, Colors.purple, _kpiDescriptions['Ticket Prom.']!),
          ]),
        ],
      );
    }

    return Column(
      children: [
        _buildKpiRow([
          _KpiItem('Ventas', _currencyFormat.format(_totalSales), Icons.attach_money, Colors.green, _kpiDescriptions['Ventas']!),
          _KpiItem('Ganancia', _currencyFormat.format(_totalProfit), Icons.account_balance_wallet, Colors.teal, _kpiDescriptions['Ganancia']!),
        ]),
        _buildKpiRow([
          _KpiItem('Gastos/Compras', _currencyFormat.format(_totalExpenses), Icons.shopping_cart, Colors.orange, _kpiDescriptions['Gastos/Compras']!),
          _KpiItem('Rentabilidad %', '${rentabilidad.toStringAsFixed(1)}', Icons.percent, Colors.indigo, _kpiDescriptions['Rentabilidad %']!),
        ]),
        _buildKpiRow([
          _KpiItem('Tickets', _totalTickets.toString(), Icons.receipt, Colors.blue, _kpiDescriptions['Tickets']!),
          _KpiItem('Ticket Prom.', _currencyFormat.format(avgTicket), Icons.trending_up, Colors.purple, _kpiDescriptions['Ticket Prom.']!),
        ]),
      ],
    );
  }

  Widget _buildOperatingExpensesSection() {
    final colors = Theme.of(context).colorScheme;
    final sortedCats = _operatingExpenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text('Gastos Operativos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onSurface)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _currencyFormat.format(_totalOperatingExpenses),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 2),
            Text(
              'Transporte, alimentación, construcción, inversiones, trabajadores, tributos y otros',
              style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)),
            ),
            const Divider(height: 20),
            ...sortedCats.map((e) {
              final pct = _totalOperatingExpenses > 0 ? (e.value / _totalOperatingExpenses) * 100 : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(e.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: Colors.orange.shade100,
                          color: Colors.orange.shade400,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        _currencyFormat.format(e.value),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart() {
    final dailySales = _groupSalesByDay();
    final sortedDays = dailySales.keys.toList()..sort();

    if (sortedDays.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstDay = sortedDays.first;
    final lastDay = sortedDays.last;
    final double maxSale = dailySales.values.fold(0, (prev, e) => e > prev ? e : prev);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < sortedDays.length; i++) {
      final day = sortedDays[i];
      final x = day.difference(firstDay).inDays.toDouble();
      barGroups.add(
        BarChartGroupData(
          x: x.toInt(),
          barRods: [
            BarChartRodData(
              toY: dailySales[day] ?? 0,
              color: Colors.green,
              width: sortedDays.length > 10 ? 8 : 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ventas por Día',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxSale > 0 ? maxSale * 1.2 : 100,
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxSale > 0 ? (maxSale * 1.2) / 5 : 20,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == meta.min) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '\$${value.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final dayOffset = value.toInt();
                          if (dayOffset < 0 || dayOffset > lastDay.difference(firstDay).inDays) {
                            return const SizedBox.shrink();
                          }
                          // Mostrar solo cada 5 días (o el primero/último)
                          final totalDays = lastDay.difference(firstDay).inDays;
                          if (dayOffset != 0 && dayOffset != totalDays && dayOffset % 5 != 0) {
                            return const SizedBox.shrink();
                          }
                          final day = firstDay.add(Duration(days: dayOffset));
                          final label = DateFormat('dd/MM').format(day);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label, style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final dayOffset = group.x;
                        final day = firstDay.add(Duration(days: dayOffset));
                        return BarTooltipItem(
                          '${DateFormat('dd/MM').format(day)}\n\$${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChart() {
    final methodCounts = _countSalesByPaymentMethod();

    // Filter out Tarjeta for vendedor
    final filteredMethods = Map<String, int>.from(methodCounts);
    if (_isVendedor) {
      filteredMethods.removeWhere((key, _) => key == 'Tarjeta');
    }

    if (filteredMethods.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = filteredMethods.values.fold(0, (prev, e) => prev + e);

    final colorMap = <String, Color>{
      'Efectivo': Colors.green,
      'Transferencia': Colors.blue,
      'Tarjeta': Colors.orange,
      'Mixto': Colors.purple,
    };

    final defaultColor = Colors.grey;
    final sections = <PieChartSectionData>[];
    final legendItems = <_PieLegendItem>[];

    for (final entry in filteredMethods.entries) {
      final color = colorMap[entry.key] ?? defaultColor;
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;
      sections.add(
        PieChartSectionData(
          value: entry.value.toDouble(),
          color: color,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      legendItems.add(_PieLegendItem(
        label: '${entry.key} (${entry.value})',
        color: color,
      ));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Métodos de Pago',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: legendItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(item.label, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Font size adaptativo: números más largos = font más chico
  double _adaptiveFontSize(String value) {
    final len = value.length;
    if (len <= 6) return 20;
    if (len <= 8) return 17;
    if (len <= 10) return 15;
    if (len <= 12) return 13;
    return 11;
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String description) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Contenido centrado
            Column(
              children: [
                const SizedBox(height: 2),
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: _adaptiveFontSize(value), fontWeight: FontWeight.w900, color: Colors.black87, height: 1.1)),
                const SizedBox(height: 2),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
              ],
            ),
            // Info icon en esquina superior derecha
            Positioned(
              top: -4,
              right: -4,
              child: GestureDetector(
                onTap: () => _showKpiInfo(title, description),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showKpiInfo(String title, String description) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(description, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _saleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: sale.totalAmount >= 0 ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            sale.totalAmount >= 0 ? Icons.trending_up : Icons.trending_down,
            color: sale.totalAmount >= 0 ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text('\$${sale.totalAmount.toStringAsFixed(2)}'),
        subtitle: Text(
          '${DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate)}\n${sale.paymentMethod}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (sale.discountAmount > 0)
              Text(
                '-\$${sale.discountAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            if (sale.commissionAmount > 0)
              Text(
                '\$${sale.commissionAmount.toStringAsFixed(2)} comision',
                style: TextStyle(fontSize: 11, color: Colors.teal.shade400),
              ),
          ],
        ),
      ),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String description;
  const _KpiItem(this.title, this.value, this.icon, this.color, this.description);
}

class _PieLegendItem {
  final String label;
  final Color color;
  const _PieLegendItem({required this.label, required this.color});
}
