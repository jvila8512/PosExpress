import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/orders/presentation/screens/order_submit_helpers.dart';

void main() {
  group('resolveKitchenPhone', () {
    test('lista con un número → devuelve ese número', () {
      expect(resolveKitchenPhone(['555-1234']), '555-1234');
    });

    test('lista con varios → devuelve el primero', () {
      expect(
        resolveKitchenPhone(['555-1111', '555-2222']),
        '555-1111',
      );
    });

    test('lista vacía → null (pedido se guarda sin SMS)', () {
      expect(resolveKitchenPhone([]), isNull);
    });
  });

  group('submitBlockerMessage', () {
    test('con cliente y productos → null (botón habilitado)', () {
      expect(
        submitBlockerMessage(hasClient: true, hasItems: true),
        isNull,
      );
    });

    test('sin cliente → pide elegir cliente', () {
      expect(
        submitBlockerMessage(hasClient: false, hasItems: true),
        'Elegí un cliente',
      );
    });

    test('sin productos → pide agregar productos', () {
      expect(
        submitBlockerMessage(hasClient: true, hasItems: false),
        'Agregá productos',
      );
    });

    test('sin cliente ni productos → el cliente va primero', () {
      expect(
        submitBlockerMessage(hasClient: false, hasItems: false),
        'Elegí un cliente',
      );
    });
  });
}
