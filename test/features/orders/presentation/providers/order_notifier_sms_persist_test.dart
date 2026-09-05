import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/contacts/domain/entities/trusted_contact.dart';
import 'package:etecsa/features/contacts/domain/repositories/contact_repository.dart';
import 'package:etecsa/features/contacts/presentation/providers/contact_provider.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/repositories/order_repository.dart';
import 'package:etecsa/features/orders/infrastructure/datasources/order_datasource.dart';
import 'package:etecsa/features/orders/presentation/providers/order_provider.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

// ---------------------------------------------------------------------------
// Fakes (hand-rolled, sin mocks externos)
// ---------------------------------------------------------------------------

class _SmsStatusCall {
  final String orderId;
  final bool enviado;
  final int? intentos;
  const _SmsStatusCall(this.orderId, this.enviado, this.intentos);
}

class _FakeOrderRepository implements OrderRepository {
  List<RestaurantOrder> todayOrders = [];
  final List<RestaurantOrder> created = [];
  final List<_SmsStatusCall> smsStatusCalls = [];
  final List<Map<String, Object>> confirmCalls = [];
  bool throwOnMarkSmsStatus = false;

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
  Future<List<RestaurantOrder>> getTodayOrders() async =>
      List.of(todayOrders);

  @override
  Future<List<RestaurantOrder>> searchOrders(String query) async => const [];

  @override
  Future<void> updateOrder(RestaurantOrder order) async {}

  @override
  Future<void> updateOrderState(String orderId, OrderState newState) async {}

  @override
  Future<void> markSmsStatus(String orderId,
      {required bool enviado, int? intentos}) async {
    if (throwOnMarkSmsStatus) throw Exception('BD caída');
    smsStatusCalls.add(_SmsStatusCall(orderId, enviado, intentos));
  }

  @override
  Future<void> markSmsConfirmado(String orderId, bool confirmado) async {
    confirmCalls.add({'orderId': orderId, 'confirmado': confirmado});
  }
}

class _FakeSmsService extends SmsService {
  bool result = true;

  @override
  Future<bool> sendSms(String phoneNumber, String message) async => result;
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

void main() {
  group('isSmsPendingState (función pura)', () {
    test('registrado/enCocina/hecho/enCamino son pendientes', () {
      expect(isSmsPendingState(OrderState.registrado), isTrue);
      expect(isSmsPendingState(OrderState.enCocina), isTrue);
      expect(isSmsPendingState(OrderState.hecho), isTrue);
      expect(isSmsPendingState(OrderState.enCamino), isTrue);
    });

    test('terminales y mesa-entregada NO son pendientes', () {
      expect(isSmsPendingState(OrderState.entregado), isFalse);
      expect(isSmsPendingState(OrderState.entregadoEnMesa), isFalse);
      expect(isSmsPendingState(OrderState.pagado), isFalse);
      expect(isSmsPendingState(OrderState.cerrado), isFalse);
      expect(isSmsPendingState(OrderState.cancelado), isFalse);
    });
  });

  group('resolveNextRetryCount (función pura)', () {
    test('sin override → incrementa en 1', () {
      expect(resolveNextRetryCount(current: 0), 1);
      expect(resolveNextRetryCount(current: 2), 3);
    });

    test('con override → lo setea tal cual', () {
      expect(resolveNextRetryCount(current: 5, override: 0), 0);
      expect(resolveNextRetryCount(current: 1, override: 7), 7);
    });
  });

  group('OrderNotifier.createOrder persiste estado SMS', () {
    test('sms-ok → markSmsStatus(enviado:true) y no queda pendiente',
        () async {
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
      expect(repo.smsStatusCalls, hasLength(1));
      expect(repo.smsStatusCalls.single.orderId, 'R1-0101-001');
      expect(repo.smsStatusCalls.single.enviado, isTrue);
      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
    });

    test('sms-false → markSmsStatus(enviado:false) y queda pendiente',
        () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = false;
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      final ok = await notifier.createOrder(
        _sampleOrder(),
        destinationPhone: '555-1234',
      );

      expect(ok, isFalse);
      expect(repo.smsStatusCalls, hasLength(1));
      expect(repo.smsStatusCalls.single.enviado, isFalse);
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
    });

    test('si persistir falla, igual devuelve el resultado del SMS', () async {
      final repo = _FakeOrderRepository()..throwOnMarkSmsStatus = true;
      final sms = _FakeSmsService()..result = true;
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      final ok = await notifier.createOrder(
        _sampleOrder(),
        destinationPhone: '555-1234',
      );

      expect(ok, isTrue);
      expect(notifier.orders.map((o) => o.id), contains('R1-0101-001'));
      expect(notifier.error, isNotNull);
    });
  });

  group('OrderNotifier.resendSms persiste estado SMS', () {
    test('ok → markSmsStatus(enviado:true) y limpia pendiente', () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = false;
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.createOrder(_sampleOrder(), destinationPhone: '555-0');
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
      repo.smsStatusCalls.clear();

      sms.result = true;
      final ok = await notifier.resendSms('R1-0101-001');

      expect(ok, isTrue);
      expect(repo.smsStatusCalls, hasLength(1));
      expect(repo.smsStatusCalls.single.orderId, 'R1-0101-001');
      expect(repo.smsStatusCalls.single.enviado, isTrue);
      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
      expect(notifier.orders.single.intentosReenvio, 1);
      expect(notifier.orders.single.smsEnviado, isTrue);
    });

    test('fallo → markSmsStatus(enviado:false) y mantiene pendiente',
        () async {
      final repo = _FakeOrderRepository();
      final sms = _FakeSmsService()..result = false;
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.createOrder(_sampleOrder(), destinationPhone: '555-0');
      repo.smsStatusCalls.clear();

      final ok = await notifier.resendSms('R1-0101-001');

      expect(ok, isFalse);
      expect(repo.smsStatusCalls, hasLength(1));
      expect(repo.smsStatusCalls.single.enviado, isFalse);
      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
      expect(notifier.orders.single.intentosReenvio, 1);
    });
  });

  group('OrderNotifier.loadTodayOrders rehidrata pendientes', () {
    test('pedido de hoy no enviado y no-terminal → pendiente', () async {
      final repo = _FakeOrderRepository()
        ..todayOrders = [_sampleOrder()];
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadTodayOrders();

      expect(notifier.isSmsPending('R1-0101-001'), isTrue);
    });

    test('pedido ya enviado → NO pendiente tras recargar', () async {
      final repo = _FakeOrderRepository()
        ..todayOrders = [_sampleOrder().copyWith(smsEnviado: true)];
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadTodayOrders();

      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
    });

    test('pedido no-terminal=false (entregado) sin SMS → NO pendiente',
        () async {
      final repo = _FakeOrderRepository()
        ..todayOrders = [
          _sampleOrder().copyWith(estado: OrderState.entregado),
        ];
      final sms = _FakeSmsService();
      final contacts = _FakeContactRepository();
      final container = _makeContainer(repo, sms, contacts);
      final notifier = container.read(orderProvider.notifier);

      await notifier.loadTodayOrders();

      expect(notifier.isSmsPending('R1-0101-001'), isFalse);
    });
  });
}
