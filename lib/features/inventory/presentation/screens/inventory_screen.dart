import 'package:flutter/material.dart';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:go_router/go_router.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late TabController _tabController;

  bool _isLoading = true;
  List<Product> _products = [];
  List<Map<String, dynamic>> _inventoryData = [];
  List<Map<String, dynamic>> _allInventoryData = [];
  List<PurchaseInvoice> _monthlyInvoices = [];
  final Map<int, List<PurchaseInvoiceItem>> _invoiceItemsCache = {};
  String _searchQuery = '';
  String _purchaseSearchQuery = '';
  String _shopSearchQuery = '';
  String _adjustSearchQuery = '';
  bool _showBulkAdjust = false;
  final Map<String, TextEditingController> _realQtyControllers = {};
  int _purchasePage = 0;
  DateTime _purchaseFrom = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _purchaseTo = DateTime.now();
  static const int _purchasePageSize = 20;

  // Carrito de compra
  final List<_CartItem> _cart = [];
  bool _showCartView = false;
  bool _isPurchasing = false;

  // Warehouse mode
  bool _warehouseMode = false;
  String _selectedLocation = 'pv';

  // Controllers para edición en carrito (persistentes para no perder focus)
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _costControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  TextEditingController _getQtyController(String productId) {
    return _qtyControllers.putIfAbsent(productId, () {
      final item = _cart.where((i) => i.product.id == productId).firstOrNull;
      return TextEditingController(text: _fmtQty(item?.quantity ?? 1));
    });
  }

  /// Formatea cantidad respetando decimales (1.5 -> "1.5", 2.0 -> "2")
  String _fmtQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  TextEditingController _getCostController(String productId) {
    return _costControllers.putIfAbsent(productId, () {
      final item = _cart.where((i) => i.product.id == productId).firstOrNull;
      return TextEditingController(
        text: (item?.costPerUnit ?? 0).toStringAsFixed(2),
      );
    });
  }

  FocusNode _getFocusNode(String productId) {
    return _focusNodes.putIfAbsent(productId, () => FocusNode());
  }

  void _disposeCartControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final c in _costControllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    _qtyControllers.clear();
    _costControllers.clear();
    _focusNodes.clear();
  }

  int get _cartItemCount => _cart.length;
  double get _cartTotal => _cart.fold<double>(
    0,
    (sum, item) => sum + (item.quantity * item.costPerUnit),
  );

  bool _allInCart(List<Product> products) {
    if (products.isEmpty) return false;
    return products.every((p) => _cart.any((item) => item.product.id == p.id));
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _initWarehouseMode();
  }

  Future<void> _initWarehouseMode() async {
    final storage = KeyValueStorageService();
    final mode = await storage.getValue('warehouse_mode_enabled') == 'true';
    setState(() {
      _warehouseMode = mode;
      _selectedLocation = mode ? 'almacen' : 'pv';
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _disposeCartControllers();
    for (final c in _realQtyControllers.values) {
      c.dispose();
    }
    _realQtyControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = AppDatabase.instance;
    _products = await db.getAllProducts();
    await _loadInventory();
    await _loadInvoices();
  }

  Future<void> _loadInventory() async {
    final db = AppDatabase.instance;

    // Batch query: un solo SELECT para todos los productos (antes N+1)
    final allLots = await db.getActiveLotsForProducts(
      _products.map((p) => p.id).toList(),
      location: _warehouseMode ? _selectedLocation : null,
    );

    // Agrupar lotes por producto
    final lotsByProduct = <String, List<InventoryLot>>{};
    for (final lot in allLots) {
      lotsByProduct.putIfAbsent(lot.productId, () => []).add(lot);
    }

    final inventory = <String, Map<String, dynamic>>{};

    for (final p in _products) {
      final lots = lotsByProduct[p.id] ?? [];

      double totalQty = 0;
      double totalValue = 0;

      for (final lot in lots) {
        totalQty += lot.remainingQuantity;
        totalValue += lot.remainingQuantity * lot.costPerUnit;
      }

      final avgCost = totalQty > 0 ? totalValue / totalQty : p.costPrice;

      inventory[p.id] = {
        'product': p,
        'quantity': totalQty,
        'avgCost': avgCost,
        'totalValue': totalValue,
        'lots': lots,
      };
    }

    var allDataList = inventory.values.toList();

    // Ordenar alfabéticamente por nombre de producto
    allDataList.sort(
      (a, b) => (a['product'] as Product).name.toLowerCase().compareTo(
        (b['product'] as Product).name.toLowerCase(),
      ),
    );

    _allInventoryData = allDataList;
    _filterInventory();
  }

  void _filterInventory() {
    if (_searchQuery.trim().isEmpty) {
      setState(() {
        _inventoryData = _allInventoryData;
        _isLoading = false;
      });
      return;
    }

    final q = _searchQuery.trim().toLowerCase();
    final filtered = _allInventoryData
        .where(
          (d) =>
              (d['product'] as Product).name.toLowerCase().contains(q) ||
              ((d['product'] as Product).code?.toLowerCase().contains(q) ?? false),
        )
        .toList();

    setState(() {
      _inventoryData = filtered;
      _isLoading = false;
    });
  }

  Future<void> _loadInvoices() async {
    final db = AppDatabase.instance;
    final invoices = await db.getInvoicesByDateRange(
      from: _purchaseFrom,
      to: _purchaseTo,
    );

    setState(() {
      _monthlyInvoices = invoices;
      _invoiceItemsCache.clear();
      _purchasePage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        bottom: _warehouseMode
            ? PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Column(
                  children: [
                    // Location selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'almacen',
                            label: Text('Almacén'),
                            icon: Icon(Icons.warehouse, size: 18),
                          ),
                          ButtonSegment(
                            value: 'pv',
                            label: Text('PV'),
                            icon: Icon(Icons.store, size: 18),
                          ),
                        ],
                        selected: {_selectedLocation},
                        onSelectionChanged: (Set<String> selected) {
                          if (selected.isNotEmpty) {
                            setState(() => _selectedLocation = selected.first);
                            _loadInventory();
                          }
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    // Tab bar
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      indicatorColor: Colors.white,
                      tabs: const [
                        Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Stock'),
                        Tab(icon: Icon(Icons.shopping_cart, size: 18), text: 'Compra'),
                        Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Compras'),
                        Tab(icon: Icon(Icons.tune, size: 18), text: 'Ajustes'),
                      ],
                    ),
                  ],
                ),
              )
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(icon: Icon(Icons.inventory_2, size: 18), text: 'Stock'),
                  Tab(icon: Icon(Icons.shopping_cart, size: 18), text: 'Compra'),
                  Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Compras'),
                  Tab(icon: Icon(Icons.tune, size: 18), text: 'Ajustes'),
                ],
              ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockTab(),
          _buildPurchaseTab(),
          _buildMonthlyPurchasesTab(),
          _buildAdjustTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await context.push('/products/new');
                if (result == true) _loadData();
              },
              icon: const Icon(Icons.add),
              label: const Text('Producto'),
              backgroundColor: AppTheme.colorMorado,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildStockTab() {
    final totalValue = _inventoryData.fold<double>(
      0,
      (sum, d) => sum + (d['totalValue'] as double),
    );
    final totalValueSale = _inventoryData.fold<double>(
      0,
      (sum, d) =>
          sum +
          ((d['quantity'] as double) * (d['product'] as Product).unitPrice),
    );

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar producto...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterInventory();
            },
          ),
        ),

        // Botón de valoración de inventario
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  _showValuationBottomSheet(totalValue, totalValueSale),
              icon: Icon(Icons.assessment, size: 18, color: AppTheme.colorCeleste),
              label: Text(
                'Valoración de Inventario',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.colorCeleste,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.colorCeleste.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
        ),

        // Botón de transferencia (solo cuando almacén está activo)
        if (_warehouseMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showTransferDialog(),
                icon: Icon(Icons.swap_horiz, size: 18, color: Colors.orange),
                label: Text(
                  'Transferir Almacén → PV',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          ),

        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _inventoryData.isEmpty
              ? const Center(child: Text('Sin inventario'))
              : ListView.builder(
                  itemCount: _inventoryData.length,
                  itemBuilder: (context, index) {
                    final data = _inventoryData[index];
                    final product = data['product'] as Product;
                    final qty = data['quantity'] as double;
                    final value = data['totalValue'] as double;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: qty > 0 ? Colors.green : Colors.red,
                          child: Text(
                            _fmtQty(qty),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(product.name),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Venta: ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '\$${(qty * product.unitPrice).toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.colorMorado,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Costo: ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  '\$${value.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _showProductLots(product),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPurchaseTab() {
    if (_showCartView) return _buildCartView();

    // Mapa de stock por producto
    final stockMap = <String, double>{};
    for (final d in _inventoryData) {
      final product = d['product'] as Product;
      stockMap[product.id] = d['quantity'] as double;
    }

    // Filtrar por búsqueda y ordenar alfabéticamente
    var filteredProducts = _products;
    if (_shopSearchQuery.trim().isNotEmpty) {
      final q = _shopSearchQuery.trim().toLowerCase();
      filteredProducts = _products
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                (p.code?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    filteredProducts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return Column(
      children: [
        // Buscador + Select All
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (value) =>
                      setState(() => _shopSearchQuery = value),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: _allInCart(filteredProducts) ? 'Quitar todos del carrito' : 'Agregar todos al carrito',
                child: InkWell(
                  onTap: () {
                    if (_allInCart(filteredProducts)) {
                      // Quitar todos los filtrados del carrito
                      final ids = filteredProducts.map((p) => p.id).toSet();
                      _cart.removeWhere((item) => ids.contains(item.product.id));
                      _disposeCartControllers();
                    } else {
                      // Agregar todos los filtrados al carrito
                      for (final p in filteredProducts) {
                        final existing = _cart
                            .where((item) => item.product.id == p.id)
                            .firstOrNull;
                        if (existing == null) {
                          _cart.add(
                            _CartItem(
                              product: p,
                              quantity: 0,
                              costPerUnit: p.costPrice > 0 ? p.costPrice : 0,
                            ),
                          );
                        }
                      }
                    }
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _allInCart(filteredProducts) ? Colors.red : AppTheme.colorMorado,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _allInCart(filteredProducts) ? Icons.deselect : Icons.select_all,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sin resultados',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final stock = stockMap[product.id] ?? 0.0;
                    final isInCart = _cart.any(
                      (item) => item.product.id == product.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: isInCart
                          ? AppTheme.colorMorado.withValues(alpha: 0.08)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isInCart
                            ? BorderSide(
                                color: AppTheme.colorMorado,
                                width: 1.5,
                              )
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          backgroundColor: stock > 0
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Text(
                            _fmtQty(stock),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: stock > 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ),
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Costo ref: \$${product.costPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Compra rápida
                            IconButton(
                              icon: const Icon(Icons.flash_on, size: 20),
                              tooltip: 'Compra rápida',
                              onPressed: () => _showPurchaseDialog(product),
                              style: IconButton.styleFrom(
                                foregroundColor: AppTheme.colorCeleste,
                              ),
                            ),
                            // Al carrito
                            IconButton(
                              icon: const Icon(
                                Icons.add_shopping_cart,
                                size: 20,
                              ),
                              tooltip: 'Agregar al carrito',
                              onPressed: () => _addToCart(product),
                              style: IconButton.styleFrom(
                                foregroundColor: AppTheme.colorMorado,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Barra inferior: ir al carrito
        if (_cart.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.colorMorado,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_cartItemCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Compra',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$_cartItemCount producto${_cartItemCount != 1 ? "s" : ""} · \$${_cartTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showCartView = true),
                  icon: const Icon(Icons.shopping_cart, size: 18),
                  label: const Text('Ver carrito'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.colorMorado,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCartView() {
    return Column(
      children: [
        // Header: Carrito + total + items count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.colorMorado.withValues(alpha: 0.05),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carrito  ·  ${_cart.length} item${_cart.length != 1 ? "s" : ""}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Total: \$${_cartTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.colorMorado,
                ),
              ),
            ],
          ),
        ),

        // Lista de items
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_shopping_cart,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    final qtyController = _getQtyController(item.product.id);
                    final costController = _getCostController(item.product.id);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Fila 1: nombre + eliminar
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  color: Colors.red,
                                  onPressed: () {
                                    setState(() {
                                      _qtyControllers
                                          .remove(item.product.id)
                                          ?.dispose();
                                      _costControllers
                                          .remove(item.product.id)
                                          ?.dispose();
                                      _focusNodes
                                          .remove(item.product.id)
                                          ?.dispose();
                                      _cart.removeAt(index);
                                    });
                                  },
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Fila 2: cantidad + costo unitario
                            Row(
                              children: [
                                const Text(
                                  'Cant: ',
                                  style: TextStyle(fontSize: 11),
                                ),
                                SizedBox(
                                  width: 55,
                                  child: TextField(
                                    controller: qtyController,
                                    focusNode: _getFocusNode(
                                      '${item.product.id}_qty',
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (value) {
                                      final qty = double.tryParse(value) ?? 0;
                                      if (qty > 0) {
                                        setState(() => item.quantity = qty);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Costo/u: ',
                                  style: TextStyle(fontSize: 11),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: TextField(
                                    controller: costController,
                                    focusNode: _getFocusNode(
                                      '${item.product.id}_cost',
                                    ),
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6,
                                      ),
                                      border: OutlineInputBorder(),
                                      prefixText: '\$',
                                    ),
                                    onChanged: (value) {
                                      final cost = double.tryParse(value) ?? 0;
                                      if (cost >= 0) {
                                        setState(() => item.costPerUnit = cost);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Fila 3: subtotal
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Subtotal: \$${item.total.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.colorMorado,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer: dos botones que ocupan todo el ancho
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isPurchasing
                        ? null
                        : () => setState(() => _showCartView = false),
                    icon: const Icon(Icons.arrow_back, size: 20),
                    label: const Text('Seguir comprando', style: TextStyle(fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.colorMorado,
                      side: BorderSide(color: AppTheme.colorMorado),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _isPurchasing
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.green),
                        ),
                      )
                    : SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _cart.isEmpty ? null : _confirmPurchase,
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Confirmar compra', style: TextStyle(fontSize: 14)),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyPurchasesTab() {
    final dateFormat = DateFormat('dd/MM/yy');

    // Filtrar facturas por búsqueda (busca en número de factura, proveedor, o items)
    var filtered = _monthlyInvoices;
    if (_purchaseSearchQuery.trim().isNotEmpty) {
      final query = _purchaseSearchQuery.trim().toLowerCase();
      filtered = filtered.where((inv) {
        if (inv.invoiceNumber.toLowerCase().contains(query)) return true;
        if ((inv.supplier ?? '').toLowerCase().contains(query)) return true;
        // También buscar en items cacheados
        final items = _invoiceItemsCache[inv.id];
        if (items != null) {
          for (final item in items) {
            if (item.productName.toLowerCase().contains(query)) return true;
          }
        }
        return false;
      }).toList();
    }

    // Paginación
    final totalPages = (filtered.length / _purchasePageSize).ceil();
    final start = _purchasePage * _purchasePageSize;
    final end = (start + _purchasePageSize > filtered.length)
        ? filtered.length
        : start + _purchasePageSize;
    final pageItems = start < filtered.length
        ? filtered.sublist(start, end)
        : <PurchaseInvoice>[];

    // Totales
    final totalCost = _monthlyInvoices.fold<double>(
      0,
      (sum, inv) => sum + inv.totalAmount,
    );
    final totalInvoices = _monthlyInvoices.length;

    return Column(
      children: [
        // Header: filtro de fechas + totales
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _purchaseFrom,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _purchaseFrom = picked);
                          _loadInvoices();
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                          labelText: 'Desde',
                        ),
                        child: Text(dateFormat.format(_purchaseFrom), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _purchaseTo,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => _purchaseTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                          _loadInvoices();
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                          labelText: 'Hasta',
                        ),
                        child: Text(dateFormat.format(_purchaseTo), style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final now = DateTime.now();
                    setState(() {
                      _purchaseFrom = DateTime(now.year, now.month, 1);
                      _purchaseTo = DateTime(now.year, now.month, now.day, 23, 59, 59);
                    });
                    _loadInvoices();
                  },
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: const Text('Este mes'),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('$totalInvoices factura${totalInvoices != 1 ? "s" : ""}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  const SizedBox(width: 12),
                  Text(
                    '\$${totalCost.toStringAsFixed(0)} total',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.colorMorado),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Buscador
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar número de factura...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _purchaseSearchQuery = value;
                _purchasePage = 0;
              });
            },
          ),
        ),

        // Lista de facturas
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text('Sin facturas en el rango', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: pageItems.length,
                        itemBuilder: (context, index) {
                          final invoice = pageItems[index];
                          return _buildInvoiceCard(invoice, dateFormat);
                        },
                      ),
                    ),
                    // Paginación
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: _purchasePage > 0 ? () => setState(() => _purchasePage--) : null,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            Text('${_purchasePage + 1}/$totalPages', style: const TextStyle(fontSize: 12)),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              onPressed: _purchasePage < totalPages - 1 ? () => setState(() => _purchasePage++) : null,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(PurchaseInvoice invoice, DateFormat dateFormat) {
    final cachedItems = _invoiceItemsCache[invoice.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppTheme.colorCeleste.withValues(alpha: 0.15),
          child: Icon(Icons.receipt, size: 16, color: AppTheme.colorCeleste),
        ),
        title: Row(
          children: [
            Text(
              invoice.invoiceNumber,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 8),
            if (invoice.supplier != null && invoice.supplier!.isNotEmpty)
              Flexible(
                child: Text(
                  '- ${invoice.supplier}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              dateFormat.format(invoice.invoiceDate),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const Spacer(),
            Text(
              '\$${invoice.totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.colorMorado,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) async {
            try {
              String filePath;
              if (val == 'excel') {
                filePath = await ExportService.instance
                    .exportSingleInvoiceExcel(invoice);
              } else {
                filePath = await ExportService.instance.exportSingleInvoicePdf(
                  invoice,
                );
              }
              if (mounted) {
                ExportOptionsDialog.show(
                  context,
                  filePath: filePath,
                  shareText: 'Factura ${invoice.invoiceNumber}',
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'excel', child: Text('Exportar Excel')),
            const PopupMenuItem(value: 'pdf', child: Text('Exportar PDF')),
          ],
          icon: Icon(
            Icons.file_download,
            size: 18,
            color: AppTheme.colorCeleste,
          ),
        ),
        children: [
          FutureBuilder<List<PurchaseInvoiceItem>>(
            future: cachedItems != null
                ? Future.value(cachedItems)
                : _loadInvoiceItems(invoice.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Sin items',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${_fmtQty(item.quantity)} u × \$${item.costPerUnit.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        trailing: Text(
                          '\$${item.total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.colorMorado,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<PurchaseInvoiceItem>> _loadInvoiceItems(int invoiceId) async {
    if (_invoiceItemsCache.containsKey(invoiceId)) {
      return _invoiceItemsCache[invoiceId]!;
    }
    final db = AppDatabase.instance;
    final items = await db.getInvoiceItems(invoiceId);
    _invoiceItemsCache[invoiceId] = items;
    return items;
  }

  Widget _buildAdjustTab() {
    final allInventory = List<Map<String, dynamic>>.from(_inventoryData);
    allInventory.sort(
      (a, b) => (a['product'] as Product).name.toLowerCase().compareTo(
        (b['product'] as Product).name.toLowerCase(),
      ),
    );

    final filtered = allInventory.where((d) {
      if (_adjustSearchQuery.trim().isEmpty) return true;
      final q = _adjustSearchQuery.trim().toLowerCase();
      return (d['product'] as Product).name.toLowerCase().contains(q) ||
          ((d['product'] as Product).code?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (_showBulkAdjust) return _buildBulkAdjustView(allInventory);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar producto...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => _adjustSearchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Historial de ajustes',
                onPressed: () => context.push('/inventory/adjustments'),
              ),
            ],
          ),
        ),

        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.edit, color: AppTheme.colorMorado),
            title: const Text(
              'Ajuste Físico General',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Conteo físico de todos los productos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              for (final d in _inventoryData) {
                final p = d['product'] as Product;
                final qty = d['quantity'] as double;
                _realQtyControllers.putIfAbsent(
                  p.id,
                  () => TextEditingController(text: _fmtQty(qty)),
                );
              }
              setState(() => _showBulkAdjust = true);
            },
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Text(
                'Ajuste Individual',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Icon(Icons.touch_app, size: 16, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                'Tocá un producto',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No se encontraron productos'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index];
                    final product = data['product'] as Product;
                    final qty = data['quantity'] as double;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _showAdjustDialog(product),
                        title: Text(product.name),
                        subtitle: Text('Stock: ${_fmtQty(qty)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history, size: 20),
                              tooltip: 'Ver lotes',
                              onPressed: () => _showProductLots(product),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                size: 20,
                                color: Colors.green,
                              ),
                              tooltip: 'Agregar stock',
                              onPressed: () =>
                                  _showAdjustDialog(product, initialAdd: true),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle,
                                size: 20,
                                color: Colors.red,
                              ),
                              tooltip: 'Quitar stock',
                              onPressed: () =>
                                  _showAdjustDialog(product, initialAdd: false),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBulkAdjustView(List<Map<String, dynamic>> inventory) {
    final sorted = List<Map<String, dynamic>>.from(inventory)
      ..sort(
        (a, b) => (a['product'] as Product).name.toLowerCase().compareTo(
          (b['product'] as Product).name.toLowerCase(),
        ),
      );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.colorMorado.withValues(alpha: 0.05),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showBulkAdjust = false),
                style: IconButton.styleFrom(
                  foregroundColor: AppTheme.colorMorado,
                ),
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajuste Físico General',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ingresá el stock real contado',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _applyBulkAdjust,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colorMorado,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final d = sorted[index];
              final p = d['product'] as Product;
              final currentQty = d['quantity'] as double;
              final controller = _realQtyControllers.putIfAbsent(
                p.id,
                () => TextEditingController(text: _fmtQty(currentQty)),
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sist: ${_fmtQty(currentQty)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Real',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _applyBulkAdjust() async {
    final db = AppDatabase.instance;
    final adjustLocation = _warehouseMode ? _selectedLocation : 'pv';
    int adjusted = 0;

    for (final d in _inventoryData) {
      final p = d['product'] as Product;
      final currentQty = d['quantity'] as double;
      final controller = _realQtyControllers[p.id];
      if (controller == null) continue;
      final realQty = double.tryParse(controller.text) ?? currentQty;
      final diff = realQty - currentQty;

      if (diff.abs() < 0.01) continue;

      if (diff > 0) {
        await db.addInventoryLot(
          productId: p.id,
          quantity: diff,
          costPerUnit: p.costPrice,
          purchaseDate: DateTime.now(),
          location: adjustLocation,
        );
        await db.createStockAdjustment(
          productId: p.id,
          adjustmentType: 'bulk',
          quantity: diff,
          unitCost: p.costPrice,
          reason: 'Ajuste físico general (${_warehouseMode ? _selectedLocation.toUpperCase() : 'PV'})',
        );
      } else {
        try {
          await db.removeInventoryStock(
            productId: p.id,
            quantity: diff.abs(),
            location: adjustLocation,
            reference: 'Ajuste físico general (${_warehouseMode ? _selectedLocation.toUpperCase() : 'PV'})',
          );
          await db.createStockAdjustment(
            productId: p.id,
            adjustmentType: 'bulk',
            quantity: diff.abs(),
            reason: 'Ajuste físico general (${_warehouseMode ? _selectedLocation.toUpperCase() : 'PV'})',
          );
        } catch (_) {}
      }
      adjusted++;
    }

    if (mounted) {
      setState(() => _showBulkAdjust = false);
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ajuste físico completado: $adjusted productos ajustados',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildValuationMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _showProductLots(Product product) async {
    final db = AppDatabase.instance;
    final allLots = await db.getAllLots(product.id);
    final dateFormat = DateFormat('dd/MM/yy');
    final dateTimeFormat = DateFormat('dd/MM/yy HH:mm');

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final lots = allLots
        .where(
          (l) =>
              l.purchaseDate.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ) &&
              l.purchaseDate.isBefore(monthEnd.add(const Duration(seconds: 1))),
        )
        .toList();
    lots.sort((a, b) => a.purchaseDate.compareTo(b.purchaseDate));

    final adjustments = await db.getStockAdjustments(
      productId: product.id,
      dateFrom: monthStart,
      dateTo: monthEnd,
    );
    adjustments.sort((a, b) => a.adjustedAt.compareTo(b.adjustedAt));

    const int pageSize = 20;
    int currentPage = 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalPages = (lots.length / pageSize).ceil();
          final start = currentPage * pageSize;
          final end = (start + pageSize > lots.length)
              ? lots.length
              : start + pageSize;
          final pageLots = lots.sublist(start, end);

          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lotes del mes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: lots.isEmpty && adjustments.isEmpty
                  ? const Center(child: Text('Sin actividad este mes'))
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lots.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Compras: ${lots.length}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                      'Total: ${_fmtQty(lots.fold<double>(0, (sum, l) => sum + l.remainingQuantity))} u',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pageLots.length,
                              itemBuilder: (ctx, i) {
                                final lot = pageLots[i];
                                final globalIndex = start + i + 1;
                                final isSold = lot.remainingQuantity <= 0;

                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isSold
                                        ? Colors.grey.shade300
                                        : Colors.green.shade100,
                                    child: Text(
                                      '#$globalIndex',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSold
                                            ? Colors.grey.shade600
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${_fmtQty(lot.quantity)} u a \$${lot.costPerUnit.toStringAsFixed(2)}/u',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Text(
                                        dateFormat.format(lot.purchaseDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSold
                                              ? Colors.grey.shade200
                                              : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isSold
                                              ? 'Vendido'
                                              : '${_fmtQty(lot.remainingQuantity)} u restantes',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isSold
                                                ? Colors.grey.shade600
                                                : Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (totalPages > 1) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        size: 20,
                                      ),
                                      onPressed: currentPage > 0
                                          ? () => setDialogState(
                                              () => currentPage--,
                                            )
                                          : null,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    Text(
                                      '${currentPage + 1}/$totalPages',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        size: 20,
                                      ),
                                      onPressed: currentPage < totalPages - 1
                                          ? () => setDialogState(
                                              () => currentPage++,
                                            )
                                          : null,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                          if (adjustments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.tune,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ajustes del mes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${adjustments.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 1),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: adjustments.length,
                              itemBuilder: (ctx, i) {
                                final adj = adjustments[i];
                                final isAdd =
                                    adj.adjustmentType == 'add' ||
                                    (adj.adjustmentType == 'bulk' &&
                                        adj.quantity > 0);
                                final typeLabel = adj.adjustmentType == 'bulk'
                                    ? 'Físico'
                                    : (isAdd ? 'Agregar' : 'Quitar');
                                final color = isAdd ? Colors.green : Colors.red;

                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 2,
                                  ),
                                  leading: Icon(
                                    isAdd
                                        ? Icons.add_circle
                                        : Icons.remove_circle,
                                    color: color,
                                    size: 18,
                                  ),
                                  title: Text(
                                    '${_fmtQty(adj.quantity)} u - $typeLabel${adj.reason != null ? ' - ${adj.reason}' : ''}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  subtitle: Text(
                                    dateTimeFormat.format(adj.adjustedAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addToCart(Product product) {
    // Si ya está en el carrito, incrementar cantidad
    final existing = _cart
        .where((item) => item.product.id == product.id)
        .firstOrNull;
    if (existing != null) {
      setState(() => existing.quantity += 1);
      // Actualizar controller de cantidad si existe
      final ctrl = _qtyControllers[product.id];
      if (ctrl != null) ctrl.text = _fmtQty(existing.quantity);
    } else {
      setState(() {
        _cart.add(
          _CartItem(
            product: product,
            quantity: 1,
            costPerUnit: product.costPrice > 0 ? product.costPrice : 0,
          ),
        );
      });
    }
  }

  void _confirmPurchase() async {
    if (_cart.isEmpty) return;
    if (_isPurchasing) return; // prevenir doble clic

    final itemsToPurchase = _cart.where((item) => item.quantity > 0).toList();
    if (itemsToPurchase.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay productos con cantidad mayor a 0'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // 1. Mostrar diálogo de carga a pantalla completa (Opción A)
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black54,
          body: Center(
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 3),
                    SizedBox(height: 24),
                    Text(
                      'Procesando compra...',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Esto puede tardar unos segundos',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    setState(() => _isPurchasing = true);

    final db = AppDatabase.instance;
    final storage = KeyValueStorageService();
    final warehouseMode = await storage.getValue('warehouse_mode_enabled') == 'true';

    try {
      // 2. TODO en una sola transacción atómica (Opción B)
      late String invoiceNumber;
      await db.transaction(() async {
        for (final item in itemsToPurchase) {
          await db.addInventoryLot(
            productId: item.product.id,
            quantity: item.quantity,
            costPerUnit: item.costPerUnit,
            purchaseDate: DateTime.now(),
            location: warehouseMode ? 'almacen' : 'pv',
          );
        }

        invoiceNumber = await db.createPurchaseInvoice(
          items: itemsToPurchase
              .map(
                (item) => {
                  'productId': item.product.id,
                  'productName': item.product.name,
                  'quantity': item.quantity,
                  'costPerUnit': item.costPerUnit,
                  'total': item.total,
                },
              )
              .toList(),
          totalAmount: itemsToPurchase.fold(0.0, (sum, item) => sum + item.total),
        );
      }); // <-- acá se guarda TODO o nada

      if (!mounted) return;

      // 3. Cerrar diálogo de carga
      if (mounted) Navigator.of(context).pop();

      // Limpiar carrito y estado
      _disposeCartControllers();
      setState(() {
        _cart.clear();
        _showCartView = false;
        _isPurchasing = false;
      });
      // Actualizar rango de fechas para que incluya la compra reciente
      _purchaseTo = DateTime.now();
      await _loadData();
      await _loadInvoices();

      if (!mounted) return;

      // Ir directo al tab de Compras para ver la factura nueva
      _tabController.animateTo(2);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Factura #$invoiceNumber registrada'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // 4. Cerrar diálogo incluso si falla
      if (mounted) Navigator.of(context).pop();
      setState(() => _isPurchasing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar compra: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showPurchaseDialog(Product product) {
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(
      text: product.costPrice > 0 ? product.costPrice.toString() : '0',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool _purchasing = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('Comprar ${product.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  enabled: !_purchasing,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  enabled: !_purchasing,
                  decoration: const InputDecoration(
                    labelText: 'Costo unitario',
                    prefixText: '\$',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _purchasing ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: _purchasing ? null : () async {
                  final qty = double.tryParse(qtyController.text) ?? 0;
                  final cost = double.tryParse(costController.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('La cantidad debe ser mayor a 0'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  if (cost <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('El costo debe ser mayor a 0'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  setDialogState(() => _purchasing = true);

                  final db = AppDatabase.instance;
                  final storage = KeyValueStorageService();
                  final warehouseMode = await storage.getValue('warehouse_mode_enabled') == 'true';
                  try {
                    await db.addInventoryLot(
                      productId: product.id,
                      quantity: qty,
                      costPerUnit: cost,
                      purchaseDate: DateTime.now(),
                      location: warehouseMode ? 'almacen' : 'pv',
                    );

                    final invoiceNumber = await db.createPurchaseInvoice(
                      items: [
                        {
                          'productId': product.id,
                          'productName': product.name,
                          'quantity': qty,
                          'costPerUnit': cost,
                          'total': qty * cost,
                        },
                      ],
                      totalAmount: qty * cost,
                      supplier: 'Compra rápida',
                      notes: 'Compra individual',
                    );

                    if (!mounted) return;
                    Navigator.pop(ctx);

                    final total = qty * cost;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Comprado: $qty de ${product.name} - Factura #$invoiceNumber - \$${total.toStringAsFixed(0)}',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    await _loadInventory();
                    _purchaseTo = DateTime.now();
                    await _loadInvoices();
                    // Ir al tab de Compras para ver la factura nueva
                    _tabController.animateTo(2);
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al comprar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: _purchasing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Comprar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdjustDialog(Product product, {bool initialAdd = true}) {
    final qtyController = TextEditingController();
    final costController = TextEditingController(
      text: product.costPrice.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    bool isAdd = initialAdd;
    int? selectedLotId;
    bool createNewLot = true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ajustar ${product.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (ctx, setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Agregar',
                          style: TextStyle(color: Colors.white),
                        ),
                        selected: isAdd,
                        selectedColor: Colors.green,
                        onSelected: (s) => setState(() {
                          isAdd = true;
                          createNewLot = true;
                          selectedLotId = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text(
                          'Quitar',
                          style: TextStyle(color: Colors.white),
                        ),
                        selected: !isAdd,
                        selectedColor: Colors.red,
                        onSelected: (s) => setState(() {
                          isAdd = false;
                          createNewLot = false;
                          selectedLotId = null;
                        }),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(
                    isAdd ? Icons.add_circle : Icons.remove_circle,
                    color: isAdd ? Colors.green : Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (isAdd) ...[
                StatefulBuilder(
                  builder: (ctx, setState) {
                    return FutureBuilder<List<InventoryLot>>(
                      future: AppDatabase.instance.getActiveLots(product.id),
                      builder: (ctx, snap) {
                        final lots = snap.data ?? [];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agregar a:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: createNewLot,
                                  onChanged: (v) => setState(() {
                                    createNewLot = v!;
                                    selectedLotId = null;
                                  }),
                                ),
                                const Text('Nuevo lote'),
                              ],
                            ),
                            if (lots.isNotEmpty) ...[
                              Row(
                                children: [
                                  Radio<bool>(
                                    value: false,
                                    groupValue: createNewLot,
                                    onChanged: (v) => setState(() {
                                      createNewLot = false;
                                      selectedLotId = lots.first.id;
                                    }),
                                  ),
                                  const Text('Lote existente'),
                                ],
                              ),
                            ],
                            if (!createNewLot && lots.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              DropdownButtonFormField<int>(
                                initialValue: selectedLotId,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  labelText: 'Seleccionar lote',
                                ),
                                items: lots.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final lot = entry.value;
                                  final dateStr = DateFormat(
                                    'dd/MM/yy',
                                  ).format(lot.purchaseDate);
                                  return DropdownMenuItem(
                                    value: lot.id,
                                    child: Text('Lote #${i + 1} - $dateStr'),
                                  );
                                }).toList(),
                                onChanged: (v) =>
                                    setState(() => selectedLotId = v),
                              ),
                              if (selectedLotId != null) ...[
                                const SizedBox(height: 4),
                                Builder(
                                  builder: (context) {
                                    final lot = lots
                                        .where((l) => l.id == selectedLotId)
                                        .firstOrNull;
                                    if (lot == null)
                                      return const SizedBox.shrink();
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Stock: ${_fmtQty(lot.remainingQuantity)} u · Costo: \${lot.costPerUnit.toStringAsFixed(2)}/u',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                            if (createNewLot) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: costController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Costo unitario *',
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ] else ...[
                StatefulBuilder(
                  builder: (ctx, setState) {
                    return FutureBuilder<List<InventoryLot>>(
                      future: AppDatabase.instance.getActiveLots(product.id),
                      builder: (ctx, snap) {
                        final lots = snap.data ?? [];
                        if (lots.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No hay lotes con stock disponible',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        selectedLotId ??= lots.first.id;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quitar de:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<int>(
                              initialValue: selectedLotId,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                                labelText: 'Seleccionar lote',
                              ),
                              items: lots.asMap().entries.map((entry) {
                                final i = entry.key;
                                final lot = entry.value;
                                final dateStr = DateFormat(
                                  'dd/MM/yy',
                                ).format(lot.purchaseDate);
                                return DropdownMenuItem(
                                  value: lot.id,
                                   child: Text('Lote #${i + 1} - $dateStr'),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => selectedLotId = v),
                            ),
                            if (selectedLotId != null) ...[
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final lot = lots
                                      .where((l) => l.id == selectedLotId)
                                      .firstOrNull;
                                  if (lot == null)
                                    return const SizedBox.shrink();
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock: ${_fmtQty(lot.remainingQuantity)} u · Costo: \${lot.costPerUnit.toStringAsFixed(2)}/u',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Razón (opcional)',
                  prefixIcon: Icon(Icons.note),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cantidad debe ser mayor a 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final db = AppDatabase.instance;
              final reason = reasonController.text.trim().isEmpty
                  ? null
                  : reasonController.text.trim();

              try {
                if (isAdd) {
                  if (createNewLot) {
                    final cost = double.tryParse(costController.text) ?? 0;
                    if (cost <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El costo debe ser mayor a 0'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    await db.addInventoryLot(
                      productId: product.id,
                      quantity: qty,
                      costPerUnit: cost,
                      purchaseDate: DateTime.now(),
                      location: _warehouseMode ? _selectedLocation : 'pv',
                    );
                    await db.createStockAdjustment(
                      productId: product.id,
                      adjustmentType: 'add',
                      quantity: qty,
                      unitCost: cost,
                      reason: reason,
                    );
                  } else {
                    if (selectedLotId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Seleccioná un lote'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final cost = double.tryParse(costController.text) ?? 0;
                    await db.addStockToLot(
                      lotId: selectedLotId!,
                      quantity: qty,
                      unitCost: cost,
                      reason: reason,
                    );
                  }
                } else {
                  if (selectedLotId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No hay lotes disponibles'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  await db.removeStockFromLot(
                    lotId: selectedLotId!,
                    quantity: qty,
                    reason: reason,
                  );
                }

                if (!mounted) return;
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAdd ? 'Stock agregado' : 'Stock reducido'),
                    backgroundColor: isAdd ? Colors.green : Colors.orange,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAdd ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  void _showValuationBottomSheet(double totalValue, double totalValueSale) async {
    final db = AppDatabase.instance;
    final bool showBothLocations = _warehouseMode;

    // If warehouse mode, load both locations' data
    Map<String, dynamic>? almacenData;
    Map<String, dynamic>? pvData;

    if (showBothLocations) {
      // Load all products for both locations
      final products = await db.getAllProducts();
      final productIds = products.map((p) => p.id).toList();

      final almacenLots = await db.getActiveLotsForProducts(productIds, location: 'almacen');
      final pvLots = await db.getActiveLotsForProducts(productIds, location: 'pv');

      double almacenCost = 0, almacenVenta = 0;
      double pvCost = 0, pvVenta = 0;

      for (final lot in almacenLots) {
        final product = products.where((p) => p.id == lot.productId).firstOrNull;
        if (product != null) {
          almacenCost += lot.remainingQuantity * lot.costPerUnit;
          almacenVenta += lot.remainingQuantity * product.unitPrice;
        }
      }
      for (final lot in pvLots) {
        final product = products.where((p) => p.id == lot.productId).firstOrNull;
        if (product != null) {
          pvCost += lot.remainingQuantity * lot.costPerUnit;
          pvVenta += lot.remainingQuantity * product.unitPrice;
        }
      }

      almacenData = {'cost': almacenCost, 'venta': almacenVenta};
      pvData = {'cost': pvCost, 'venta': pvVenta};

      // Override totals with combined
      totalValue = almacenCost + pvCost;
      totalValueSale = almacenVenta + pvVenta;
    }

    final totalCosto = totalValue;
    final totalVenta = totalValueSale;
    final ganancia = totalVenta - totalCosto;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Calculamos detalle por producto para la lista
        final detailItems = List<Map<String, dynamic>>.from(_inventoryData);
        detailItems.sort(
          (a, b) => (a['product'] as Product).name.compareTo(
            (b['product'] as Product).name,
          ),
        );

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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
                  const SizedBox(height: 16),

                  // Título
                  Row(
                    children: [
                      Icon(
                        Icons.assessment,
                        color: AppTheme.colorCeleste,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Valoración de Inventario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.download,
                          color: AppTheme.colorCeleste,
                          size: 22,
                        ),
                        tooltip: 'Exportar',
                        onSelected: (value) async {
                          try {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Exportando...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            final filePath = value == 'excel'
                                ? await ExportService.instance
                                      .exportInventoryExcel()
                                : await ExportService.instance
                                      .exportInventoryPdf();
                            if (mounted) {
                              ExportOptionsDialog.show(
                                this.context,
                                filePath: filePath,
                                shareText: 'Informe de Inventario',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'excel',
                            child: Row(
                              children: [
                                Icon(Icons.table_chart, size: 20),
                                SizedBox(width: 8),
                                Text('Excel (.xlsx)'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'pdf',
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf, size: 20),
                                SizedBox(width: 8),
                                Text('PDF'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Métricas principales
                  Row(
                    children: [
                      _buildValuationMetric(
                        Icons.inventory,
                        '${_inventoryData.length}',
                        'Productos',
                        AppTheme.colorCeleste,
                      ),
                      _buildValuationMetric(
                        Icons.money_off,
                        '\$${totalCosto.toStringAsFixed(0)}',
                        'Costo total',
                        Colors.orange.shade700,
                      ),
                      _buildValuationMetric(
                        Icons.sell,
                        '\$${totalVenta.toStringAsFixed(0)}',
                        'Venta total',
                        Colors.green.shade700,
                      ),
                    ],
                  ),

                  // Warehouse breakdown
                  if (showBothLocations && almacenData != null && pvData != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warehouse, size: 16, color: Colors.blue.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Almacén',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Costo: \$${almacenData['cost'].toStringAsFixed(0)}  |  Venta: \$${almacenData['venta'].toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.store, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'PV',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Costo: \$${pvData['cost'].toStringAsFixed(0)}  |  Venta: \$${pvData['venta'].toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),
                  // Ganancia
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ganancia >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ganancia potencial: \$${ganancia.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: ganancia >= 0
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 20),

                  // Detalle por producto
                  Text(
                    'Detalle por producto',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: detailItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = detailItems[i];
                        final p = d['product'] as Product;
                        final qty = d['quantity'] as double;
                        final costo = d['totalValue'] as double;
                        final venta = qty * p.unitPrice;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  '${_fmtQty(qty)} und',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '\$${costo.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '\$${venta.toStringAsFixed(0)}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.colorMorado,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showValoracionReport() {
    final totalQty = _inventoryData.fold<double>(
      0,
      (sum, d) => sum + (d['quantity'] as double),
    );
    final totalCosto = _inventoryData.fold<double>(
      0,
      (sum, d) => sum + (d['totalValue'] as double),
    );
    final totalVenta = _inventoryData.fold<double>(
      0,
      (sum, d) =>
          sum +
          ((d['quantity'] as double) * (d['product'] as Product).unitPrice),
    );
    final ganancia = totalVenta - totalCosto;

    final buffer = StringBuffer();
    buffer.writeln('=====================================');
    buffer.writeln('INFORME DE VALORACIÓN');
    buffer.writeln('=====================================');
    buffer.writeln('');
    buffer.writeln('PRODUCTOS: ${_inventoryData.length}');
    buffer.writeln('UNIDADES: ${_fmtQty(totalQty)}');
    buffer.writeln('');
    buffer.writeln('VALOR EN COSTO: \$${totalCosto.toStringAsFixed(2)}');
    buffer.writeln('VALOR EN VENTA: \$${totalVenta.toStringAsFixed(2)}');
    buffer.writeln('GANANCIA POTENCIAL: \$${ganancia.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('----------------------------------------');
    buffer.writeln('DETALLE POR PRODUCTO:');
    buffer.writeln('----------------------------------------');

    for (final d in _inventoryData) {
      final p = d['product'] as Product;
      final qty = d['quantity'] as double;
      final costo = d['totalValue'] as double;
      final venta = qty * p.unitPrice;
      buffer.writeln(p.name);
      buffer.writeln(
        ' Stock: ${_fmtQty(qty)} | Costo: \$${costo.toStringAsFixed(2)} | Venta: \$${venta.toStringAsFixed(2)}',
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valoración de Inventario'),
        content: SingleChildScrollView(
          child: SelectableText(
            buffer.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Transfer dialog: move stock from Almacén to PV
  void _showTransferDialog() {
    final db = AppDatabase.instance;
    String? selectedProductId;
    double transferQty = 0;
    bool isTransferring = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Transferir Almacén → PV'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product selector
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: () async {
                    final products = await db.getAllProducts();
                    final result = <Map<String, dynamic>>[];
                    for (final p in products) {
                      final lots = await db.getActiveLotsForProducts(
                        [p.id],
                        location: 'almacen',
                      );
                      final qty = lots.fold<double>(0, (s, l) => s + l.remainingQuantity);
                      if (qty > 0) {
                        result.add({'product': p, 'quantity': qty});
                      }
                    }
                    return result;
                  }(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay stock en Almacén para transferir'),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Producto',
                        border: OutlineInputBorder(),
                      ),
                      isExpanded: true,
                      items: items.map((item) {
                        final p = item['product'] as Product;
                        final qty = item['quantity'] as double;
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.name} (Almacén: ${_fmtQty(qty)})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedProductId = value;
                          transferQty = 0;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Quantity input
                if (selectedProductId != null)
                  FutureBuilder<double>(
                    future: () async {
                      final lots = await db.getActiveLotsForProducts(
                        [selectedProductId!],
                        location: 'almacen',
                      );
                      return lots.fold<double>(0, (s, l) => s + l.remainingQuantity);
                    }(),
                    builder: (ctx, snapshot) {
                      final available = snapshot.data ?? 0;
                      return Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Cantidad a transferir',
                              border: const OutlineInputBorder(),
                              suffixText: 'Disponible: ${_fmtQty(available)}',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (value) {
                              transferQty = double.tryParse(value) ?? 0;
                            },
                          ),
                          const SizedBox(height: 8),
                          // Quick buttons
                          Wrap(
                            spacing: 8,
                            children: [
                              if (available > 0)
                                ActionChip(
                                  label: const Text('Todo'),
                                  onPressed: () {
                                    setDialogState(() => transferQty = available);
                                  },
                                ),
                              if (available >= 5)
                                ActionChip(
                                  label: const Text('5'),
                                  onPressed: () => setDialogState(() => transferQty = 5),
                                ),
                              if (available >= 10)
                                ActionChip(
                                  label: const Text('10'),
                                  onPressed: () => setDialogState(() => transferQty = 10),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: (selectedProductId != null && transferQty > 0 && !isTransferring)
                  ? () async {
                      setDialogState(() => isTransferring = true);
                      try {
                        await db.transferStock(
                          productId: selectedProductId!,
                          quantity: transferQty,
                          fromLocation: 'almacen',
                          toLocation: 'pv',
                          reference: 'Transferencia manual',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Transferidos ${_fmtQty(transferQty)} unidades a PV'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadData();
                        }
                      } catch (e) {
                        setDialogState(() => isTransferring = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              child: isTransferring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Transferir'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item del carrito de compra
class _CartItem {
  final Product product;
  double quantity;
  double costPerUnit;

  _CartItem({
    required this.product,
    this.quantity = 1,
    required this.costPerUnit,
  });

  double get total => quantity * costPerUnit;
}
