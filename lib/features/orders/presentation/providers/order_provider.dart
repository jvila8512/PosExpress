import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/orders/infrastructure/repositories/order_repository_impl.dart';
import 'package:etecsa/features/sms/domain/entities/sms_payload.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _orderDatasourceProvider = Provider<OrderDatasource>((ref) {
  return OrderDatasource(AppDatabase.instance);
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(_orderDatasourceProvider));
});

final smsServiceProvider = Provider<SmsService>((ref) {
  return SmsService();
});

final orderProvider = NotifierProvider<OrderNotifier, OrderState>(() => OrderNotifier());

// ---------------------------------------------------------------------------
// Order Notifier
// ---------------------------------------------------------------------------

class OrderNotifier extends Notifier<OrderState> {
  List<RestaurantOrder> _orders = [];
  String? _error;
  bool _isLoading = false;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);
  SmsService get _smsService => ref.read(smsServiceProvider);

  @override
  OrderState build() {
    return OrderState.registrado;
  }

  List<RestaurantOrder> get orders => _orders;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Create a new order and send PED SMS.
  Future<void> createOrder(RestaurantOrder order) async {
    _isLoading = true;
    _error = null;

    try {
      await _repository.createOrder(order);

      // Send PED SMS via SmsService
      final smsPayload = SmsPayload(
        type: 'PED',
        orderId: order.id,
        client: '', // Would be resolved from client
        phone: '',
        address: '',
        items: order.items
            .map((i) => Item(code: i.code, qty: i.qty))
            .toList(),
        time: order.horaSolicitada,
        payment: order.metodoPago,
        amount: order.montoTotal,
      );

      await _smsService.sendSms('', smsPayload.toJson());
      _smsService.startAckTimer(order.id, () {
        _error = 'Cocina did not confirm order #${order.id}';
      });

      _orders = [order, ..._orders];
    } catch (e) {
      _error = 'Error creating order: $e';
    } finally {
      _isLoading = false;
    }
  }

  /// Update order state and send appropriate SMS.
  Future<void> updateState(String orderId, OrderState newState) async {
    _error = null;

    try {
      await _repository.updateOrderState(orderId, newState);

      // Send state-appropriate SMS
      String smsType;
      switch (newState) {
        case OrderState.hecho:
          smsType = 'HEC';
          break;
        case OrderState.entregado:
          smsType = 'ENT';
          break;
        case OrderState.cancelado:
          smsType = 'CAN';
          break;
        default:
          smsType = '';
      }

      if (smsType.isNotEmpty) {
        final payload = SmsPayload(type: smsType, orderId: orderId);
        await _smsService.sendSms('', payload.toJson());
      }

      // Update local list
      _orders = _orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(estado: newState);
        }
        return o;
      }).toList();
    } catch (e) {
      _error = 'Error updating order state: $e';
    }
  }

  /// Load today's orders from the repository.
  Future<void> loadTodayOrders() async {
    _isLoading = true;
    _error = null;

    try {
      _orders = await _repository.getTodayOrders();
    } catch (e) {
      _error = 'Error loading orders: $e';
    } finally {
      _isLoading = false;
    }
  }
}
