import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/core/database/database_provider.dart';
import 'package:etecsa/features/shared/services/KeyValueStorageService.dart';
import 'package:etecsa/features/home/presentation/screens/home_screen.dart';

// ================================================================
// PROVIDERS DE POS
// ================================================================

// Sesión actual
final currentSessionProvider =
    NotifierProvider<CurrentSessionNotifier, Session?>(
      CurrentSessionNotifier.new,
    );

class CurrentSessionNotifier extends Notifier<Session?> {
  @override
  Session? build() {
    return null;
  }

  Future<void> loadActiveSession() async {
    final db = AppDatabase.instance;
    state = await db.getActiveSession();
  }

  Future<void> openSession({
    required String userId,
    required double openingCash,
    String? description,
  }) async {
    final db = AppDatabase.instance;
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    await db.openSession(
      id: sessionId,
      userId: userId,
      openingCash: openingCash,
      description: description,
    );
    await loadActiveSession();
    // Invalidar datos del Home para que métricas se actualicen
    ref.invalidate(homeDataProvider);
  }

  Future<void> closeSession({required double closingCash}) async {
    if (state == null) return;
    final db = AppDatabase.instance;

    final totalSales = state!.totalSales;
    final totalCash = state!.totalCash;
    final totalTransfer = state!.totalTransfer;
    final totalProfit = await db.getSessionProfit(state!.id);

    await db.closeSession(
      id: state!.id,
      closingCash: closingCash,
      totalSales: totalSales,
      totalCash: totalCash,
      totalTransfer: totalTransfer,
      totalProfit: totalProfit,
    );

    // Limpiar sesión local
    state = null;

    // Limpiar carrito al cerrar caja (previene que quede pedido residual)
    ref.read(cartProvider.notifier).clear();

    // Invalidar datos del Home para que métricas se actualicen
    ref.invalidate(homeDataProvider);
  }
}

// Carrito actual
final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

class CartState {
  final String? orderId;
  final List<CartItem> items;
  final double subtotal;

  const CartState({this.orderId, this.items = const [], this.subtotal = 0});

