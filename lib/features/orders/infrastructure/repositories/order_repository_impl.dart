import '../../domain/entities/restaurant_order.dart';
import '../../domain/entities/order_state.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_datasource.dart';

/// Implementation of [OrderRepository] backed by Drift.
class OrderRepositoryImpl extends OrderRepository {
  final OrderDatasource _datasource;

  OrderRepositoryImpl(this._datasource);

  @override
  Future<List<RestaurantOrder>> getAllOrders() =>
      _datasource.getAllOrders();

  @override
  Future<void> createOrder(RestaurantOrder order) =>
      _datasource.createOrder(order);

  @override
  Future<RestaurantOrder?> getOrderById(String id) =>
      _datasource.getOrderById(id);

  @override
  Future<List<RestaurantOrder>> getTodayOrders() =>
      _datasource.getTodayOrders();

  @override
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from) =>
      _datasource.getOrdersSince(from);

  @override
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) =>
      _datasource.getOrdersByState(state);

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) =>
      _datasource.updateOrderState(orderId, newState);

  @override
  Future<void> updateOrder(RestaurantOrder order) =>
      _datasource.updateOrder(order);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) =>
      _datasource.searchOrders(query);

  @override
  Future<void> markSmsStatus(String orderId,
          {required bool enviado, int? intentos}) =>
      _datasource.markSmsStatus(orderId, enviado: enviado, intentos: intentos);

  @override
  Future<void> markSmsConfirmado(String orderId, bool confirmado) =>
      _datasource.markSmsConfirmado(orderId, confirmado);
}
