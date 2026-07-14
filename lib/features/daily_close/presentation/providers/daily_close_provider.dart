import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:drift/drift.dart';

import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/core/database/database_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A product's aggregated sales data for the daily close.
class ProductSalesEntry {
  final String productCode;
  final int quantity;
  final double amount;

  const ProductSalesEntry({
    required this.productCode,
    required this.quantity,
    required this.amount,
  });
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DailyCloseState {
  final bool isLoading;
  final String? error;

  // Today's orders (raw)
  final List<RestaurantOrder> orders;

  // ── Tab 1: Summary ──────────────────────────────────────────────────
  final double totalSales;
  final double cashSales;
  final double transferSales;
  final double solidSales;
  final double liquidSales;
  final List<ProductSalesEntry> topProducts;
  final double productionCost;

  // Totals from manual entries
  final double totalPurchasesAmount;
  final double totalExpensesAmount;
  final double totalPayrollAmount;

  // Derived profit & distribution
  final double utilidadNeta;
  final double distributionYurdenis;
  final double distributionMildrey;
  final double distributionNegocio;

  // ── Tab 2: Expenses (from DB) ──────────────────────────────────────
  final List<DailyExpense> expenses;

  // ── Tab 3: Purchases (from DB) ─────────────────────────────────────
  final List<DailyPurchase> purchases;

  // ── Tab 4: Payroll (from DB) ───────────────────────────────────────
  final List<DailyPayrollData> payrollEntries;
  final List<User> workers;

  // ── Operational indicators ──────────────────────────────────────────
  final int totalOrders;
  final int cancelledOrders;
  final Map<String, int> cancellationReasons;
  final int ordersWithUnconfirmedPayment;
  final double avgKitchenTimeMinutes;
  final double avgDeliveryTimeMinutes;

  const DailyCloseState({
    this.isLoading = false,
    this.error,
    this.orders = const [],
    this.totalSales = 0,
    this.cashSales = 0,
    this.transferSales = 0,
    this.solidSales = 0,
    this.liquidSales = 0,
    this.topProducts = const [],
    this.productionCost = 0,
    this.totalPurchasesAmount = 0,
    this.totalExpensesAmount = 0,
    this.totalPayrollAmount = 0,
    this.utilidadNeta = 0,
    this.distributionYurdenis = 0,
    this.distributionMildrey = 0,
    this.distributionNegocio = 0,
    this.expenses = const [],
    this.purchases = const [],
    this.payrollEntries = const [],
    this.workers = const [],
    this.totalOrders = 0,
    this.cancelledOrders = 0,
    this.cancellationReasons = const {},
    this.ordersWithUnconfirmedPayment = 0,
    this.avgKitchenTimeMinutes = 0,
    this.avgDeliveryTimeMinutes = 0,
  });

  DailyCloseState copyWith({
    bool? isLoading,
    String? error,
    List<RestaurantOrder>? orders,
    double? totalSales,
    double? cashSales,
    double? transferSales,
    double? solidSales,
    double? liquidSales,
    List<ProductSalesEntry>? topProducts,
    double? productionCost,
    double? totalPurchasesAmount,
    double? totalExpensesAmount,
    double? totalPayrollAmount,
    double? utilidadNeta,
    double? distributionYurdenis,
    double? distributionMildrey,
    double? distributionNegocio,
    List<DailyExpense>? expenses,
    List<DailyPurchase>? purchases,
    List<DailyPayrollData>? payrollEntries,
    List<User>? workers,
    int? totalOrders,
    int? cancelledOrders,
    Map<String, int>? cancellationReasons,
    int? ordersWithUnconfirmedPayment,
    double? avgKitchenTimeMinutes,
    double? avgDeliveryTimeMinutes,
  }) {
    return DailyCloseState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      orders: orders ?? this.orders,
      totalSales: totalSales ?? this.totalSales,
      cashSales: cashSales ?? this.cashSales,
      transferSales: transferSales ?? this.transferSales,
      solidSales: solidSales ?? this.solidSales,
      liquidSales: liquidSales ?? this.liquidSales,
      topProducts: topProducts ?? this.topProducts,
      productionCost: productionCost ?? this.productionCost,
      totalPurchasesAmount:
          totalPurchasesAmount ?? this.totalPurchasesAmount,
      totalExpensesAmount:
          totalExpensesAmount ?? this.totalExpensesAmount,
      totalPayrollAmount: totalPayrollAmount ?? this.totalPayrollAmount,
      utilidadNeta: utilidadNeta ?? this.utilidadNeta,
      distributionYurdenis:
          distributionYurdenis ?? this.distributionYurdenis,
      distributionMildrey:
          distributionMildrey ?? this.distributionMildrey,
      distributionNegocio:
          distributionNegocio ?? this.distributionNegocio,
      expenses: expenses ?? this.expenses,
      purchases: purchases ?? this.purchases,
      payrollEntries: payrollEntries ?? this.payrollEntries,
      workers: workers ?? this.workers,
      totalOrders: totalOrders ?? this.totalOrders,
      cancelledOrders: cancelledOrders ?? this.cancelledOrders,
      cancellationReasons:
          cancellationReasons ?? this.cancellationReasons,
      ordersWithUnconfirmedPayment:
          ordersWithUnconfirmedPayment ?? this.ordersWithUnconfirmedPayment,
      avgKitchenTimeMinutes:
          avgKitchenTimeMinutes ?? this.avgKitchenTimeMinutes,
      avgDeliveryTimeMinutes:
          avgDeliveryTimeMinutes ?? this.avgDeliveryTimeMinutes,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dailyCloseProvider =
    NotifierProvider<DailyCloseNotifier, DailyCloseState>(
  () => DailyCloseNotifier(),
);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class DailyCloseNotifier extends Notifier<DailyCloseState> {
  AppDatabase get _db => AppDatabase.instance;
  final _uuid = const Uuid();

  @override
  DailyCloseState build() {
    return const DailyCloseState();
  }

  // ─── Full Data Load ────────────────────────────────────────────────

  /// Load all data needed for the daily close screen.
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final todayOrders = await ref
          .read(orderRepositoryProvider)
          .getTodayOrders();
      final allProducts = await _getAllProducts();
      final todayExpenses = await _getTodayDailyExpenses();
      final todayPurchases = await _getTodayDailyPurchases();
      final todayPayroll = await _getTodayPayroll();
      final workers = await _getWorkers();
      final stateHistory = await _getTodayStateHistory(
        todayOrders.map((o) => o.id).toList(),
      );

      // ── Build product lookup ────────────────────────────────────
      final productByCode = <String, Product>{};
      for (final p in allProducts) {
        if (p.codigoCorto != null) {
          productByCode[p.codigoCorto!] = p;
        }
      }

      // ── Aggregate order data ────────────────────────────────────
      double totalSales = 0;
      double cashSales = 0;
      double transferSales = 0;
      double solidSales = 0;
      double liquidSales = 0;
      double productionCost = 0;
      final productQty = <String, int>{};
      final productAmount = <String, double>{};
      int cancelledOrders = 0;
      final cancellationReasons = <String, int>{};
      int ordersWithUnconfirmedPayment = 0;

      for (final order in todayOrders) {
        totalSales += order.montoTotal;

        // Payment method grouping (normalise to lowercase)
        final metodo = (order.metodoPago ?? '').toLowerCase();
        if (metodo == 'efectivo' || metodo == 'cash') {
          cashSales += order.montoTotal;
        } else if (metodo == 'transferencia' ||
            metodo == 'transfer' ||
            metodo == 'transferencia') {
          transferSales += order.montoTotal;
        }

        // Check for unconfirmed payment
        if (order.estado != OrderState.cancelado &&
            order.estado != OrderState.cerrado &&
            order.estado != OrderState.entregado &&
            order.estado != OrderState.pagado &&
            order.metodoPago == null) {
          ordersWithUnconfirmedPayment++;
        }

        // Cancelled orders
        if (order.estado == OrderState.cancelado) {
          cancelledOrders++;
          final reason =
              order.motivoCancelacion ?? 'Sin motivo';
          cancellationReasons[reason] =
              (cancellationReasons[reason] ?? 0) + 1;
        }

        // Product-level aggregation
        for (final item in order.items) {
          final product = productByCode[item.code];
          final categoryId = product?.categoryId ?? '';

          // Determine solid vs liquid
          if (categoryId == 'solidos') {
            solidSales += item.subtotal;
          } else {
            // liquidos, postres, or unknown → treat as liquid
            liquidSales += item.subtotal;
          }

          // Production cost
          final costPrice = product?.costPrice ?? 0;
          productionCost += item.qty * costPrice;

          // Top products
          productQty[item.code] =
              (productQty[item.code] ?? 0) + item.qty;
          productAmount[item.code] =
              (productAmount[item.code] ?? 0) + item.subtotal;
        }
      }

      // ── Top products sorted ────────────────────────────────────
      final sortedCodes = productQty.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topProducts = sortedCodes
          .map((e) => ProductSalesEntry(
                productCode: e.key,
                quantity: e.value,
                amount: productAmount[e.key] ?? 0,
              ))
          .toList();

      // ── Payroll totals ─────────────────────────────────────────
      double totalPayrollAmount = 0;
      for (final p in todayPayroll) {
        totalPayrollAmount += p.total;
      }

      // ── Manual entry totals ────────────────────────────────────
      double totalExpensesAmount = 0;
      for (final e in todayExpenses) {
        totalExpensesAmount += e.monto;
      }
      double totalPurchasesAmount = 0;
      for (final p in todayPurchases) {
        totalPurchasesAmount += p.costo;
      }

      // ── Derived calculations ───────────────────────────────────
      final utilidadNeta = totalSales -
          productionCost -
          totalExpensesAmount -
          totalPurchasesAmount -
          totalPayrollAmount;

      final distributionYurdenis = utilidadNeta * 0.30;
      final distributionMildrey = utilidadNeta * 0.30;
      final distributionNegocio = utilidadNeta * 0.40;

      // ── Operational indicators ─────────────────────────────────
      final kitchenTimes = <double>[];
      final deliveryTimes = <double>[];

      // Group state history by orderId
      final historyByOrder = <String, List<OrderStateHistoryData>>{};
      for (final h in stateHistory) {
        historyByOrder.putIfAbsent(h.orderId, () => []);
        historyByOrder[h.orderId]!.add(h);
      }

      for (final entry in historyByOrder.entries) {
        final estados = entry.value;
        // Kitchen time: enCocina → hecho
        final enCocinaTimestamps = estados
            .where((h) => h.estado == 'enCocina')
            .map((h) => h.timestamp)
            .toList()
          ..sort();
        final hechoTimestamps = estados
            .where((h) => h.estado == 'hecho')
            .map((h) => h.timestamp)
            .toList()
          ..sort();

        if (enCocinaTimestamps.isNotEmpty &&
            hechoTimestamps.isNotEmpty) {
          final kitchenMinutes = hechoTimestamps.first
              .difference(enCocinaTimestamps.first)
              .inMinutes;
          if (kitchenMinutes >= 0) {
            kitchenTimes.add(kitchenMinutes.toDouble());
          }
        }

        // Delivery time (DOMICILIO): enCamino → entregado
        final enCaminoTimestamps = estados
            .where((h) => h.estado == 'enCamino')
            .map((h) => h.timestamp)
            .toList()
          ..sort();
        final entregadoTimestamps = estados
            .where((h) => h.estado == 'entregado')
            .map((h) => h.timestamp)
            .toList()
          ..sort();

        if (enCaminoTimestamps.isNotEmpty &&
            entregadoTimestamps.isNotEmpty) {
          final deliveryMinutes = entregadoTimestamps.first
              .difference(enCaminoTimestamps.first)
              .inMinutes;
          if (deliveryMinutes >= 0) {
            deliveryTimes.add(deliveryMinutes.toDouble());
          }
        }
      }

      final avgKitchen = kitchenTimes.isNotEmpty
          ? kitchenTimes.reduce((a, b) => a + b) / kitchenTimes.length
          : 0.0;
      final avgDelivery = deliveryTimes.isNotEmpty
          ? deliveryTimes.reduce((a, b) => a + b) / deliveryTimes.length
          : 0.0;

      // ── Build state history map for orders with unconfirmed SMS ─
      int unconfirmedCount = 0;
      for (final order in todayOrders) {
        // An order with an SMS-based origin (e.g. SMS/WhatsApp)
        // that does NOT have the smsConfirmado flag
        if (order.canalOrigen != null &&
            order.canalOrigen!.toLowerCase().contains('sms') &&
            order.estado != OrderState.cancelado) {
          unconfirmedCount++;
        }
      }

      state = state.copyWith(
        isLoading: false,
        orders: todayOrders,
        totalSales: totalSales,
        cashSales: cashSales,
        transferSales: transferSales,
        solidSales: solidSales,
        liquidSales: liquidSales,
        topProducts: topProducts,
        productionCost: productionCost,
        totalPurchasesAmount: totalPurchasesAmount,
        totalExpensesAmount: totalExpensesAmount,
        totalPayrollAmount: totalPayrollAmount,
        utilidadNeta: utilidadNeta,
        distributionYurdenis: distributionYurdenis,
        distributionMildrey: distributionMildrey,
        distributionNegocio: distributionNegocio,
        expenses: todayExpenses,
        purchases: todayPurchases,
        payrollEntries: todayPayroll,
        workers: workers,
        totalOrders: todayOrders.length,
        cancelledOrders: cancelledOrders,
        cancellationReasons: cancellationReasons,
        ordersWithUnconfirmedPayment: unconfirmedCount,
        avgKitchenTimeMinutes: avgKitchen,
        avgDeliveryTimeMinutes: avgDelivery,
      );
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar datos: $e',
      );
    }
  }

