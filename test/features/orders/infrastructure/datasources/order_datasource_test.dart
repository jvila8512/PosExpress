import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';

void main() {
  group('RestaurantOrder entity', () {
    test('can be created with required fields only', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        estado: OrderState.registrado,
        creadoPorUsuarioId: 'user-001',
      );

      expect(order.id, 'R1-0712-001');
      expect(order.tipoPedido, 'DOMICILIO');
      expect(order.estado, OrderState.registrado);
      expect(order.items, isEmpty);
    });

    test('can be created with full fields', () {
      final order = RestaurantOrder(
        id: 'R1-0712-002',
        tipoPedido: 'MESA',
        clienteId: 'CLI-002',
        mesaId: 'mesa-5',
        estado: OrderState.enCocina,
        canalOrigen: 'sms',
        horaSolicitada: '19:30',
        metodoPago: 'EF',
        montoTotal: 950.0,
        creadoPorUsuarioId: 'user-001',
        items: [
          OrderItem(code: 'H1', qty: 2, price: 250.0),
          OrderItem(code: 'P1', qty: 1, price: 450.0),
        ],
      );

      expect(order.mesaId, 'mesa-5');
      expect(order.montoTotal, 950.0);
      expect(order.items.length, 2);
    });

    test('can transition state via copyWith', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        estado: OrderState.registrado,
        creadoPorUsuarioId: 'user-001',
      );

      final updated = order.copyWith(estado: OrderState.enCocina);
      expect(updated.estado, OrderState.enCocina);
      expect(updated.id, order.id); // unchanged
    });

    test('copyWith preserves other fields', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        estado: OrderState.registrado,
        creadoPorUsuarioId: 'user-001',
        metodoPago: 'EF',
        montoTotal: 500.0,
      );

      final updated = order.copyWith(metodoPago: 'TR');
      expect(updated.metodoPago, 'TR');
      expect(updated.montoTotal, 500.0); // unchanged
      expect(updated.estado, OrderState.registrado); // unchanged
    });

    test('toJson produces correct map', () {
      final order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        estado: OrderState.registrado,
        creadoPorUsuarioId: 'user-001',
        items: [
          OrderItem(code: 'H1', qty: 2, price: 250.0),
        ],
      );

      final json = order.toJson();
      expect(json['id'], 'R1-0712-001');
      expect(json['tipo_pedido'], 'DOMICILIO');
      expect(json['estado'], 'registrado');
      expect(json['items'], isA<List>());
      expect((json['items'] as List).length, 1);
    });

    test('fromJson creates correct entity', () {
      final json = {
        'id': 'R1-0712-001',
        'tipo_pedido': 'DOMICILIO',
        'cliente_id': 'CLI-001',
        'estado': 'registrado',
        'creado_por_usuario_id': 'user-001',
        'items': [
          {'code': 'H1', 'qty': 2, 'price': 250.0},
        ],
      };

      final order = RestaurantOrder.fromJson(json);
      expect(order.id, 'R1-0712-001');
      expect(order.tipoPedido, 'DOMICILIO');
      expect(order.estado, OrderState.registrado);
      expect(order.items.length, 1);
      expect(order.items[0].code, 'H1');
    });
  });

  group('OrderItem entity', () {
    test('can be created', () {
      final item = OrderItem(code: 'H1', qty: 2, price: 250.0);
      expect(item.code, 'H1');
      expect(item.qty, 2);
      expect(item.price, 250.0);
    });

    test('toJson produces correct map', () {
      final item = OrderItem(code: 'H1', qty: 2, price: 250.0);
      final json = item.toJson();
      expect(json['code'], 'H1');
      expect(json['qty'], 2);
      expect(json['price'], 250.0);
    });

    test('fromJson creates correct entity', () {
      final json = {'code': 'H1', 'qty': 2, 'price': 250.0};
      final item = OrderItem.fromJson(json);
      expect(item.code, 'H1');
      expect(item.qty, 2);
      expect(item.price, 250.0);
    });
  });
}
