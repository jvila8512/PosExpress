import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/core/security/license_service.dart';

void main() {
  group('LicenseService.getDeviceFingerprintOrNull (non-fatal)', () {
    test('devuelve el id cuando la fuente funciona', () async {
      final id = await LicenseService.getDeviceFingerprintOrNull(
        source: () async => 'device-abc',
      );
      expect(id, 'device-abc');
    });

    test('devuelve null cuando la fuente tira (canal de plataforma falla)',
        () async {
      final id = await LicenseService.getDeviceFingerprintOrNull(
        source: () async => throw StateError('platform channel broken'),
      );
      expect(id, isNull);
    });

    test('devuelve null cuando la fuente cuelga (timeout) y no bloquea',
        () async {
      final id = await LicenseService.getDeviceFingerprintOrNull(
        timeout: const Duration(milliseconds: 100),
        source: () => Completer<String>().future, // nunca se resuelve
      );
      expect(id, isNull);
    });
  });
}