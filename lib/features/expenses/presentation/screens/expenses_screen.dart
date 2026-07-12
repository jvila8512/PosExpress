import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/shared.dart';
import 'package:etecsa/features/expenses/presentation/screens/expense_form_screen.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';

/// Category display config
const Map<String, _CatInfo> _categoryConfig = {
  'Transporte': _CatInfo(Icons.local_shipping, Colors.orange),
  'Alimentación': _CatInfo(Icons.restaurant, Colors.amber),
  'Construcción/Reparaciones': _CatInfo(Icons.build, Colors.brown),
  'Inversiones (equipos, neveras)': _CatInfo(Icons.kitchen, Colors.indigo),
  'Pago a trabajadores': _CatInfo(Icons.people, Colors.teal),
  'Tributos': _CatInfo(Icons.account_balance, Colors.red),
  'Otros': _CatInfo(Icons.category, Colors.grey),
};

class _CatInfo {
  final IconData icon;
  final Color color;
  const _CatInfo(this.icon, this.color);
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late DateTime _fromDate;
  late DateTime _toDate;
  List<Expense> _expenses = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  double _totalExpenses = 0;
  Map<String, double> _byCategory = {};
  String _userRole = '';
  final _currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day + 1);
    _loadUserRole().then((_) => _loadExpenses());
  }

  Future<void> _loadUserRole() async {
    final role = await KeyValueStorageService().getValue('user_role');
    if (mounted) setState(() => _userRole = role ?? '');
  }

  bool get _isVendedor => _userRole == 'vendedor';

  String get _rangeLabel {
    if (_isRangeThisMonth) return 'Este mes';
    if (_isRangeToday) return 'Hoy';
    if (_isRangeYesterday) return 'Ayer';
    if (_isRangeThisWeek) return 'Semana';
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

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    try {
      final db = AppDatabase.instance;
      _expenses = await db.getExpensesByDateRange(_fromDate, _toDate);
      _totalExpenses = 0;
      for (final e in _expenses) {
        _totalExpenses += e.amount;
      }
      _byCategory = await db.getExpensesByCategory(_fromDate, _toDate);

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
          break;
        case 'yesterday':
          final y = now.subtract(const Duration(days: 1));
          _fromDate = DateTime(y.year, y.month, y.day);
          _toDate = DateTime(y.year, y.month, y.day + 1);
          break;
        case 'week':
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _fromDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _toDate = DateTime(now.year, now.month, now.day + 1);
          break;
        case 'month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = DateTime(now.year, now.month, now.day + 1);
          break;
      }
    });
  }

  Future<void> _showDateFilterModal() async {
    DateTime tempFrom = _fromDate;
    DateTime tempTo = _toDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Seleccionar período', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _chip('Hoy', 'today', tempFrom, tempTo, setModalState, (f, t) { tempFrom = f; tempTo = t; }),
                  _chip('Ayer', 'yesterday', tempFrom, tempTo, setModalState, (f, t) { tempFrom = f; tempTo = t; }),
                  _chip('Semana', 'week', tempFrom, tempTo, setModalState, (f, t) { tempFrom = f; tempTo = t; }),
                  _chip('Mes', 'month', tempFrom, tempTo, setModalState, (f, t) { tempFrom = f; tempTo = t; }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx, initialDate: tempFrom,
                          firstDate: DateTime(2024), lastDate: DateTime.now(),
                        );
                        if (picked != null) setModalState(() => tempFrom = DateTime(picked.year, picked.month, picked.day));
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Desde ${DateFormat('dd/MM/yyyy').format(tempFrom)}', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('a')),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx, initialDate: tempTo.subtract(const Duration(days: 1)),
                          firstDate: tempFrom, lastDate: DateTime.now(),
                        );
                        if (picked != null) setModalState(() => tempTo = DateTime(picked.year, picked.month, picked.day + 1));
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Hasta ${DateFormat('dd/MM/yyyy').format(tempTo.subtract(const Duration(days: 1)))}', overflow: TextOverflow.ellipsis),
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
                    _loadExpenses();
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

  Widget _chip(String label, String range, DateTime currentFrom, DateTime currentTo, void Function(void Function()) setModalState, void Function(DateTime, DateTime) onSelect) {
    final now = DateTime.now();
    bool isSelected;
    switch (range) {
      case 'today':
        isSelected = currentFrom == DateTime(now.year, now.month, now.day) && currentTo == DateTime(now.year, now.month, now.day + 1);
        break;
      case 'yesterday':
        final y = now.subtract(const Duration(days: 1));
        isSelected = currentFrom == DateTime(y.year, y.month, y.day) && currentTo == DateTime(y.year, y.month, y.day + 1);
        break;
      case 'week':
        final ws = now.subtract(Duration(days: now.weekday - 1));
        isSelected = currentFrom == DateTime(ws.year, ws.month, ws.day);
        break;
      case 'month':
        isSelected = currentFrom == DateTime(now.year, now.month, 1) && currentTo == DateTime(now.year, now.month, now.day + 1);
        break;
      default:
        isSelected = false;
    }
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      onSelected: (_) {
        setModalState(() {
          final n = DateTime.now();
          switch (range) {
            case 'today':
              onSelect(DateTime(n.year, n.month, n.day), DateTime(n.year, n.month, n.day + 1));
              break;
            case 'yesterday':
              final y = n.subtract(const Duration(days: 1));
              onSelect(DateTime(y.year, y.month, y.day), DateTime(y.year, y.month, y.day + 1));
              break;
            case 'week':
              final ws = n.subtract(Duration(days: n.weekday - 1));
              onSelect(DateTime(ws.year, ws.month, ws.day), DateTime(n.year, n.month, n.day + 1));
              break;
            case 'month':
              onSelect(DateTime(n.year, n.month, 1), DateTime(n.year, n.month, n.day + 1));
              break;
          }
        });
      },
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar gasto'),
        content: Text('¿Eliminar "${expense.description}" (\$${expense.amount.toStringAsFixed(2)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
        ],
      ),
    );
    if (confirmed == true) {
      await AppDatabase.instance.deleteExpense(expense.id);
      _loadExpenses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Gastos'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_hasLoaded)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadExpenses,
              tooltip: 'Actualizar',
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
                      Icon(Icons.receipt_long_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('Cargando gastos...', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadExpenses,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Range chip
                      GestureDetector(
                        onTap: _showDateFilterModal,
                        child: Card(
                          color: colors.primaryContainer.withValues(alpha: 0.5),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, size: 20, color: colors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_rangeLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
                                ),
                                Icon(Icons.edit_calendar, size: 18, color: colors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // KPI: Total
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.orange, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Gastos', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                                  const SizedBox(height: 4),
                                  Text(_currencyFormat.format(_totalExpenses), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                  Text('${_expenses.length} registros', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_byCategory.isNotEmpty) ...[
                        // Por categoría
                        Text('Gastos por Categoría', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.onSurface)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 1,
                          child: Column(
                            children: _byCategory.entries.map((e) {
                              final config = _categoryConfig[e.key] ?? const _CatInfo(Icons.category, Colors.grey);
                              final pct = _totalExpenses > 0 ? (e.value / _totalExpenses) * 100 : 0.0;
                              return ListTile(
                                leading: Icon(config.icon, color: config.color, size: 22),
                                title: Text(e.key, style: const TextStyle(fontSize: 14)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_currencyFormat.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (_expenses.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('No hay gastos en este período')),
                          ),
                        )
                      else ...[
                        // Lista de gastos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Últimos Gastos (${_expenses.length})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.onSurface)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._expenses.map((expense) => _expenseCard(expense)),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
          );
          if (result == true) _loadExpenses();
        },
        tooltip: 'Nuevo Gasto',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _expenseCard(Expense expense) {
    final config = _categoryConfig[expense.category] ?? const _CatInfo(Icons.category, Colors.grey);
    final dateStr = DateFormat('dd/MM/yyyy').format(expense.expenseDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onLongPress: () => _deleteExpense(expense),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: config.color.withValues(alpha: 0.15),
            child: Icon(config.icon, color: config.color, size: 20),
          ),
          title: Text(expense.description, style: const TextStyle(fontSize: 14)),
          subtitle: Text('$dateStr  •  ${expense.category}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${expense.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (expense.notes != null && expense.notes!.isNotEmpty)
                Text(expense.notes!, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
          onTap: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: expense)),
            );
            if (result == true) _loadExpenses();
          },
        ),
      ),
    );
  }
}
