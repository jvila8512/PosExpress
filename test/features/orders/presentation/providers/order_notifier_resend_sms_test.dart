import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart';
import 'package:etecsa/features/contacts/domain/repositories/contact_repository.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// Fakes (hand-rolled, sin mocks externos)
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  final List<RestaurantOrder> created = [];

  @override
  Future<void> createOrder(RestaurantOrder order) async {
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
  int ackTimerStarts = 0;

  @override
  Future<bool> sendSms(String phoneNumber, String message) async {
    lastPhone = phoneNumber;
    lastMessage = message;
    return result;
  }

  @override
  void startAckTimer(
    String orderId,
    void Function() onTimeout, {
    int timeoutMs = 300000,
  }) {
    // No-op: registra sin crear un Timer real de 5 minutos.
    ackTimerStarts++;
  }
}

class _FakeContactRepository implements ContactRepository {
  List<String> kitchenPhones = ['555-1234'];

  @override
  Future<void> createContact(TrustedContact contact) async {}

  @override
  Future<void> deleteContact(String id) async {}

  @override
  Future<List<String>> getActivePhonesForRole(String rol) async =>
      List.of(kitchenPhones);

  @override
  Future<TrustedContact?> getContactById(String id) async => null;

  @override
  Future<List<TrustedContact>> getContacts({String? rol}) async => const [];

  @override
  Future<void> toggleContactActive(String id, bool active) async {}

  @override
  Future<void> updateContact(TrustedContact contact) async {}
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
  _FakeOrderRepository repo,
  _FakeSmsService sms,
  _FakeContactRepository contacts,
) {
  final container = ProviderContainer(
    overrides: [
      orderRepositoryProvider.overrideWithValue(repo),
      smsServiceProvider.overrideWithValue(sms),
      contactRepositoryProvider.overrideWithValue(contacts),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Deja un pedido en _orders con SMS pendiente: createOrder con SMS fallido.
Future<OrderNotifier> _notifierWithPendingOrder(
  ProviderContainer container,
  _FakeSmsService sms,
) async {
  final notifier = container.read(orderProvider.notifier);
  sms.result = false;
  await notifier.createOrder(_sampleOrder(), destinationPhone: '555-0000');
  return notifier;
}

void main() {
  group('OrderNotifier.isSmsPending', () {
    test(
      'createOrder sms-false → marca el pedido como SMS pendiente',
      () async {
        final repo = _FakeOrderRepository();
        final sms = _FakeSmsService();
        final contacts = _FakeContactRepository();
        final container = _makeContainer(repo, sms, contacts);
        final notifier = container.read(orderProvider.notifier);

        sms.result = false;
        final ok = await notifier.createOrder(
          _sampleOrder(),
          destinationPhone: '555-1234',
        );

        expect(ok, isFalse);
        expect(notifier.isSmsPending('R1-0101-001'), isTrue);
      },
    );

    test('createOrder sms-ok → NO queda pendiente', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = true;
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      final ok = await notifier.createOrder(
        _sampleOrder(),
        destinationPhone: '555-1234',
      );

      expect(ok, isTrue);
      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
    });

    test('pedido desconocido → NO pendiente', () {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      expect(notifier.isSmsPending('NO-EXISTE'), isFalse);
    });
  });

  group('OrderNotifier.resendSms', () {
    test('ok → true, limpia pendiente y reenvía al número de Cocina', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository()..kitchenPhones = ['555-9999'];
      final container = _makeContainer(repo, sms, contacts);
      final notifier = await _notifierWithPendingOrder(container, sms);
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);

      sms.result = true;
      final ok = await notifier.resendSms('R1-0101-001');

      expect(ok, isTrue);
      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
      expect(sms.lastPhone, '555-9999');
      expect(sms.lastMessage, contains('R1-0101-001'));
      expect(sms.ackTimerStarts, greaterThanOrEqualTo(1));
    });

    test('sin número de Cocina → false y mantiene pendiente', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository()..kitchenPhones = [];
      final container = _makeContainer(repo, sms, contacts);
      final notifier = await _notifierWithPendingOrder(container, sms);
      sms.lastPhone = null;
      sms.result = true;

      final ok = await notifier.resendSms('R1-0101-001');

      expect(ok, isFalse);
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
      // Sin número no debe intentar ningún envío.
      expect(sms.lastPhone, isNull);
    });

    test('pedido inexistente → false', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      final ok = await notifier.resendSms('NO-EXISTE');

      expect(ok, isFalse);
      expect(sms.lastPhone, isNull);
    });

    test('sms-false → false y mantiene pendiente', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = await _notifierWithPendingOrder(container, sms);

      sms.result = false;
      final ok = await notifier.resendSms('R1-0101-001');

      expect(ok, isFalse);
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
    });
  });
}