  // ─── Expense CRUD ──────────────────────────────────────────────────

  /// Add a daily expense.
  Future<void> addExpense({
    required String concepto,
    required double monto,
  }) async {
    try {
      final storage = const FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id');

      await _db.into(_db.dailyExpenses).insert(
        DailyExpensesCompanion.insert(
          id: _uuid.v4(),
          concepto: concepto,
          monto: monto,
          fecha: DateTime.now(),
          registradoPorUsuarioId: Value(userId),
        ),
      );
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Error al agregar gasto: $e');
    }
  }

  /// Delete a daily expense.
  Future<void> deleteExpense(String id) async {
    try {
      await (_db.delete(_db.dailyExpenses)
            ..where((e) => e.id.equals(id)))
          .go();
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar gasto: $e');
    }
  }

  // ─── Purchase CRUD ─────────────────────────────────────────────────

  /// Add a daily purchase (insumo).
  Future<void> addPurchase({
    required String insumo,
    String? proveedor,
    required double cantidad,
    required double costo,
  }) async {
    try {
      final storage = const FlutterSecureStorage();
      final userId = await storage.read(key: 'user_id');

      await _db.into(_db.dailyPurchases).insert(
        DailyPurchasesCompanion.insert(
          id: _uuid.v4(),
          insumo: insumo,
          proveedor: Value(proveedor),
          cantidad: cantidad,
          costo: costo,
          fecha: DateTime.now(),
          registradoPorUsuarioId: Value(userId),
        ),
      );
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Error al agregar compra: $e');
    }
  }

