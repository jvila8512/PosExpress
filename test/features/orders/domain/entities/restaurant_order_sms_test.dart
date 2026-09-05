import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';

void main() {
  group('RestaurantOrder SMS persistence fields', () {
    test('defaults: smsEnviado=false, smsConfirmado=false, intentosReenvio=0',
        () {
      const order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        creadoPorUsuarioId: 'user-001',
      );

      expect(order.smsEnviado, isFalse);
      expect(order.smsConfirmado, isFalse);
      expect(order.intentosReenvio, 0);
    });

    test('accepts explicit SMS values', () {
      const order = RestaurantOrder(
        id: 'R1-0712-002',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        creadoPorUsuarioId: 'user-001',
        smsEnviado: true,
        smsConfirmado: true,
        intentosReenvio: 3,
      );

      expect(order.smsEnviado, isTrue);
      expect(order.smsConfirmado, isTrue);
      expect(order.intentosReenvio, 3);
    });

    test('copyWith updates SMS fields without touching the rest', () {
      const order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        creadoPorUsuarioId: 'user-001',
        montoTotal: 500.0,
      );

      final updated = order.copyWith(smsEnviado: true, intentosReenvio: 1);

      expect(updated.smsEnviado, isTrue);
      expect(updated.intentosReenvio, 1);
      expect(updated.smsConfirmado, isFalse);
      expect(updated.id, 'R1-0712-001');
      expect(updated.montoTotal, 500.0);
    });

    test('copyWith preserves SMS fields when not overridden', () {
      const order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        creadoPorUsuarioId: 'user-001',
        smsEnviado: true,
        smsConfirmado: true,
        intentosReenvio: 2,
      );

      final updated = order.copyWith(estado: OrderState.enCocina);

      expect(updated.estado, OrderState.enCocina);
      expect(updated.smsEnviado, isTrue);
      expect(updated.smsConfirmado, isTrue);
      expect(updated.intentosReenvio, 2);
    });

    test('toJson includes SMS fields in snake_case', () {
      const order = RestaurantOrder(
        id: 'R1-0712-001',
        tipoPedido: 'DOMICILIO',
        clienteId: 'CLI-001',
        creadoPorUsuarioId: 'user-001',
        smsEnviado: true,
        intentosReenvio: 2,
      );

      final json = order.toJson();

      expect(json['sms_enviado'], isTrue);
      expect(json['sms_confirmado'], isFalse);
      expect(json['intentos_reenvio'], 2);
    });

    test('fromJson reads SMS fields, defaulting when absent', () {
      final withSms = RestaurantOrder.fromJson({
        'id': 'R1-0712-001',
        'tipo_pedido': 'DOMICILIO',
        'cliente_id': 'CLI-001',
        'creado_por_usuario_id': 'user-001',
        'sms_enviado': true,
        'sms_confirmado': true,
        'intentos_reenvio': 2,
      });
      expect(withSms.smsEnviado, isTrue);
      expect(withSms.smsConfirmado, isTrue);
      expect(withSms.intentosReenvio, 2);

      final withoutSms = RestaurantOrder.fromJson({
        'id': 'R1-0712-002',
        'tipo_pedido': 'DOMICILIO',
        'cliente_id': 'CLI-001',
        'creado_por_usuario_id': 'user-001',
      });
      expect(withoutSms.smsEnviado, isFalse);
      expect(withoutSms.smsConfirmado, isFalse);
      expect(withoutSms.intentosReenvio, 0);
    });
  });
}
