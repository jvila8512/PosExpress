import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/daily_close/domain/daily_close_totals.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';
import 'package:etecsa/features/orders/domain/entities/restaurant_order.dart';

RestaurantOrder _order({
  required OrderState estado,
  double monto = 100.0,
  String? metodoPago,
  String? canalOrigen,
}) {
  return RestaurantOrder(
    id: '${estado.name}-${monto.toStringAsFixed(0)}-'
        '${metodoPago ?? 'sin-pago'}-${canalOrigen ?? 'sin-canal'}',
    tipoPedido: 'DOMICILIO',
    clienteId: 'cli-1',
    estado: estado,
    metodoPago: metodoPago,
    canalOrigen: canalOrigen,
    montoTotal: monto,
    creadoPorUsuarioId: 'u-1',
  );
}

void main() {
  group('validSaleStates', () {
    test('incluye terminales de venta: entregado, pagado, cerrado '
        'y entregadoEnMesa', () {
      expect(
        validSaleStates,
        containsAll([
          OrderState.entregado,
          OrderState.entregadoEnMesa,
          OrderState.pagado,
          OrderState.cerrado,
        ]),
      );
    });

    test('excluye registrado, enCocina, hecho, enCamino y cancelado', () {
      expect(validSaleStates, isNot(contains(OrderState.registrado)));
      expect(validSaleStates, isNot(contains(OrderState.enCocina)));
      expect(validSaleStates, isNot(contains(OrderState.hecho)));
      expect(validSaleStates, isNot(contains(OrderState.enCamino)));
      expect(validSaleStates, isNot(contains(OrderState.cancelado)));
    });
  });

  group('summarizeSales — filtro por estado', () {
    test('suma solo pedidos en estado válido', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'efectivo'),
        _order(estado: OrderState.pagado, monto: 200, metodoPago: 'efectivo'),
        _order(estado: OrderState.cerrado, monto: 300, metodoPago: 'efectivo'),
        _order(
            estado: OrderState.entregadoEnMesa,
            monto: 400,
            metodoPago: 'efectivo'),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 1000.0);
    });

    test('excluye registrado, enCocina, hecho, enCamino y cancelado '
        'del total', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'efectivo'),
        _order(
            estado: OrderState.registrado, monto: 500, metodoPago: 'efectivo'),
        _order(estado: OrderState.enCocina, monto: 500, metodoPago: 'efectivo'),
        _order(estado: OrderState.hecho, monto: 500, metodoPago: 'efectivo'),
        _order(estado: OrderState.enCamino, monto: 500, metodoPago: 'efectivo'),
        _order(estado: OrderState.cancelado, monto: 500, metodoPago: 'efectivo'),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 100.0);
    });
  });

  group('summarizeSales — agrupado por método de pago', () {
    test('agrupa efectivo/cash y transferencia/transfer sin duplicar', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'efectivo'),
        _order(estado: OrderState.pagado, monto: 50, metodoPago: 'cash'),
        _order(
            estado: OrderState.cerrado, monto: 200, metodoPago: 'transferencia'),
        _order(estado: OrderState.entregado, monto: 80, metodoPago: 'transfer'),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 430.0);
      expect(result.cashSales, 150.0);
      expect(result.transferSales, 280.0);
    });

    test('normaliza mayúsculas en el método de pago', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'EFECTIVO'),
        _order(
            estado: OrderState.pagado,
            monto: 200,
            metodoPago: 'Transferencia'),
      ];

      final result = summarizeSales(orders);

      expect(result.cashSales, 100.0);
      expect(result.transferSales, 200.0);
    });
  });

  group('summarizeSales — pago sin confirmar y diferencia', () {
    test('unconfirmedCount cuenta válidos con metodoPago null '
        'e ignora canalOrigen', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: null),
        _order(
            estado: OrderState.pagado,
            monto: 200,
            metodoPago: 'efectivo',
            canalOrigen: 'sms'),
        _order(
            estado: OrderState.registrado, monto: 500, metodoPago: null),
      ];

      final result = summarizeSales(orders);

      expect(result.unconfirmedCount, 1);
    });

    test('diferencia = total − efectivo − transferencia con su %', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'efectivo'),
        _order(
            estado: OrderState.pagado, monto: 200, metodoPago: 'transferencia'),
        _order(estado: OrderState.cerrado, monto: 100, metodoPago: null),
      ];

      final result = summarizeSales(orders);

      expect(result.totalSales, 400.0);
      expect(result.diferencia, 100.0);
      expect(result.unconfirmedPct, closeTo(25.0, 0.001));
    });

    test('todo confirmado cuadra a cero', () {
      final orders = [
        _order(estado: OrderState.entregado, monto: 100, metodoPago: 'efectivo'),
        _order(
            estado: OrderState.pagado, monto: 200, metodoPago: 'transferencia'),
      ];

      final result = summarizeSales(orders);

      expect(result.unconfirmedCount, 0);
      expect(result.diferencia, 0.0);
      expect(result.unconfirmedPct, 0.0);
    });

    test('lista vacía devuelve ceros sin dividir por cero', () {
      final result = summarizeSales(const []);

      expect(result.totalSales, 0.0);
      expect(result.cashSales, 0.0);
      expect(result.transferSales, 0.0);
      expect(result.diferencia, 0.0);
      expect(result.unconfirmedCount, 0);
      expect(result.unconfirmedPct, 0.0);
    });
  });
}
