import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:intl/intl.dart';

class AdjustmentsHistoryScreen extends StatefulWidget {
  final String? initialProductId;
  const AdjustmentsHistoryScreen({super.key, this.initialProductId});

  @override
  State<AdjustmentsHistoryScreen> createState() => _AdjustmentsHistoryScreenState();
}

class _AdjustmentsHistoryScreenState extends State<AdjustmentsHistoryScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<StockAdjustment> _adjustments = [];
  Map<String, String> _productNames = {};
  bool _isLoading = true;

  String _productFilter = '';
  String? _selectedProductId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _typeFilter = 'all';

  int _page = 0;
  static const int _pageSize = 30;
  bool _hasMore = true;

  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yy HH:mm');

  /// Formatea cantidad respetando decimales (1.5 -> "1.5", 2.0 -> "2")
  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialProductId != null) {
      _selectedProductId = widget.initialProductId;
    }
    _loadAdjustments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdjustments({bool resetPage = true}) async {
    if (resetPage) {
      setState(() { _isLoading = true; _page = 0; _hasMore = true; });
    }

    final db = AppDatabase.instance;
    final results = await db.getStockAdjustments(
      productId: _selectedProductId,
      adjustmentType: _typeFilter == 'all' ? null : _typeFilter,
      dateFrom: _dateFrom,
      dateTo: _dateTo != null ? DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59) : null,
      limit: _pageSize + 1,
    );

    _hasMore = results.length > _pageSize;
    final display = _hasMore ? results.sublist(0, _pageSize) : results;

    for (final adj in display) {
      if (!_productNames.containsKey(adj.productId)) {
        final p = await db.getProductById(adj.productId);
        _productNames[adj.productId] = p?.name ?? 'Desconocido';
      }
    }

    setState(() {
      if (resetPage) {
        _adjustments = display;
      } else {
        _adjustments.addAll(display);
      }
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _page++;
    final db = AppDatabase.instance;
    final offset = _page * _pageSize;
    final results = await db.getStockAdjustments(
      productId: _selectedProductId,
      adjustmentType: _typeFilter == 'all' ? null : _typeFilter,
      dateFrom: _dateFrom,
      dateTo: _dateTo != null ? DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59) : null,
      limit: _pageSize + 1,
    );

    _hasMore = results.length > _pageSize;
    final display = _hasMore ? results.sublist(0, _pageSize) : results;

    for (final adj in display) {
      if (!_productNames.containsKey(adj.productId)) {
        final p = await db.getProductById(adj.productId);
        _productNames[adj.productId] = p?.name ?? 'Desconocido';
      }
    }

    setState(() {
      _adjustments.addAll(display);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Historial de Ajustes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    _productFilter = v;
                  },
                  onSubmitted: (_) => _applyProductFilter(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Aplicar filtro',
                onPressed: _applyProductFilter,
              ),
              if (_selectedProductId != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Quitar filtro producto',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedProductId = null;
                      _productFilter = '';
                    });
                    _loadAdjustments();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ?? DateTime.now(),
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateFrom = picked);
                      _loadAdjustments();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: 'Desde',
                      prefixIcon: const Icon(Icons.calendar_today, size: 14),
                    ),
                    child: Text(
                      _dateFrom != null ? DateFormat('dd/MM/yy').format(_dateFrom!) : '-',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dateTo = picked);
                      _loadAdjustments();
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      labelText: 'Hasta',
                      prefixIcon: const Icon(Icons.calendar_today, size: 14),
                    ),
                    child: Text(
                      _dateTo != null ? DateFormat('dd/MM/yy').format(_dateTo!) : '-',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<String>(
                  value: _typeFilter,
                  isDense: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    labelText: 'Tipo',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todos')),
                    DropdownMenuItem(value: 'add', child: Text('Agregar')),
                    DropdownMenuItem(value: 'remove', child: Text('Quitar')),
                    DropdownMenuItem(value: 'bulk', child: Text('Físico')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _typeFilter = v);
                      _loadAdjustments();
                    }
                  },
                ),
              ),
            ],
          ),
          if (_dateFrom != null || _dateTo != null || _selectedProductId != null || _typeFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedProductId = null;
                      _productFilter = '';
                      _dateFrom = null;
                      _dateTo = null;
                      _typeFilter = 'all';
                    });
                    _loadAdjustments();
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Limpiar filtros', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _applyProductFilter() async {
    if (_productFilter.isEmpty) {
      setState(() => _selectedProductId = null);
      _loadAdjustments();
      return;
    }
    final db = AppDatabase.instance;
    final products = await db.getAllProducts();
    final match = products.where((p) => p.name.toLowerCase().contains(_productFilter.toLowerCase())).firstOrNull;
    if (match != null) {
      setState(() => _selectedProductId = match.id);
      _loadAdjustments();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto no encontrado'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_adjustments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tune, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Sin ajustes', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _adjustments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _adjustments.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: OutlinedButton(
                onPressed: _loadMore,
                child: const Text('Cargar más'),
              ),
            ),
          );
        }

        final adj = _adjustments[index];
        final isAdd = adj.adjustmentType == 'add' || (adj.adjustmentType == 'bulk' && adj.quantity > 0);
        final name = _productNames[adj.productId] ?? '...';
        final typeLabel = adj.adjustmentType == 'bulk' ? 'Físico' : (isAdd ? 'Agregar' : 'Quitar');
        final color = isAdd ? Colors.green : Colors.red;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: Icon(
              isAdd ? Icons.add_circle : Icons.remove_circle,
              color: color,
              size: 22,
            ),
            title: Text(
              '$name — ${_fmtQty(adj.quantity)} u',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$typeLabel${adj.reason != null ? ' — ${adj.reason}' : ''} — ${_dateFormat.format(adj.adjustedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}
