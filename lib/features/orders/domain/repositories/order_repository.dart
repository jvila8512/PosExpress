import '../entities/restaurant_order.dart';
import '../entities/order_state.dart';

/// Abstract repository for restaurant orders.
abstract class OrderRepository {
  /// Create a new order.
  Future<void> createOrder(RestaurantOrder order);

  /// Get an order by ID.
  Future<RestaurantOrder?> getOrderById(String id);

  /// Get all orders for today.
  Future<List<RestaurantOrder>> getTodayOrders();

  /// Get all orders created since [from] (inclusive), newest first.
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from);

  /// Get orders by state.
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state);

  /// Update order state.
  Future<void> updateOrderState(String orderId, OrderState newState);

  /// Update order with full data.
  Future<void> updateOrder(RestaurantOrder order);

  /// Get all orders (for history).
  Future<List<RestaurantOrder>> getAllOrders();

  /// Search orders by client name or phone.
  Future<List<RestaurantOrder>> searchOrders(String query);

  /// Persist the PED SMS send result for [orderId].
  ///
  /// Updates `sms_enviado` and `intentos_reenvio`: when [intentos] is
  /// given it is set as-is, otherwise the current value is incremented
  /// by 1.
  Future<void> markSmsStatus(String orderId,
      {required bool enviado, int? intentos});

  /// Persist the kitchen ACK for the PED SMS of [orderId].
  Future<void> markSmsConfirmado(String orderId, bool confirmado);
}