  CartState copyWith({
    String? orderId,
    List<CartItem>? items,
    double? subtotal,
  }) {
    return CartState(
      orderId: orderId ?? this.orderId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity.ceil());
}

class CartItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double originalPrice;
  final double costPrice;
  final bool isWholesale;

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    double? originalPrice,
    this.isWholesale = false,
  }) : originalPrice = originalPrice ?? unitPrice;

  double get subtotal => quantity * unitPrice;

  CartItem copyWith({
    double? quantity,
    double? unitPrice,
    bool? isWholesale,
    double? originalPrice,
  }) {
    return CartItem(
      productId: productId,
      productName: productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      isWholesale: isWholesale ?? this.isWholesale,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState();
  }

  /// Add item to cart. Returns null on success, or an error message string on failure.
  /// [maxStock] limits the quantity. If null, no stock validation is performed.
  String? addItem(Product product, {double? maxStock}) {
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex >= 0) {
      // Already in cart → increment quantity
      final currentQty = state.items[existingIndex].quantity;
      return updateQuantity(existingIndex, currentQty + 1, maxStock: maxStock);
    }

    if (maxStock != null && maxStock <= 0) {
      return 'Stock insuficiente para ${product.name} (disponible: ${_formatStock(maxStock)})';
    }

    final newItem = CartItem(
      productId: product.id,
      productName: product.name,
      quantity: 1,
      unitPrice: product.unitPrice,
      costPrice: product.costPrice,
    );

    final newItems = [...state.items, newItem];
    final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.subtotal);
    state = state.copyWith(items: newItems, subtotal: newSubtotal);

    // Load wholesale rules and apply pricing
    _loadWholesaleRules().then((_) => _applyWholesalePricing());

    return null;
  }

  /// Cache de reglas de precio por mayor
  Map<String, List<Map<String, dynamic>>> _wholesaleCache = {};

  /// Cargar reglas de precio por mayor para todos los productos en el carrito
  Future<void> _loadWholesaleRules() async {
    final db = AppDatabase.instance;
    final productIds = state.items.map((i) => i.productId).toSet();
    for (final pid in productIds) {
      if (!_wholesaleCache.containsKey(pid)) {
        _wholesaleCache[pid] = await db.getWholesaleRules(pid);
      }
    }
  }

  /// Aplicar precios por mayor según cantidad en carrito
  void _applyWholesalePricing() {
    // Agrupar cantidades por producto
    final qtyByProduct = <String, double>{};
    for (final item in state.items) {
      qtyByProduct[item.productId] =
          (qtyByProduct[item.productId] ?? 0) + item.quantity;
    }

    final newItems = state.items.map((item) {
      final totalQty = qtyByProduct[item.productId] ?? item.quantity;
      final rules = _wholesaleCache[item.productId] ?? [];

      // Buscar la mejor regla aplicable (mayor cantidad que no exceda el total)
      Map<String, dynamic>? bestRule;
      double bestMinQty = 0;
      for (final rule in rules) {
        final minQty = (rule['minQuantity'] as num).toDouble();
        if (totalQty >= minQty && minQty > bestMinQty) {
          bestRule = rule;
          bestMinQty = minQty;
        }
      }

      if (bestRule != null) {
        return item.copyWith(
          unitPrice: (bestRule['unitPrice'] as num).toDouble(),
          isWholesale: true,
        );
      } else if (item.isWholesale) {
        // Restaurar precio original si ya no aplica
        return item.copyWith(unitPrice: item.originalPrice, isWholesale: false);
      }
      return item;
    }).toList();

    final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.subtotal);
    state = state.copyWith(items: newItems, subtotal: newSubtotal);
  }

  /// Updates quantity of a cart item. Returns null on success, or an error message string on failure.
  /// [maxStock] is the available stock for this product. If null, no stock validation is performed.
  String? updateQuantity(int index, double qty, {double? maxStock}) {
    if (index < 0 || index >= state.items.length) return null;

    if (qty <= 0) {
      final newItems = [...state.items]..removeAt(index);
      final newSubtotal = newItems.fold(
        0.0,
        (sum, item) => sum + item.subtotal,
      );
      state = state.copyWith(items: newItems, subtotal: newSubtotal);
      _loadWholesaleRules().then((_) => _applyWholesalePricing());
      return null;
    }

    // Stock validation: clamp to max
    if (maxStock != null && qty > maxStock) {
      return 'Stock insuficiente para ${state.items[index].productName} (disponible: ${_formatStock(maxStock)})';
    }

    final newItems = [...state.items];
    newItems[index] = newItems[index].copyWith(quantity: qty);
    final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.subtotal);
    state = state.copyWith(items: newItems, subtotal: newSubtotal);
    _loadWholesaleRules().then((_) => _applyWholesalePricing());
    return null;
  }

  String _formatStock(double stock) {
    return stock == stock.roundToDouble()
        ? stock.toInt().toString()
        : stock.toStringAsFixed(1);
  }

  void updatePrice(int index, double newPrice) {
    if (index < 0 || index >= state.items.length || newPrice <= 0) return;

    final newItems = [...state.items];
    newItems[index] = newItems[index].copyWith(unitPrice: newPrice);
    final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.subtotal);
    state = state.copyWith(items: newItems, subtotal: newSubtotal);
  }

  void removeItem(int index) {
    final newItems = [...state.items];
    newItems.removeAt(index);
    final newSubtotal = newItems.fold(0.0, (sum, item) => sum + item.subtotal);
    state = state.copyWith(items: newItems, subtotal: newSubtotal);
  }

  void setOrderId(String orderId) {
    state = state.copyWith(orderId: orderId);
  }

  void clear() {
    state = const CartState();
  }
}

// Pedidos pendientes
final pendingOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final db = AppDatabase.instance;
  return db.getPendingOrders();
});

// Stocks de productos (Notifier para poder recargar)
final stocksProvider = NotifierProvider<StocksNotifier, Map<String, double>>(
  StocksNotifier.new,
);

class StocksNotifier extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() {
    return {};
  }

  Future<void> refresh() async {
    final db = AppDatabase.instance;
    // POS solo muestra stock de 'pv' (nunca mezclar con almacen)
    state = await db.getAllStocks(location: 'pv');
  }
}

// Ganancia en tiempo real de la sesión activa (Notifier para recargar)
final sessionProfitProvider = NotifierProvider<SessionProfitNotifier, double>(
  SessionProfitNotifier.new,
);

// Modo Kiosco
final kioscoModeProvider = FutureProvider<bool>((ref) async {
  final storage = KeyValueStorageService();
  final enabled = await storage.getValue('kiosco_mode_enabled');
  return enabled == 'true';
});

class SessionProfitNotifier extends Notifier<double> {
  @override
  double build() {
    return 0.0;
  }

  Future<void> refresh() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      state = 0.0;
      return;
    }
    final db = AppDatabase.instance;
    state = await db.getSessionProfit(session.id);
  }
}
