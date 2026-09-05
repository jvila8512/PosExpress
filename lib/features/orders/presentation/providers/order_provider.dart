import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:etecsa/core/database/app_database.dart' hide RestaurantOrder;
import 'package:etecsa/features/contacts/domain/repositories/contact_repository.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/orders/infrastructure/repositories/order_repository_impl.dart';
import 'package:etecsa/features/sms/domain/entities/sms_payload.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// SMS pending helpers (funciones puras, testeables sin BD)
// ---------------------------------------------------------------------------

/// Estados en los que un pedido de hoy sin SMS enviado sigue pendiente.
///
/// PED se envía al crear (registrado); mientras el pedido siga en flujo
/// de cocina/reparto sin `smsEnviado`, se ofrece reenvío. Terminales
/// (entregado, pagado, cerrado, cancelado) y mesa ya entregada nunca
/// son pendientes.
const Set<OrderState> smsPendingStates = {
  OrderState.registrado,
  OrderState.enCocina,
  OrderState.hecho,
  OrderState.enCamino,
};

/// Returns `true` when orders in [state] still await their PED SMS.
bool isSmsPendingState(OrderState state) => smsPendingStates.contains(state);

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

final orderProvider = NotifierProvider<OrderNotifier, OrderState>(
  () => OrderNotifier(),
);

// ---------------------------------------------------------------------------
// Order Notifier
// ---------------------------------------------------------------------------

class OrderNotifier extends Notifier<OrderState> {
  List<RestaurantOrder> _orders = [];
  final Set<String> _smsPendingIds = {};
  String? _error;
  bool _isLoading = false;

  OrderRepository get _repository => ref.read(orderRepositoryProvider);
  SmsService get _smsService => ref.read(smsServiceProvider);
  ContactRepository get _contactRepository =>
      ref.read(contactRepositoryProvider);

  @override
  OrderState build() {
    return OrderState.registrado;
  }

  List<RestaurantOrder> get orders => _orders;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Whether the PED SMS for [orderId] is still pending.
  ///
  /// La entidad (estado persistido en BD) manda cuando el pedido está en
  /// la lista local; el set en memoria queda como caché para ids aún no
  /// cargados. Solo pedidos de hoy en estados no-terminales sin
  /// `smsEnviado` cuentan como pendientes.
  bool isSmsPending(String orderId) {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order != null) {
      return !order.smsEnviado && isSmsPendingState(order.estado);
    }
    return _smsPendingIds.contains(orderId);
  }

  /// Create a new order and send PED SMS.
  ///
  /// [destinationPhone] is the Cocina/kitchen phone number to send the PED to.
  ///
  /// Returns true when the order was saved AND the SMS was accepted for
  /// sending; false when the order was saved locally but the SMS was not
  /// sent (caller should surface "SMS pendiente" and offer a retry).
  ///
  /// Repository errors are recorded in [error] and rethrown so the UI
  /// can react instead of showing a false success.
  Future<bool> createOrder(
    RestaurantOrder order, {
    String? destinationPhone,
  }) async {
    _isLoading = true;
    _error = null;

    try {
      await _repository.createOrder(order);
    } catch (e) {
      _error = 'Error creating order: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }

    // Send PED SMS via SmsService
    final smsPayload = SmsPayload(
      type: 'PED',
      orderId: order.id,
      client: '', // Would be resolved from client
      phone: '',
      address: '',
      items: order.items.map((i) => Item(code: i.code, qty: i.qty)).toList(),
      time: order.horaSolicitada,
      payment: order.metodoPago,
      amount: order.montoTotal,
    );

    final smsSent = await _smsService.sendSms(
      destinationPhone ?? '',
      smsPayload.toJson(),
    );

    // Persiste el resultado en BD (best-effort: si falla, el pedido y el
    // SMS ya existen; se informa sin revertir el resultado).
    try {
      await _repository.markSmsStatus(order.id, enviado: smsSent);
    } catch (e) {
      _error = 'No se pudo guardar el estado del SMS: $e';
    }

    if (smsSent) {
      _smsPendingIds.remove(order.id);
      _smsService.startAckTimer(order.id, () {
        _error = 'Cocina did not confirm order #${order.id}';
      });
    } else {
      _smsPendingIds.add(order.id);
    }

    _orders = [
      order.copyWith(smsEnviado: smsSent ? true : order.smsEnviado),
      ..._orders
    ];
    return smsSent;
  }

  /// Reenvía el SMS PED de un pedido cuyo envío quedó pendiente.
  ///
  /// Resuelve el número de Cocina con `contactRepository` (igual que el
  /// form), reconstruye el payload PED con el mismo formato de
  /// [createOrder] y lo envía. Si el envío tiene éxito, saca el pedido
  /// de pendientes y (re)arranca el ACK timer.
  ///
  /// Devuelve false (y el pedido sigue pendiente) cuando el pedido no
  /// existe en [_orders], no hay número de Cocina configurado o el
  /// envío falla.
  Future<bool> resendSms(String orderId) async {
    final order = _orders.where((o) => o.id == orderId).firstOrNull;
    if (order == null) return false;

    final kitchenPhones = await _contactRepository.getActivePhonesForRole(
      'cocina',
    );
    final kitchenPhone = kitchenPhones.firstOrNull;
    if (kitchenPhone == null) return false;

    final smsPayload = SmsPayload(
      type: 'PED',
      orderId: order.id,
      client: '',
      phone: '',
      address: '',
      items: order.items.map((i) => Item(code: i.code, qty: i.qty)).toList(),
      time: order.horaSolicitada,
      payment: order.metodoPago,
      amount: order.montoTotal,
    );

    final smsSent = await _smsService.sendSms(
      kitchenPhone,
      smsPayload.toJson(),
    );

    // Persiste el resultado e incrementa intentos en BD (best-effort:
    // se informa el fallo sin cambiar el resultado del envío).
    try {
      await _repository.markSmsStatus(order.id, enviado: smsSent);
    } catch (e) {
      _error = 'No se pudo guardar el estado del SMS: $e';
    }

    if (smsSent) {
      _smsPendingIds.remove(orderId);
      _smsService.startAckTimer(order.id, () {
        _error = 'Cocina did not confirm order #${order.id}';
      });
    }
    _orders = _orders.map((o) {
      if (o.id == orderId) {
        return o.copyWith(
          smsEnviado: smsSent ? true : o.smsEnviado,
          intentosReenvio: o.intentosReenvio + 1,
        );
      }
      return o;
    }).toList();
    return smsSent;
  }

  /// Update order state and send appropriate SMS.
  ///
  /// [destinationPhone] is the phone to send the state notification to
  /// (e.g. Redes phone for HEC, client phone for ENT).
  Future<void> updateState(
    String orderId,
    OrderState newState, {
    String? destinationPhone,
  }) async {
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
        await _smsService.sendSms(destinationPhone ?? '', payload.toJson());
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
  ///
  /// Rehidrata el caché de SMS pendientes desde el estado persistido:
  /// solo pedidos de hoy con `smsEnviado == false` y estado no-terminal
  /// quedan marcados (los históricos viejos nunca se marcan porque esta
  /// lista solo trae el día actual).
  Future<void> loadTodayOrders() async {
    _isLoading = true;
    _error = null;

    try {
      _orders = await _repository.getTodayOrders();
      _smsPendingIds
        ..clear()
        ..addAll(_orders
            .where((o) => !o.smsEnviado && isSmsPendingState(o.estado))
            .map((o) => o.id));
    } catch (e) {
      _error = 'Error loading orders: $e';
    } finally {
      _isLoading = false;
    }
  }
}
