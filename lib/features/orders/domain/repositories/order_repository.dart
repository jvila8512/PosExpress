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
}