  /// Delete a daily purchase.
  Future<void> deletePurchase(String id) async {
    try {
      await (_db.delete(_db.dailyPurchases)
            ..where((p) => p.id.equals(id)))
          .go();
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar compra: $e');
    }
  }

  // ─── Payroll CRUD ─────────────────────────────────────────────────

  /// Upsert a payroll entry for a worker on today's date.
  ///
  /// If an entry already exists for [usuarioId] today, it is updated.
  /// Otherwise a new entry is created.
  Future<void> upsertPayroll({
    required String usuarioId,
    required bool trabajo,
    String? jornada,
    required double salarioBase,
    double estimulo = 0,
  }) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existing = await (_db.select(_db.dailyPayroll)
            ..where((p) =>
                p.usuarioId.equals(usuarioId) &
                p.fecha.equals(startOfDay)))
          .getSingleOrNull();

      final total = trabajo ? salarioBase + estimulo : 0.0;

      if (existing != null) {
        await (_db.update(_db.dailyPayroll)
              ..where((p) => p.id.equals(existing.id)))
            .write(DailyPayrollCompanion(
              trabajo: Value(trabajo),
              jornada: Value(jornada),
              salarioBase: Value(salarioBase),
              estimulo: Value(estimulo),
              total: Value(total),
            ));
      } else {
        await _db.into(_db.dailyPayroll).insert(
          DailyPayrollCompanion.insert(
            id: _uuid.v4(),
            usuarioId: usuarioId,
            fecha: startOfDay,
            trabajo: trabajo,
            jornada: Value(jornada),
            salarioBase: salarioBase,
            estimulo: Value(estimulo),
            total: total,
          ),
        );
      }

      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Error al guardar nómina: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  /// Calculate the stimulus per worker based on total sales.
  ///
  /// Rule: $100 CUP per $5000 CUP sold above $25000 CUP total.
  double calculateStimulus() {
    final totalSales = state.totalSales;
    if (totalSales <= 25000) return 0;
    final excess = totalSales - 25000;
    final increments = (excess / 5000).floor();
    return increments * 100;
  }

