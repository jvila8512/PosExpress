import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/features/pos/presentation/providers/pos_provider.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/config/theme/app_colors.dart';
import 'package:etecsa/features/pos/presentation/screens/invoice_screen.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/core/database/app_database.dart';

/// Pantalla dedicada para modo Prefactura.
/// Permite armar un carrito y generar una prefactura SIN registrar ventas,
/// SIN descontar stock, SIN sesión de caja.
class PrefacturaScreen extends ConsumerStatefulWidget {
  const PrefacturaScreen({super.key});

  @override
  ConsumerState<PrefacturaScreen> createState() => _PrefacturaScreenState();
}

class _PrefacturaScreenState extends ConsumerState<PrefacturaScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  late TabController _tabController;
  final Set<String> _expandedCategories = {};
  final Set<String> _userCollapsedCategories = {};
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // SIEMPRE cargar stocks para mostrar stock real
    Future.microtask(() async {
      await ref.read(stocksProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _qtyControllers.values) c.dispose();
    for (final f in _qtyFocusNodes.values) f.dispose();
    _qtyControllers.clear();
    _qtyFocusNodes.clear();
    _searchController.dispose();
    super.dispose();
  }

  void _clearCartControllers() {
    for (final c in _qtyControllers.values) c.dispose();
    for (final f in _qtyFocusNodes.values) f.dispose();
    _qtyControllers.clear();
    _qtyFocusNodes.clear();
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final isTablet = MediaQuery.of(context).size.width > 600;

    return isTablet
        ? _buildTabletLayout(cart)
        : _buildPhoneLayout(cart);
  }

  // ─── PHONE LAYOUT ───

  Widget _buildPhoneLayout(CartState cart) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined,
                color: Colors.green, size: 16),
            const SizedBox(width: 6),
            const Text(
              'PREFACTURA',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProductsList(), _buildCartView(cart)],
      ),
    );
  }

  // ─── TABLET LAYOUT ───

  Widget _buildTabletLayout(CartState cart) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.description_outlined,
                color: Colors.green, size: 16),
            const SizedBox(width: 6),
            const Text(
              'PREFACTURA',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [Expanded(child: _buildProductsList())],
            ),
          ),
          Container(
            width: 320,
            color: Colors.grey.shade100,
            child: _buildCartView(cart),
          ),
        ],
      ),
    );
  }

  /// Expande todas las categorías (usado al buscar y al borrar filtro)
  void _expandAllCategories() {
    _userCollapsedCategories.clear();
    final products = ref.read(productsProvider);
    final catIds = <String>{};
    for (final p in products.products.where((p) => p.isActive)) {
      catIds.add(p.categoryId ?? '');
    }
    for (final id in catIds) {
      _expandedCategories.add(id);
    }
  }

  // ─── PRODUCTS LIST ───

  Widget _buildProductsList() {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);
    final query = _searchController.text.toLowerCase();

    List<Product> filtered =
        products.products.where((p) => p.isActive).toList();
    if (query.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              (p.code?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    final Map<String?, List<Product>> grouped = {};
    for (final p in filtered) {
      grouped.putIfAbsent(p.categoryId, () => []).add(p);
    }

    final catMap = {for (final c in categories.categories) c.id: c.name};

    final groupKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return (catMap[a] ?? '').compareTo(catMap[b] ?? '');
      });

    // Expandir por defecto: todas las categorías que no colapsó el usuario manualmente
    for (final key in groupKeys) {
      final k = key ?? '';
      if (!_expandedCategories.contains(k) && !_userCollapsedCategories.contains(k)) {
        _expandedCategories.add(k);
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _expandAllCategories();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    query.isEmpty
                        ? 'No hay productos disponibles'
                        : 'No se encontró "$query"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final catId in groupKeys) ...[
                  _buildCategorySection(
                    key: ValueKey('cat-$catId'),
                    categoryId: catId ?? '',
                    categoryName: catId != null
                        ? (catMap[catId] ?? 'Sin categoría')
                        : 'Sin categoría',
                    products: grouped[catId]!,
                    cart: cart,
                    isExpanded: query.isNotEmpty ||
                        _expandedCategories.contains(catId ?? ''),
                    onToggle: () {
                      setState(() {
                        final key = catId ?? '';
                        if (_expandedCategories.contains(key)) {
                          _expandedCategories.remove(key);
                          _userCollapsedCategories.add(key);
                        } else {
                          _expandedCategories.add(key);
                          _userCollapsedCategories.remove(key);
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCategorySection({
    Key? key,
    required String categoryId,
    required String categoryName,
    required List<Product> products,
    required CartState cart,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${products.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: GridView.builder(
            padding: const EdgeInsets.all(4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.52,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index], cart);
            },
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  // ─── PRODUCT CARD ───

  Widget _buildProductCard(Product product, CartState cart) {
    final stocks = ref.watch(stocksProvider);
    final stock = stocks[product.id] ?? 0;
    final hasStock = stock > 0;

    String? imageUrl;
    try {
      final desc = product.description ?? '';
      if (desc.startsWith('IMG:')) imageUrl = desc.substring(4);
    } catch (_) {
      imageUrl = null;
    }
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final isInCart =
        cart.items.any((item) => item.productId == product.id);
    final cartItem = isInCart
        ? cart.items.firstWhere((item) => item.productId == product.id)
        : null;

    return InkWell(
      onTap: hasStock
          ? () {
              final error = ref
                  .read(cartProvider.notifier)
                  .addItem(product,
                      maxStock: stock > 0 ? stock : null);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          : () {
              // Stock = 0 → preguntar si es devolución
              _showReturnFromGridDialog(product);
            },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isInCart
              ? AppColors.accent.withValues(alpha: 0.08)
              : (hasStock ? Colors.white : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isInCart
                ? AppColors.accent
                : (hasStock
                    ? (stock <= 3 ? Colors.orange : Colors.grey.shade300)
                    : Colors.orange.shade300),
            width: isInCart ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 70,
                  width: double.infinity,
                  child: hasImage
                      ? Image.file(
                          File(imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              _buildInitial(product.name),
                        )
                      : _buildInitial(product.name),
                ),
                if (isInCart && cartItem != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${cartItem.quantity == cartItem.quantity.roundToDouble() ? cartItem.quantity.toInt() : cartItem.quantity.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  child: Text(
                    product.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '\$${product.unitPrice.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
              child: hasStock
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: stock <= 3
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _formatQty(stock),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: stock <= 3
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(3),
                        border:
                            Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.undo,
                              size: 8,
                              color: Colors.orange.shade700),
                          const SizedBox(width: 2),
                          Text(
                            'DEV',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial(String name) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  // ─── CART VIEW ───

  Widget _buildCartView(CartState cart) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.accent,
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Carrito',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${cart.itemCount} items',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: cart.items.isEmpty
              ? const Center(child: Text('Agrega productos'))
              : ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    final ctrl = _qtyControllers.putIfAbsent(
                      item.productId,
                      () => TextEditingController(
                          text: _formatQty(item.quantity)),
                    );
                    final qtyText = _formatQty(item.quantity);
                    if (ctrl.text != qtyText) ctrl.text = qtyText;
                    final focus = _qtyFocusNodes.putIfAbsent(
                      item.productId,
                      () => FocusNode(),
                    );
                    return Dismissible(
                      key: Key(item.productId),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ref
                          .read(cartProvider.notifier)
                          .removeItem(index),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.shade100,
                        child: Icon(Icons.delete,
                            color: Colors.red.shade400),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.isWholesale) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      '\$${item.originalPrice.toStringAsFixed(0)} → \$${item.unitPrice.toStringAsFixed(0)} × mayoreo',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    item.isWholesale
                                        ? '\$${item.unitPrice.toStringAsFixed(0)} × ${_formatQty(item.quantity)} = \$${item.subtotal.toStringAsFixed(0)}'
                                        : '\$${item.unitPrice.toStringAsFixed(0)} × ${_formatQty(item.quantity)} = \$${item.subtotal.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.isWholesale
                                          ? Colors.green.shade700
                                          : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: ctrl,
                                focusNode: focus,
                                keyboardType: const TextInputType
                                    .numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 4),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppColors.accent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  final qty = double.tryParse(val);
                                  if (qty != null &&
                                      qty > 0 &&
                                      qty !=
                                          cart
                                              .items[index].quantity) {
                                    final itemStock = ref
                                            .read(stocksProvider)[
                                        item.productId] ?? 0;
                                    final error = ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(index, qty,
                                            maxStock:
                                                itemStock > 0
                                                    ? itemStock
                                                    : null);
                                    if (error != null) {
                                      ctrl.text = _formatQty(
                                          cart
                                              .items[index].quantity);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(error),
                                        backgroundColor:
                                            Colors.orange,
                                        duration: const Duration(
                                            seconds: 2),
                                      ));
                                    }
                                  }
                                },
                                onSubmitted: (val) {
                                  final qty =
                                      double.tryParse(val) ?? 0;
                                  if (qty <= 0) {
                                    ctrl.text = _formatQty(
                                        cart
                                            .items[index].quantity);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'La cantidad debe ser mayor a 0.'),
                                        duration:
                                            Duration(seconds: 2),
                                        backgroundColor:
                                            Colors.orange,
                                      ),
                                    );
                                  } else {
                                    final itemStock = ref
                                            .read(stocksProvider)[
                                        item.productId] ?? 0;
                                    ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(index, qty,
                                            maxStock:
                                                itemStock > 0
                                                    ? itemStock
                                                    : null);
                                    ctrl.text = _formatQty(qty);
                                  }
                                  focus.unfocus();
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.close,
                                  size: 20,
                                  color: Colors.red.shade400),
                              tooltip: 'Quitar del carrito',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 28, minHeight: 28),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .removeItem(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Total + botón ENVIAR PREFACTURA
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:',
                        style: TextStyle(fontSize: 18)),
                    Text(
                      '\$${cart.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () => _navigateToPrefactura(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: const Text(
                      'ENVIAR PREFACTURA',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── RETURN FROM GRID (stock=0) ───

  void _showReturnFromGridDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.undo, color: Colors.orange),
            SizedBox(width: 8),
            Text('Devolución'),
          ],
        ),
        content: Text(
          '"${product.name}" no tiene stock.\n\n¿Es una devolución?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(cartProvider.notifier)
                  .addItem(product, maxStock: null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${product.name} agregado para devolución'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange),
            child: const Text('SÍ, DEVOLVER'),
          ),
        ],
      ),
    );
  }

  // ─── NAVIGATE TO PREFACTURA ───

  void _navigateToPrefactura() {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    final invoiceItems = cart.items
        .map(
          (i) => InvoiceItemData(
            productName: i.productName,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
            subtotal: i.subtotal,
            isWholesale: i.isWholesale,
            originalPrice: i.originalPrice,
          ),
        )
        .toList();

    final orderId = 'PF${DateTime.now().millisecondsSinceEpoch}';

    ref.read(cartProvider.notifier).clear();
    _clearCartControllers();
    _tabController.animateTo(0);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(
          orderId: orderId,
          items: invoiceItems,
          total: cart.subtotal,
          method: 'prefactura',
          cashAmount: 0,
          transferAmount: 0,
          change: 0,
          sellerId: '',
          isPrefactura: true,
        ),
      ),
    );
  }
}
