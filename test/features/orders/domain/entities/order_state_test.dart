import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/domain/entities/order_state.dart';

void main() {
  group('OrderState.canTransitionTo', () {
    // ============================================================
    // DOMICILIO FLOW: registrado → enCocina → hecho → enCamino → entregado
    // ============================================================

    test('registrado can transition to enCocina', () {
      expect(OrderState.registrado.canTransitionTo(OrderState.enCocina),
          isTrue);
    });

    test('registrado can transition to cancelado', () {
      expect(OrderState.registrado.canTransitionTo(OrderState.cancelado),
          isTrue);
    });

    test('registrado cannot transition to hecho (skip enCocina)', () {
      expect(OrderState.registrado.canTransitionTo(OrderState.hecho),
          isFalse);
    });

    test('registrado cannot transition to entregado (skip entire flow)', () {
      expect(OrderState.registrado.canTransitionTo(OrderState.entregado),
          isFalse);
    });

    test('enCocina can transition to hecho', () {
      expect(OrderState.enCocina.canTransitionTo(OrderState.hecho), isTrue);
    });

    test('enCocina can transition to cancelado', () {
      expect(OrderState.enCocina.canTransitionTo(OrderState.cancelado), isTrue);
    });

    test('enCocina cannot transition to registrado (backwards)', () {
      expect(OrderState.enCocina.canTransitionTo(OrderState.registrado),
          isFalse);
    });

    test('hecho can transition to enCamino', () {
      expect(OrderState.hecho.canTransitionTo(OrderState.enCamino), isTrue);
    });

    test('hecho can transition to entregadoEnMesa (mesa flow)', () {
      expect(
          OrderState.hecho.canTransitionTo(OrderState.entregadoEnMesa), isTrue);
    });

    test('hecho can transition to cancelado', () {
      expect(OrderState.hecho.canTransitionTo(OrderState.cancelado), isTrue);
    });

    test('hecho cannot transition to enCocina (backwards)', () {
      expect(OrderState.hecho.canTransitionTo(OrderState.enCocina), isFalse);
    });

    test('enCamino can transition to entregado', () {
      expect(OrderState.enCamino.canTransitionTo(OrderState.entregado), isTrue);
    });

    test('enCamino can transition to cancelado', () {
      expect(OrderState.enCamino.canTransitionTo(OrderState.cancelado), isTrue);
    });

    test('enCamino cannot transition to hecho (backwards)', () {
      expect(OrderState.enCamino.canTransitionTo(OrderState.hecho), isFalse);
    });

    test('entregado is terminal (no outgoing transitions)', () {
      expect(OrderState.entregado.canTransitionTo(OrderState.cancelado),
          isFalse);
      expect(OrderState.entregado.canTransitionTo(OrderState.pagado), isFalse);
      expect(OrderState.entregado.canTransitionTo(OrderState.cerrado), isFalse);
    });

    // ============================================================
    // MESA FLOW: enCocina → hecho → entregadoEnMesa → pagado → cerrado
    // ============================================================

    test('entregadoEnMesa can transition to pagado', () {
      expect(
          OrderState.entregadoEnMesa.canTransitionTo(OrderState.pagado), isTrue);
    });

    test('entregadoEnMesa can transition to cancelado', () {
      expect(
          OrderState.entregadoEnMesa.canTransitionTo(OrderState.cancelado),
          isTrue);
    });

    test('entregadoEnMesa cannot transition to enCamino', () {
      expect(
          OrderState.entregadoEnMesa.canTransitionTo(OrderState.enCamino),
          isFalse);
    });

    test('pagado can transition to cerrado', () {
      expect(OrderState.pagado.canTransitionTo(OrderState.cerrado), isTrue);
    });

    test('pagado can transition to cancelado', () {
      expect(OrderState.pagado.canTransitionTo(OrderState.cancelado), isTrue);
    });

    test('pagado cannot transition to entregadoEnMesa (backwards)', () {
      expect(
          OrderState.pagado.canTransitionTo(OrderState.entregadoEnMesa),
          isFalse);
    });

    test('cerrado is terminal (no outgoing transitions)', () {
      expect(OrderState.cerrado.canTransitionTo(OrderState.pagado), isFalse);
      expect(OrderState.cerrado.canTransitionTo(OrderState.cancelado), isFalse);
    });

    test('cancelado is terminal (no outgoing transitions)', () {
      expect(OrderState.cancelado.canTransitionTo(OrderState.registrado),
          isFalse);
      expect(OrderState.cancelado.canTransitionTo(OrderState.enCocina),
          isFalse);
    });

    // ============================================================
    // SELF-TRANSITION: any state to itself
    // ============================================================

    test('no state can transition to itself', () {
      for (final state in OrderState.values) {
        expect(state.canTransitionTo(state), isFalse,
            reason: '$state should not transition to itself');
      }
    });
  });

  group('OrderState enum values', () {
    test('has exactly 9 states', () {
      expect(OrderState.values.length, 9);
    });

    test('registrado is first value', () {
      expect(OrderState.values[0], OrderState.registrado);
    });

    test('cancelado is last value', () {
      expect(OrderState.values.last, OrderState.cancelado);
    });

    test('all states are present', () {
      final states = OrderState.values.toSet();
      expect(states, containsAll([
        OrderState.registrado,
        OrderState.enCocina,
        OrderState.hecho,
        OrderState.enCamino,
        OrderState.entregado,
        OrderState.entregadoEnMesa,
        OrderState.pagado,
        OrderState.cerrado,
        OrderState.cancelado,
      ]));
    });
  });
}