  List<Product> _allProducts = [];

  Future<List<Product>> _getAllProducts() async {
    _allProducts = await (_db.select(_db.products)
          ..where((p) => p.isDeleted.equals(false)))
        .get();
    return _allProducts;
  }

  Future<List<DailyExpense>> _getTodayDailyExpenses() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (_db.select(_db.dailyExpenses)
          ..where((e) =>
              e.fecha.isBiggerOrEqualValue(startOfDay) &
              e.fecha.isLessThanValue(endOfDay))
          ..orderBy([(e) => OrderingTerm.desc(e.fecha)]))
        .get();
  }

  Future<List<DailyPurchase>> _getTodayDailyPurchases() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (_db.select(_db.dailyPurchases)
          ..where((p) =>
              p.fecha.isBiggerOrEqualValue(startOfDay) &
              p.fecha.isLessThanValue(endOfDay))
          ..orderBy([(p) => OrderingTerm.desc(p.fecha)]))
        .get();
  }

  Future<List<DailyPayrollData>> _getTodayPayroll() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return (_db.select(_db.dailyPayroll)
          ..where((p) =>
              p.fecha.isBiggerOrEqualValue(startOfDay) &
              p.fecha.isLessThanValue(endOfDay)))
        .get();
  }

  Future<List<User>> _getWorkers() async {
    return (_db.select(_db.users)
          ..where((u) => u.active.equals(true))
          ..orderBy([(u) => OrderingTerm.asc(u.fullName)]))
        .get();
  }

  Future<List<OrderStateHistoryData>> _getTodayStateHistory(
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return [];
    return (_db.select(_db.orderStateHistory)
          ..where((h) => h.orderId.isIn(orderIds)))
        .get();
  }
}
