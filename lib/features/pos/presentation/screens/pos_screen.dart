import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:etecsa/features/pos/presentation/providers/pos_provider.dart';
import 'package:etecsa/features/products/presentation/providers/products_provider.dart';
import 'package:etecsa/features/products/presentation/providers/categories_provider.dart';
import 'package:etecsa/features/shared/widgets/side_menu.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/core/services/export_service.dart';
import 'package:etecsa/features/shared/widgets/export_options_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'package:etecsa/config/theme/app_theme.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/pos/presentation/screens/invoice_screen.dart';
import 'package:etecsa/features/pos/presentation/screens/payment_screen.dart';
import 'package:etecsa/features/home/presentation/screens/home_screen.dart';

const _kioscoModeKey = 'kiosco_mode_enabled';

class PosScreen extends ConsumerStatefulWidget {
  final bool isPrefacturaMode;
  const PosScreen({super.key, this.isPrefacturaMode = false});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _cashController = TextEditingController(text: '500');
  final _descController = TextEditingController(text: 'Apertura');
  bool _isSearching = false;
  late TabController _tabController;
  final Set<String> _expandedCategories = {};
  final Set<String> _userCollapsedCategories = {};
  bool _isKioscoMode = false;
  bool _isVendedor = false;
  bool _isAdminOrSuperAdmin = false;
  Timer? _searchDebounce;
  String _debouncedQuery = '';
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, FocusNode> _qtyFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // El rol lo cargamos SIEMPRE (lo necesita tanto POS normal como prefactura)
    _loadUserRole();

