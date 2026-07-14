import 'package:etecsa/core/database/app_database.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:uuid/uuid.dart';

/// Drift datasource for restaurant orders.
class OrderDatasource {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OrderDatasource(this._db);

  Future<void> createOrder(RestaurantOrder order) async {
    await _db.into(_db.restaurantOrders).insert(
      RestaurantOrdersCompanion.insert(
        id: order.id,
        tipoPedido: order.tipoPedido,
        clienteId: order.clienteId,
        mesaId: Value(order.mesaId),
        estado: order.estado.name,
        canalOrigen: Value(order.canalOrigen),
        horaSolicitada: Value(order.horaSolicitada),
        metodoPago: Value(order.metodoPago),
        montoTotal: order.montoTotal,
        creadoPorUsuarioId: order.creadoPorUsuarioId,
      ),
    );

    // Insert order items
    for (final item in order.items) {
      await _db.into(_db.restaurantOrderItems).insert(
        RestaurantOrderItemsCompanion.insert(
          id: _uuid.v4(),
          orderId: order.id,
          productoCodigo: item.code,
          cantidad: item.qty.toDouble(),
          precioUnitario: item.price,
          subtotal: item.subtotal,
        ),
      );
    }
  }

  Future<RestaurantOrder?> getOrderById(String id) async {
    final row = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final items = await _getOrderItems(id);
    return _mapRowToOrder(row, items);
  }

  Future<List<RestaurantOrder>> getTodayOrders() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.fechaCreacion.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) async {
    final stateName = state.name;
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) => o.estado.equals(stateName))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<void> updateOrderState(String orderId, OrderState newState) async {
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(orderId)))
        .write(RestaurantOrdersCompanion(
          estado: Value(newState.name),
        ));
  }

  Future<void> updateOrder(RestaurantOrder order) async {
    await (_db.update(_db.restaurantOrders)
          ..where((o) => o.id.equals(order.id)))
        .write(RestaurantOrdersCompanion(
          tipoPedido: Value(order.tipoPedido),
          clienteId: Value(order.clienteId),
          mesaId: Value(order.mesaId),
          estado: Value(order.estado.name),
          canalOrigen: Value(order.canalOrigen),
          horaSolicitada: Value(order.horaSolicitada),
          metodoPago: Value(order.metodoPago),
          montoTotal: Value(order.montoTotal),
          motivoCancelacion: Value(order.motivoCancelacion),
        ));
  }

  Future<List<RestaurantOrder>> getAllOrders() async {
    final rows = await (_db.select(_db.restaurantOrders)
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<RestaurantOrder>> searchOrders(String query) async {
    // Search by ID or client ID
    final rows = await (_db.select(_db.restaurantOrders)
          ..where((o) =>
              o.id.contains(query) | o.clienteId.contains(query))
          ..orderBy([(o) => OrderingTerm.desc(o.fechaCreacion)]))
        .get();

    final orders = <RestaurantOrder>[];
    for (final row in rows) {
      final items = await _getOrderItems(row.id);
      orders.add(_mapRowToOrder(row, items));
    }
    return orders;
  }

  Future<List<RestaurantOrderItem>> _getOrderItems(String orderId) async {
    return (_db.select(_db.restaurantOrderItems)
          ..where((i) => i.orderId.equals(orderId)))
        .get();
  }

  RestaurantOrder _mapRowToOrder(
    RestaurantOrder row,
    List<RestaurantOrderItem> items,
  ) {
    return RestaurantOrder(
      id: row.id,
      tipoPedido: row.tipoPedido,
      clienteId: row.clienteId,
      mesaId: row.mesaId,
      estado: _parseState(row.estado),
      canalOrigen: row.canalOrigen,
      horaSolicitada: row.horaSolicitada,
      metodoPago: row.metodoPago,
      montoTotal: row.montoTotal,
      creadoPorUsuarioId: row.creadoPorUsuarioId,
      fechaCreacion: row.fechaCreacion,
      items: items.map((i) => OrderItem(
        code: i.productoCodigo,
        qty: i.cantidad.toInt(),
        price: i.precioUnitario,
      )).toList(),
      motivoCancelacion: row.motivoCancelacion,
    );
  }

  OrderState _parseState(String state) {
    return OrderState.values.firstWhere(
      (s) => s.name == state,
      orElse: () => OrderState.registrado,
    );
  }
}
