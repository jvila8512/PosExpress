import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/sms/infrastructure/services/sms_service.dart';

void main() {
  group('SmsService ACK timer', () {
    test('ACK timer fires callback after timeout', () async {
      final service = SmsService();
      bool timeoutCalled = false;

      service.startAckTimer('R1-0712-007', () {
        timeoutCalled = true;
      }, timeoutMs: 100);

      expect(service.isTimerActive('R1-0712-007'), isTrue);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(timeoutCalled, isTrue);
      expect(service.isTimerActive('R1-0712-007'), isFalse);
    });

    test('ACK timer does not fire if cancelled', () async {
      final service = SmsService();
      bool timeoutCalled = false;

      service.startAckTimer('R1-0712-007', () {
        timeoutCalled = true;
      }, timeoutMs: 100);

      service.cancelAckTimer('R1-0712-007');

      await Future.delayed(const Duration(milliseconds: 150));

      expect(timeoutCalled, isFalse);
      expect(service.isTimerActive('R1-0712-007'), isFalse);
    });

    test('cancelling non-existent timer does not throw', () {
      final service = SmsService();
      expect(() => service.cancelAckTimer('nonexistent'), returnsNormally);
    });

    test('starting timer for same order replaces previous', () async {
      final service = SmsService();
      int callCount = 0;

      service.startAckTimer('R1-0712-007', () {
        callCount++;
      }, timeoutMs: 50);

      // Replace with new timer
      service.startAckTimer('R1-0712-007', () {
        callCount++;
      }, timeoutMs: 200);

      await Future.delayed(const Duration(milliseconds: 100));

      // Only the second timer should fire (after 200ms)
      expect(callCount, 0);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(callCount, 1);
    });

    test('multiple timers can run independently', () async {
      final service = SmsService();
      bool timeout1 = false;
      bool timeout2 = false;

      service.startAckTimer('ORDER-1', () {
        timeout1 = true;
      }, timeoutMs: 50);
      service.startAckTimer('ORDER-2', () {
        timeout2 = true;
      }, timeoutMs: 100);

      await Future.delayed(const Duration(milliseconds: 75));

      expect(timeout1, isTrue);
      expect(timeout2, isFalse);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(timeout2, isTrue);
    });
  });

  group('SmsService dedup', () {
    test('isDuplicate returns false for unknown order', () {
      final service = SmsService();
      expect(service.isDuplicate('R1-0712-007'), isFalse);
    });

    test('isDuplicate returns true after marking order', () {
      final service = SmsService();
      service.markOrderProcessed('R1-0712-007');
      expect(service.isDuplicate('R1-0712-007'), isTrue);
    });

    test('isDuplicate returns false for different order IDs', () {
      final service = SmsService();
      service.markOrderProcessed('R1-0712-007');
      expect(service.isDuplicate('R1-0712-008'), isFalse);
      expect(service.isDuplicate('R1-0712-007'), isTrue);
    });

    test('dedup set can be cleared', () {
      final service = SmsService();
      service.markOrderProcessed('R1-0712-007');
      expect(service.isDuplicate('R1-0712-007'), isTrue);

      service.clearProcessedOrders();
      expect(service.isDuplicate('R1-0712-007'), isFalse);
    });

    test('multiple orders can be tracked', () {
      final service = SmsService();
      service.markOrderProcessed('ORDER-1');
      service.markOrderProcessed('ORDER-2');
      service.markOrderProcessed('ORDER-3');

      expect(service.isDuplicate('ORDER-1'), isTrue);
      expect(service.isDuplicate('ORDER-2'), isTrue);
      expect(service.isDuplicate('ORDER-3'), isTrue);
      expect(service.isDuplicate('ORDER-4'), isFalse);
    });
  });
}
