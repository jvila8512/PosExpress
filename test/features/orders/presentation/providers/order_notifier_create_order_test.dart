import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// Fakes (sin mocks externos: hand-rolled, 2 fakes vs 3+ asserts por test)
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  final List<RestaurantOrder> created = [];
  bool throwOnCreate = false;

  @override
  Future<void> createOrder(RestaurantOrder order) async {
    if (throwOnCreate) throw Exception('DB caída');
    created.add(order);
  }

  @override
  Future<List<RestaurantOrder>> getAllOrders() async => List.of(created);

  @override
  Future<RestaurantOrder?> getOrderById(String id) async =>
      created.where((o) => o.id == id).firstOrNull;

  @override
  Future<List<RestaurantOrder>> getOrdersByState(OrderState state) async =>
      created.where((o) => o.estado == state).toList();

  @override
  Future<List<RestaurantOrder>> getOrdersSince(DateTime from) async =>
      List.of(created);

  @override
  Future<List<RestaurantOrder>> getTodayOrders() async => List.of(created);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {}

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {}

  @override
  Future<void> markSmsStatus(String orderId,
      {required bool enviado, int? intentos}) async {}

  @override
  Future<void> markSmsConfirmado(String orderId, bool confirmado) async {}
}

class _FakeSmsService extends SmsService {
  bool result = true;
  String? lastPhone;
  String? lastMessage;

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    lastPhone = phoneNumber;
    lastMessage = message;
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

RestaurantOrder _sampleOrder() => const RestaurantOrder(
      id: 'R1-0101-001',
      tipoPedido: 'DOMICILIO',
      clienteId: 'CLI-1',
      estado: OrderState.registrado,
      creadoPorUsuarioId: 'u1',
      items: [OrderItem(code: 'H1', qty: 2, price: 100)],
    );

ProviderContainer _makeContainer(
    _FakeOrderRepository repo, _FakeSmsService sms) {
  final container = ProviderContainer(overrides: [
    orderRepositoryProvider.overrideWithValue(repo),
    smsServiceProvider.overrideWithValue(sms),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OrderNotifier.createOrder devuelve bool y no traga errores', () {
    test('repo-ok + sms-ok → true, guarda pedido y envía SMS al destino',
        () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = true;
      final container = _makeContainer(repo, sms);
      final notifier = container.read(orderProvider.notifier);

      final bool ok = await notifier.createOrder(
        _sampleOrder(),
        destinationPhone: '555-1234',
      );

      expect(ok, isTrue);
      expect(repo.created, hasLength(1));
      expect(sms.lastPhone, '555-1234');
      expect(sms.lastMessage, contains('R1-0101-001'));
      expect(notifier.orders.map((o) => o.id), contains('R1-0101-001'));
      expect(notifier.error, isNull);
    });

    test('sms-false → false pero el pedido queda guardado (SMS pendiente)',
        () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = false;
      final container = _makeContainer(repo, sms);
      final notifier = container.read(orderProvider.notifier);

      final bool ok = await notifier.createOrder(
        _sampleOrder(),
        destinationPhone: '555-1234',
      );

      expect(ok, isFalse);
      expect(repo.created, hasLength(1));
      expect(notifier.orders, hasLength(1));
      expect(notifier.error, isNull);
    });

    test('repo-throw → relanza para que el form lo vea y setea error',
        () async {
      final repo = _FakeOrderRepository()..throwOnCreate = true;
      final sms = _FakeSmsService();
      final container = _makeContainer(repo, sms);
      final notifier = container.read(orderProvider.notifier);

      await expectLater(
        () => notifier.createOrder(
          _sampleOrder(),
          destinationPhone: '555-1234',
        ),
        throwsException,
      );
      expect(notifier.error, isNotNull);
      expect(notifier.orders, isEmpty);
      // El SMS jamás debió intentarse si el guardado falló.
      expect(sms.lastPhone, isNull);
    });
  });
}