    if (!widget.isPrefacturaMode) {
      _checkKioscoMode();

      Future.microtask(() async {
        ref.read(currentSessionProvider.notifier).loadActiveSession();
        await ref.read(stocksProvider.notifier).refresh();
        await ref.read(sessionProfitProvider.notifier).refresh();
        await _loadLastSessionCash();
      });
    }
  }

  Future<void> _loadUserRole() async {
    final storage = KeyValueStorageService();
    final role = await storage.getValue('user_role') ?? '';
    if (mounted) {
      setState(() {
        _isVendedor = role == 'vendedor';
        _isAdminOrSuperAdmin = role == 'admin' || role == 'super_admin';
      });
    }
  }

  Future<void> _checkKioscoMode() async {
    final storage = KeyValueStorageService();
    final kioscoEnabled = await storage.getValue(_kioscoModeKey);
    if (kioscoEnabled == 'true') {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      if (mounted) setState(() => _isKioscoMode = true);
    }
  }

  Future<void> _loadLastSessionCash() async {
    final db = AppDatabase.instance;
    final lastSession = await db.getLastClosedSession();
    if (lastSession != null && lastSession.closingCash != null) {
      _cashController.text = lastSession.closingCash!.toStringAsFixed(0);
      _descController.text =
          'Apertura ${lastSession.openingTime.toString().substring(0, 10)}';
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final f in _qtyFocusNodes.values) {
      f.dispose();
    }
    _qtyControllers.clear();
    _qtyFocusNodes.clear();
    super.dispose();
  }

  void _clearCartControllers() {
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final f in _qtyFocusNodes.values) {
      f.dispose();
    }
    _qtyControllers.clear();
    _qtyFocusNodes.clear();
  }

  String _formatQty(double qty) {
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  void _showOpenSessionDialog() {
    // Ir a la pestaña de abrir caja
    _tabController.animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caja cerrada. Abre una nueva caja para continuar.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prefactura mode: skip session check entirely
    if (widget.isPrefacturaMode) {
      final cart = ref.watch(cartProvider);
      final isTablet = MediaQuery.of(context).size.width > 600;
      if (isTablet) {
        return _buildTabletLayout(cart);
      } else {
        return _buildPhoneLayout(cart);
      }
    }

    // Auto load session on build
    final sessionAsync = ref.watch(currentSessionProvider);
    final cart = ref.watch(cartProvider);
    final isTablet = MediaQuery.of(context).size.width > 600;

    // Auto load session if null
    if (sessionAsync == null) {
      Future.microtask(
        () => ref.read(currentSessionProvider.notifier).loadActiveSession(),
      );
      // Mostrar pantalla de abrir caja si no hay sesión
      return _buildOpenSessionScreen();
    }

    if (isTablet) {
      return _buildTabletLayout(cart);
    } else {
      return _buildPhoneLayout(cart);
    }
  }

  int _titleTapCount = 0;
  DateTime? _lastTapTime;

  void _onTitleTap() {
    if (!_isKioscoMode) return;
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds < 2) {
      _titleTapCount++;
    } else {
      _titleTapCount = 1;
    }
    _lastTapTime = now;

    if (_titleTapCount >= 3) {
      _titleTapCount = 0;
      _showExitKioscoDialog();
    }
  }

  Future<void> _exitKioscoMode() async {
    final storage = KeyValueStorageService();
    await storage.setKeyValue(_kioscoModeKey, 'false');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    if (mounted) {
      setState(() => _isKioscoMode = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Modo Kiosco desactivado')));
    }
  }

  Widget _buildPhoneLayout(CartState cart) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _isKioscoMode ? null : SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: _isKioscoMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'POSJVL',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : const Text('POSJVL'),
        ),
        leading: _isKioscoMode
            ? IconButton(
                icon: const Icon(Icons.lock_outline),
                onPressed: _showExitKioscoDialog,
                tooltip: 'Salir Modo Kiosco',
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSessionReport(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showCloseSessionDialog(),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _tabController.animateTo(1),
              ),
              if (cart.items.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProductsList(), _buildCartView(cart)],
      ),
    );
  }

  Widget _buildTabletLayout(CartState cart) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _isKioscoMode ? null : SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onTitleTap,
          child: _isKioscoMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'POSJVL',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                )
              : const Text('POSJVL'),
        ),
        leading: _isKioscoMode
            ? IconButton(
                icon: const Icon(Icons.lock_outline),
                onPressed: _showExitKioscoDialog,
                tooltip: 'Salir Modo Kiosco',
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showSessionReport(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showCloseSessionDialog(),
          ),
          TextButton(
            onPressed: () => _showCloseSessionDialog(),
            child: const Text(
              'CERRAR CAJA',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(children: [Expanded(child: _buildProductsList())]),
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

    // Recopilar todos los categoryIds de productos activos
    final catIds = <String>{};
    for (final p in products.products.where((p) => p.isActive)) {
      catIds.add(p.categoryId ?? '');
    }
    for (final id in catIds) {
      _expandedCategories.add(id);
    }
  }

  Widget _buildProductsList() {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider);
    final cart = ref.watch(cartProvider);
    final stocks = ref.watch(stocksProvider);
    final query = _debouncedQuery;

    // Filtrar productos activos + búsqueda
    List<Product> filtered = products.products
        .where((p) => p.isActive)
        .toList();
    if (query.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(query) ||
                (p.code?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    // Agrupar por categoría
    final Map<String?, List<Product>> grouped = {};
    for (final p in filtered) {
      grouped.putIfAbsent(p.categoryId, () => []).add(p);
    }

    // Mapa de id → nombre de categoría
    final catMap = {for (final c in categories.categories) c.id: c.name};

    // Ordenar grupos: categorías con nombre, y "Sin categoría" al final
    final groupKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return (catMap[a] ?? '').compareTo(catMap[b] ?? '');
      });

    // Expandir solo categorías con productos (durante búsqueda, solo las que tienen match)
    for (final key in groupKeys) {
      final k = key ?? '';
      if (query.isNotEmpty) {
        // En búsqueda: expandir SOLO categorías con productos filtrados
        _expandedCategories.add(k);
      } else {
        // Sin búsqueda: expandir todas las que no colapsó el usuario
        if (!_expandedCategories.contains(k) && !_userCollapsedCategories.contains(k)) {
          _expandedCategories.add(k);
        }
      }
    }

    return Column(
      children: [
        // Buscador
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
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _debouncedQuery = '';
                        // Re-expandir todas las categorías al borrar filtro
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
            onChanged: (text) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _debouncedQuery = text.toLowerCase();
                  });
                }
              });
              // Actualizar inmediatamente para UX responsiva (solo el text field)
              setState(() {});
            },
          ),
        ),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    query.isEmpty
                        ? 'No hay productos disponibles'
                        : 'No se encontró "$query"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (query.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        _debouncedQuery = '';
                        _expandAllCategories();
                        setState(() {});
                      },
                      child: const Text('Limpiar búsqueda'),
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
                    stocks: stocks,
                    isExpanded:
                        query.isNotEmpty ||
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
    required Map<String, double> stocks,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header de categoría (tocable para expandir/colapsar)
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppTheme.colorCeleste,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: AppTheme.colorCeleste,
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
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.colorCeleste.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${products.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.colorCeleste,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Grid de productos (animado)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: GridView.builder(
            padding: const EdgeInsets.all(4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.52,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(products[index], cart, stocks);
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

  Widget _buildProductCard(Product product, CartState cart, Map<String, double> stocks) {
    final stock = stocks[product.id] ?? 0;
    final hasStock = stock > 0;

    // Obtener imageUrl del campo description (formato: IMG:ruta)
    String? imageUrl;
    try {
      final desc = product.description ?? '';
      if (desc.startsWith('IMG:')) {
        imageUrl = desc.substring(4); // Quitar "IMG:"
      }
    } catch (_) {
      imageUrl = null;
    }
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final isInCart = cart.items.any((item) => item.productId == product.id);
    final cartItem = isInCart
        ? cart.items.firstWhere((item) => item.productId == product.id)
        : null;
    return InkWell(
      onTap: hasStock
          ? () {
              final error = ref
                  .read(cartProvider.notifier)
                  .addItem(product, maxStock: stock > 0 ? stock : null);
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
              // No mostramos SnackBar al agregar — el borde verde ya indica que está en el carrito
            }
          : () {
              // Stock = 0 → preguntar si es una devolución
              _showReturnFromGridDialog(product);
            },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isInCart
              ? AppTheme.colorMorado.withValues(alpha: 0.08)
              : (hasStock ? Colors.white : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isInCart
                ? AppTheme.colorMorado
                : (hasStock
                      ? (stock <= 3 ? Colors.orange : Colors.grey.shade300)
                      : Colors.orange.shade300),
            width: isInCart ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Imagen full-width arriba
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
                // Badge de cantidad en carrito (superpuesto)
                if (isInCart && cartItem != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.colorMorado,
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
            // Nombre centrado, ocupa espacio flexible
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
            // Precio (siempre al fondo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '\$${product.unitPrice.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.colorMorado,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            // Stock badge (siempre al fondo)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 1, 4, 4),
              child: hasStock
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
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
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.undo,
                            size: 8,
                            color: Colors.orange.shade700,
                          ),
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

  // Helper para mostrar inicial si no hay imagen
  Widget _buildInitial(String name) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.colorCeleste.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'P',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.colorCeleste,
          ),
        ),
      ),
    );
  }

  Widget _buildCartView(CartState cart) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.colorCeleste,
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
        // Items
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
                        text: _formatQty(item.quantity),
                      ),
                    );
                    // Sincronizar el texto del controller con la cantidad actual (putIfAbsent no actualiza automáticamente)
                    final qtyText = _formatQty(item.quantity);
                    if (ctrl.text != qtyText) ctrl.text = qtyText;
                    final focus = _qtyFocusNodes.putIfAbsent(
                      item.productId,
                      () => FocusNode(),
                    );
                    return Dismissible(
                      key: Key(item.productId),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) =>
                          ref.read(cartProvider.notifier).removeItem(index),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: Colors.red.shade100,
                        child: Icon(Icons.delete, color: Colors.red.shade400),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.isWholesale)
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  if (!item.isWholesale)
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
                                  GestureDetector(
                                    onTap: _isVendedor
                                        ? null
                                        : () =>
                                              _showEditPriceDialog(index, item),
                                    child: item.isWholesale
                                        ? Text(
                                            '\$${item.unitPrice.toStringAsFixed(0)} × ${_formatQty(item.quantity)} = \$${item.subtotal.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade700,
                                              decoration: _isVendedor
                                                  ? TextDecoration.none
                                                  : TextDecoration.underline,
                                              decorationColor:
                                                  Colors.green.shade400,
                                            ),
                                          )
                                        : Text(
                                            '\$${item.unitPrice.toStringAsFixed(0)} × ${_formatQty(item.quantity)} = \$${item.subtotal.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.colorCeleste,
                                              decoration: _isVendedor
                                                  ? TextDecoration.none
                                                  : TextDecoration.underline,
                                              decorationColor: AppTheme
                                                  .colorCeleste
                                                  .withValues(alpha: 0.4),
                                            ),
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 4,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: AppTheme.colorMorado,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  final qty = double.tryParse(val);
                                  if (qty != null &&
                                      qty > 0 &&
                                      qty != cart.items[index].quantity) {
                                    final itemStock =
                                        ref.read(
                                          stocksProvider,
                                        )[item.productId] ??
                                        0;
                                    final error = ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(
                                          index,
                                          qty,
                                          maxStock: itemStock > 0
                                              ? itemStock
                                              : null,
                                        );
                                    if (error != null) {
                                      ctrl.text = _formatQty(
                                        cart.items[index].quantity,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(error),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                },
                                onSubmitted: (val) {
                                  final qty = double.tryParse(val) ?? 0;
                                  if (qty <= 0) {
                                    // Restaurar cantidad anterior, no eliminar
                                    ctrl.text = _formatQty(
                                      cart.items[index].quantity,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'La cantidad debe ser mayor a 0. Para quitar, usá el botón eliminar.',
                                        ),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  } else {
                                    final itemStock =
                                        ref.read(
                                          stocksProvider,
                                        )[item.productId] ??
                                        0;
                                    final error = ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(
                                          index,
                                          qty,
                                          maxStock: itemStock > 0
                                              ? itemStock
                                              : null,
                                        );
                                    if (error != null) {
                                      ctrl.text = _formatQty(
                                        cart.items[index].quantity,
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(error),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } else {
                                      ctrl.text = _formatQty(qty);
                                    }
                                  }
                                  focus.unfocus();
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.red.shade400,
                              ),
                              tooltip: 'Quitar del carrito',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
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
        // Total y botones
        SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 18)),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: cart.items.isEmpty
                            ? null
                            : () => _showReturnDialog(),
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Devolver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: (widget.isPrefacturaMode && _isAdminOrSuperAdmin)
                          ? ElevatedButton(
                              onPressed: cart.items.isEmpty
                                  ? null
                                  : () => _navigateToPrefactura(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('ENVIAR PREFACTURA'),
                            )
                          : ElevatedButton(
                              onPressed: cart.items.isEmpty
                                  ? null
                                  : () => _navigateToPayment(cart.subtotal),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.colorMorado,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('COBRAR'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showReturnDialog() {
    final cart = ref.read(cartProvider);
    final totalReturn = cart.subtotal;
    final cashController = TextEditingController(
      text: totalReturn.toStringAsFixed(2),
    );

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar productos a devolver
            const Text(
              'Productos a devolver:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...cart.items.map(
              (i) => Text('• ${_formatQty(i.quantity)}x ${i.productName}'),
            ),
            const Divider(),
            Text(
              'Total a devolver: \$${totalReturn.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Dinero que el cliente entrega:'),
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dinero',
                prefixText: '\$',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(cashController.text) ?? 0;
              Navigator.pop(ctx);
              _processReturn(amount);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('CONFIRMAR'),
          ),
        ],
      ),
    );
  }

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
              // Agregar al carrito para devolución (sin validación de stock)
              ref.read(cartProvider.notifier).addItem(product, maxStock: null);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} agregado para devolución'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('SÍ, DEVOLVER'),
          ),
        ],
      ),
    );
  }

  Future<void> _processReturn(double clientMoney) async {
    final cart = ref.read(cartProvider);
    if (cart.items.isEmpty) return;

    final totalReturn = cart.subtotal;
    final change = clientMoney - totalReturn;

    if (change < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falta: \$${(-change).toStringAsFixed(2)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final session = ref.read(currentSessionProvider);
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abre una caja primero'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final db = AppDatabase.instance;
    final orderId = 'R${DateTime.now().millisecondsSinceEpoch}';
    final saleId = 'SR$orderId'; // ID para la tabla sales (devolución)

    // Crear venta negativa en sales (para que dashboard descuente la devolución)
    await db.createSale(
      id: saleId,
      sellerId: session.userId,
      totalAmount: -totalReturn,
      paymentMethod: 'efectivo',
      notes: 'DEVOLUCION',
      sessionId: session.id,
    );

    // Crear order como devolución
    await db.createOrder(
      id: orderId,
      sessionId: session.id,
      sellerId: session.userId,
    );
    await db.updateOrder(
      id: orderId,
      subtotal: cart.subtotal,
      taxAmount: 0,
      totalAmount: cart.subtotal,
    );

    // Registrar items y devolver al inventario
    for (var i = 0; i < cart.items.length; i++) {
      final item = cart.items[i];

      // Calcular costo real (devoluciones usan costPrice o promedio, no FIFO)
      final realCost = item.costPrice > 0
          ? item.costPrice
          : await db.getAverageCost(item.productId);

      // Item en la venta (devolución) — valores NEGATIVOS para que getSessionProfit reste
      await db.addSaleItem(
        id: '${saleId}_$i',
        saleId: saleId,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: -item.unitPrice,
        costPriceAtSale: -realCost,
        subtotal: -item.subtotal,
      );

      // Item en el pedido — valores NEGATIVOS para que getSessionProfit reste
      await db.addOrderItem(
        id: '${orderId}_$i',
        orderId: orderId,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: -item.unitPrice,
        costPrice: -realCost,
        subtotal: -item.subtotal,
      );

      // Devolver al inventario
      await db.addInventoryLot(
        productId: item.productId,
        quantity: item.quantity,
        costPerUnit: realCost,
        purchaseDate: DateTime.now(),
        supplier: 'DEVOLUCION',
      );
    }

    // Registrar pago negativo
    await db.addPayment(
      id: '${orderId}_cash',
      orderId: orderId,
      paymentMethod: 'efectivo',
      amount: totalReturn,
      changeGiven: change,
    );

    // Marcar como pagado para que entre en las estadísticas
    await db.markOrderPaid(orderId);

    // Actualizar totales de la sesión (restar la devolución)
    final newSales = session.totalSales - totalReturn;
    // El efectivo que sale de caja es clientMoney (lo que se le da al cliente)
    // Si clientMoney > totalReturn, el cambio se restó del efectivo que sale
    final newCash = session.totalCash - clientMoney;
    final newProfit = await db.getSessionProfit(session.id);

    await db.updateSessionTotals(
      id: session.id,
      totalSales: newSales,
      totalCash: newCash,
      totalTransfer: session.totalTransfer,
    );

    // Construir mensaje de productos devueltos ANTES de limpiar
    final productsList = cart.items
        .map((i) => '${_formatQty(i.quantity)}x ${i.productName}')
        .join(', ');

    ref.read(cartProvider.notifier).clear();
    _clearCartControllers();
    ref.read(currentSessionProvider.notifier).loadActiveSession();
    await ref.read(stocksProvider.notifier).refresh();
    await ref.read(sessionProfitProvider.notifier).refresh();

    // Mostrar diálogo con el resultado
    if (mounted) {
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Atendido por: ${session.userId}'),
              const SizedBox(height: 8),
              const Text(
                'Productos devueltos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(productsList),
              const SizedBox(height: 12),
              Text('Total devuelto: \$${totalReturn.toStringAsFixed(2)}'),
              Text('Cambio: \$${change.toStringAsFixed(2)}'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOpenSessionScreen() {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(scaffoldKey: _scaffoldKey),
      appBar: AppBar(
        title: const Text('Apertura de Caja'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.point_of_sale,
              size: 80,
              color: AppTheme.colorCeleste,
            ),
            const SizedBox(height: 24),
            const Text(
              'Abrir Caja',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Ingresa el efectivo inicial'),
            const SizedBox(height: 32),
            TextField(
              controller: _cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Efectivo inicial',
                prefixIcon: Icon(Icons.money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final cash = double.tryParse(_cashController.text) ?? 0;
                  if (cash < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('El monto no puede ser negativo'),
                      ),
                    );
                    return;
                  }
                  final userId =
                      await const FlutterSecureStorage().read(key: 'user_id') ??
                      'admin';
                  await ref
                      .read(currentSessionProvider.notifier)
                      .openSession(
                        userId: userId,
                        openingCash: cash,
                        description: _descController.text,
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.colorMorado,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('ABRIR CAJA', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
            // Botón ver sesiones
            TextButton.icon(
              onPressed: () => context.push('/sessions'),
              icon: const Icon(Icons.history),
              label: const Text('Ver Sesiones'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseSessionDialog() {
    // Pre-cargar el efectivo esperado para que el vendedor solo verifique
    final session = ref.read(currentSessionProvider);
    final expectedCash = (session?.openingCash ?? 0) +
        (session?.totalCash ?? 0);
    final cashController = TextEditingController(
      text: expectedCash.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el efectivo actual en caja'),
            const SizedBox(height: 16),
            TextField(
              controller: cashController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Efectivo en caja',
                prefixText: '\$',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final cash = double.tryParse(cashController.text) ?? 0;
              await ref
                  .read(currentSessionProvider.notifier)
                  .closeSession(closingCash: cash);
              if (mounted) {
                // Ir a abrir una nueva caja
                _showOpenSessionDialog();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CERRAR'),
          ),
        ],
      ),
    );
  }

  void _showSessionReport() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;

    await ref.read(sessionProfitProvider.notifier).refresh();
    final profit = ref.read(sessionProfitProvider);

    // Cargar pedidos de la sesión
    final db = AppDatabase.instance;
    final orders = await db.getPaidOrdersBySession(session.id);
    final orderItemsMap = <String, List<OrderItem>>{};
    final orderPaymentsMap = <String, List<OrderPayment>>{};
    for (final order in orders) {
      orderItemsMap[order.id] = await db.getOrderItems(order.id);
      orderPaymentsMap[order.id] = await db.getOrderPayments(order.id);
    }

    // totalCash ya es neto (efectivo - cambio), el efectivo esperado es openingCash + totalCash
    final expectedCash = (session.openingCash ?? 0) + (session.totalCash ?? 0);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    'Informe de Caja',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      Navigator.pop(context);
                      if (val == 'excel') _exportSessionExcel(session);
                      if (val == 'pdf') _exportSessionPdf(session);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'excel',
                        child: Text('Exportar Excel'),
                      ),
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Text('Exportar PDF'),
                      ),
                    ],
                    child: const Text(
                      'Exportar',
                      style: TextStyle(
                        color: AppTheme.colorCeleste,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // === RESUMEN ===
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.colorCeleste.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.colorCeleste.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apertura: ${session.openingTime.toString().substring(0, 16)}',
                        ),
                        if (session.closingTime != null)
                          Text(
                            'Cierre: ${session.closingTime!.toString().substring(0, 16)}',
                          ),
                        if (session.description != null)
                          Text('Descripcion: ${session.description}'),
                        const Divider(),
                        _summaryRow(
                          'Ventas',
                          '\$${session.totalSales.toStringAsFixed(2)}',
                        ),
                        _summaryRow(
                          'Efectivo (ventas)',
                          '\$${session.totalCash.toStringAsFixed(2)}',
                        ),
                        _summaryRow(
                          'Transferencia',
                          '\$${session.totalTransfer.toStringAsFixed(2)}',
                        ),
                        if (!_isVendedor)
                          _summaryRow(
                            'Ganancia',
                            '\$${profit.toStringAsFixed(2)}',
                            color: Colors.green,
                            bold: true,
                          ),
                        const Divider(),
                        _summaryRow(
                          'Efectivo Inicial',
                          '\$${session.openingCash.toStringAsFixed(2)}',
                        ),
                        _summaryRow(
                          'Efectivo Esperado',
                          '\$${expectedCash.toStringAsFixed(2)}',
                          bold: true,
                        ),
                        if (session.closingCash != null)
                          _summaryRow(
                            'Efectivo Final (arqueo)',
                            '\$${session.closingCash!.toStringAsFixed(2)}',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // === PEDIDOS DE LA SESIÓN ===
                  Row(
                    children: [
                      const Text(
                        'PEDIDOS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.colorMorado.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${orders.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.colorMorado,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No hay pedidos en esta sesión',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    )
                  else
                    ...orders.map((order) {
                      final items = orderItemsMap[order.id] ?? [];
                      final payments = orderPaymentsMap[order.id] ?? [];
                      final isReturn = order.id.startsWith('R');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isReturn
                                  ? Colors.orange.shade50
                                  : AppTheme.colorCeleste.withValues(
                                      alpha: 0.1,
                                    ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isReturn ? Icons.undo : Icons.receipt,
                              size: 18,
                              color: isReturn
                                  ? Colors.orange
                                  : AppTheme.colorCeleste,
                            ),
                          ),
                          title: Text(
                            isReturn
                                ? 'Devolución'
                                : 'Pedido #${order.id.substring(order.id.length - 6)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            order.paidAt != null
                                ? '${order.paidAt!.day}/${order.paidAt!.month} ${order.paidAt!.hour}:${order.paidAt!.minute.toString().padLeft(2, '0')} - ${items.length} items'
                                : '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Text(
                            '\$${order.totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isReturn
                                  ? Colors.orange
                                  : AppTheme.colorMorado,
                            ),
                          ),
                          children: [
                            // Items
                            ...items.map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.productName,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      '${_formatQty(item.quantity)} × \$${item.unitPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '\$${item.subtotal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            // Payments
                            ...payments.map(
                              (p) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 1,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      p.paymentMethod == 'efectivo'
                                          ? Icons.money
                                          : Icons.account_balance,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _paymentLabel(p.paymentMethod),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '\$${p.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (p.changeGiven > 0) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(cambio: \$${p.changeGiven.toStringAsFixed(0)})',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPriceDialog(int index, CartItem item) {
    final ctrl = TextEditingController(text: item.unitPrice.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio de ${item.productName}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Precio unitario',
            prefixText: '\$',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newPrice = double.tryParse(ctrl.text);
              if (newPrice != null && newPrice > 0) {
                ref.read(cartProvider.notifier).updatePrice(index, newPrice);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'mixto':
        return 'Mixto';
      default:
        return method;
    }
  }

  void _exportSessionExcel(Session session) async {
    try {
      final filePath = await ExportService.instance.exportSessionExcel(session);
      if (mounted) {
        ExportOptionsDialog.show(
          context,
          filePath: filePath,
          shareText: 'Informe de Caja',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportSessionPdf(Session session) async {
    try {
      final filePath = await ExportService.instance.exportSessionPdf(session);
      if (mounted) {
        ExportOptionsDialog.show(
          context,
          filePath: filePath,
          shareText: 'Informe de Caja',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToPayment(double total) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(total: total, onPaymentComplete: () {}),
      ),
    );

    if (result != null) {
      try {
        await _completeSale(
          total: total,
          method: result['method'] as String,
          cashAmount: result['cashAmount'] as double,
          transferAmount: result['transferAmount'] as double,
          reference: result['reference'] as String? ?? '',
          bank: result['bank'] as String?,
          transactionId: result['transactionId'] as String?,
          purchaseId: result['purchaseId'] as String?,
          clientName: result['clientName'] as String?,
          clientPhone: result['clientPhone'] as String?,
          clientCI: result['clientCI'] as String?,
          transferDate: result['transferDate'] as String?,
          rawSms: result['rawSms'] as String?,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al procesar venta: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } else {
      // Usuario canceló el pago - limpiar búsqueda
      _searchController.clear();
      _debouncedQuery = '';
    }
  }

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

  Future<void> _completeSale({
    required double total,
    required String method,
    required double cashAmount,
    required double transferAmount,
    required String reference,
    required String? bank,
    String? transactionId,
    String? purchaseId,
    String? clientName,
    String? clientPhone,
    String? clientCI,
    String? transferDate,
    String? rawSms,
  }) async {
    final cart = ref.read(cartProvider);
    var session = ref.read(currentSessionProvider);

    // If no session, create one
    if (session == null) {
      final userId =
          await const FlutterSecureStorage().read(key: 'user_id') ?? 'admin';
      await ref
          .read(currentSessionProvider.notifier)
          .openSession(
            userId: userId,
            openingCash: 0,
            description: 'Auto Apertura',
          );
      // Reload session
      await ref.read(currentSessionProvider.notifier).loadActiveSession();
      session = ref.read(currentSessionProvider);
    }

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No hay sesiÃ³n de caja'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final db = AppDatabase.instance;
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final saleId = 'S$orderId'; // ID para la tabla sales

    // Pre-validate stock for all items before starting the sale
    final stocks = ref.read(stocksProvider);
    for (final item in cart.items) {
      final availableStock = stocks[item.productId] ?? 0;
      if (availableStock < item.quantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${item.productName} no tiene inventario suficiente (disponible: ${_formatQty(availableStock)}, solicitado: ${_formatQty(item.quantity)})',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    // Determinar mÃ©todo de pago principal para la tabla sales
    final mainPaymentMethod = method == 'ambos' ? 'mixto' : method;

    // 1. Crear registro en sales (para dashboard y alertas)
    await db.createSale(
      id: saleId,
      sellerId: session.userId,
      totalAmount: total,
      paymentMethod: mainPaymentMethod,
      sessionId: session.id,
    );

    // 2. Crear pedido (orders - para el POS)
    await db.createOrder(
      id: orderId,
      sessionId: session.id,
      sellerId: session.userId,
    );
    await db.updateOrder(
      id: orderId,
      subtotal: cart.subtotal,
      taxAmount: 0,
      totalAmount: cart.subtotal,
    );

    // 3. Agregar items y descontar del inventario (FIFO)
    for (var i = 0; i < cart.items.length; i++) {
      final item = cart.items[i];

      // PRIMERO descontar del inventario con FIFO y obtener costo real
      // POS siempre vende desde 'pv' — nunca desde almacen
      final fifoTotalCost = await db.sellWithFIFO(
        productId: item.productId,
        quantity: item.quantity,
        sellerId: session.userId,
        fromLocation: 'pv',
      );

      // Calcular costo unitario real FIFO (fallback a costPrice si FIFO devuelve 0)
      final realCost = fifoTotalCost > 0
          ? fifoTotalCost / item.quantity
          : (item.costPrice > 0
                ? item.costPrice
                : await db.getAverageCost(item.productId));

      // Item en la venta (sales)
      await db.addSaleItem(
        id: '${saleId}_$i',
        saleId: saleId,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        costPriceAtSale: realCost,
        subtotal: item.subtotal,
      );

      // Item en el pedido (orders)
      await db.addOrderItem(
        id: '${orderId}_$i',
        orderId: orderId,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        costPrice: realCost,
        subtotal: item.subtotal,
      );
    }

    // MÃ©todo principal
    final mainMethod = method == 'ambos' ? 'efectivo' : method;

    // Calcular cambio correctamente segÃºn mÃ©todo de pago
    // Efectivo: cambio = efectivo - total
    // Ambos: cambio = efectivo - (total - transferencia), si es positivo
    final changeGiven = method == 'ambos'
        ? (cashAmount > (total - transferAmount)
              ? cashAmount - (total - transferAmount)
              : 0.0)
        : (cashAmount > total ? cashAmount - total : 0.0);

    // Registrar pagos
    if (cashAmount > 0) {
      final change = changeGiven;
      await db.addPayment(
        id: '${orderId}_cash',
        orderId: orderId,
        paymentMethod: 'efectivo',
        amount: cashAmount,
        changeGiven: change,
        clientName: clientName,
        clientPhone: clientPhone,
      );
    }

    if (transferAmount > 0) {
      await db.addPayment(
        id: '${orderId}_transfer',
        orderId: orderId,
        paymentMethod: 'transferencia',
        amount: transferAmount,
        reference: reference.isEmpty ? null : reference,
        bank: bank,
        transactionId: transactionId,
        purchaseId: purchaseId,
        clientName: clientName,
        clientPhone: clientPhone,
        clientCI: clientCI,
        transferDate: transferDate,
        rawSms: rawSms,
      );
    }

    await db.markOrderPaid(orderId);

    // Guardar items para la factura ANTES de limpiar el carrito
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
    final invoiceChange = changeGiven;
    final invoiceMethod = method == 'ambos' ? 'mixto' : method;
    final sellerId = session?.userId ?? 'admin';

    ref.read(cartProvider.notifier).clear();
    _clearCartControllers();

    // Actualizar totales de sesiÃ³n (sin cerrarla)
    final newTotalSales = session.totalSales + total;
    // Registrar el efectivo NETO que quedó en caja (lo que el cliente dio menos el vuelto)
    final newTotalCash = session.totalCash + (cashAmount - changeGiven);
    final newTotalTransfer = session.totalTransfer + transferAmount;

    await db.updateSessionTotals(
      id: session.id,
      totalSales: newTotalSales,
      totalCash: newTotalCash,
      totalTransfer: newTotalTransfer,
    );

    await ref.read(currentSessionProvider.notifier).loadActiveSession();
    await ref.read(stocksProvider.notifier).refresh();
    await ref.read(sessionProfitProvider.notifier).refresh();
    // Invalidar datos del Home para que métricas se actualicen al volver
    ref.invalidate(homeDataProvider);

    if (mounted) {
      // Ir a productos (tab 0) antes de navegar a la factura
      _tabController.animateTo(0);
      // Limpiar búsqueda para que se vean todos los productos
      _searchController.clear();
      _debouncedQuery = '';
      // Navegar a la factura
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoiceScreen(
            orderId: orderId,
            items: invoiceItems,
            total: total,
            method: invoiceMethod,
            cashAmount: cashAmount,
            transferAmount: transferAmount,
            change: invoiceChange,
            sellerId: sellerId,
            clientPhone: clientPhone,
            clientName: clientName,
          ),
        ),
      );
    }
  }

  final _pinController = TextEditingController();

  void _showExitKioscoDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir del Modo Kiosco'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa el PIN para desactivar:'),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'PIN',
                counterText: '',
              ),
              controller: _pinController,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pinController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final pin = _pinController.text;
              final storage = KeyValueStorageService();
              final savedPin = await storage.getValue('kiosco_mode_pin');
              if (pin == savedPin) {
                _pinController.clear();
                if (ctx.mounted) Navigator.pop(ctx);
                await _exitKioscoMode();
              } else {
                _pinController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN incorrecto'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
