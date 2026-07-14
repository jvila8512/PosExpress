import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/sms/domain/entities/sms_payload.dart';

void main() {
  group('SmsSerializer', () {
    test('serialized payload is under 160 chars for typical 3-item order', () {
      final payload = SmsPayload(
        type: 'PED',
        orderId: 'R1-0712-007',
        client: 'Juan Perez',
        phone: '53512345',
        address: 'Calle 123',
        reference: 'Edif Azul',
        items: [
          Item(code: 'H1', qty: 2),
          Item(code: 'P1', qty: 1),
          Item(code: 'B1', qty: 3),
        ],
        time: '19:30',
        payment: 'EF',
        amount: 950.0,
      );

      final json = payload.toJson();
      expect(json.length, lessThan(160),
          reason: 'Minified JSON payload must fit in one SMS segment');
    });

    test('serialized payload uses short keys', () {
      final payload = SmsPayload(
        type: 'PED',
        orderId: 'R1-0712-001',
        client: 'Maria',
      );

      final json = payload.toJson();
      // Verify short keys are used
      expect(json, contains('"t"'));
      expect(json, contains('"id"'));
      expect(json, contains('"cl"'));
      expect(json, isNot(contains('"type"')));
      expect(json, isNot(contains('"orderId"')));
    });

    test('serialize minimal payload (PED with just orderId)', () {
      final payload = SmsPayload(
        type: 'PED',
        orderId: 'R1-0712-001',
      );

      final json = payload.toJson();
      expect(json.length, lessThan(160));
      expect(json, contains('"t":"PED"'));
      expect(json, contains('"id":"R1-0712-001"'));
    });

    test('round-trip JSON deserialization preserves all fields', () {
      final original = SmsPayload(
        type: 'PED',
        orderId: 'R1-0712-007',
        client: 'Juan Perez',
        phone: '53512345',
        address: 'Calle 123',
        reference: 'Edif Azul',
        items: [
          Item(code: 'H1', qty: 2),
          Item(code: 'P1', qty: 1),
        ],
        time: '19:30',
        payment: 'EF',
        amount: 950.0,
      );

      final json = original.toJson();
      final parsed = SmsPayload.fromJson(json);
      expect(parsed.type, original.type);
      expect(parsed.orderId, original.orderId);
      expect(parsed.client, original.client);
      expect(parsed.phone, original.phone);
      expect(parsed.address, original.address);
      expect(parsed.reference, original.reference);
      expect(parsed.items.length, original.items.length);
      expect(parsed.items[0].code, original.items[0].code);
      expect(parsed.items[0].qty, original.items[0].qty);
      expect(parsed.time, original.time);
      expect(parsed.payment, original.payment);
      expect(parsed.amount, original.amount);
    });

    test('CAN payload includes motive', () {
      final payload = SmsPayload(
        type: 'CAN',
        orderId: 'R1-0712-007',
        motive: 'Cliente cancelo',
      );

      final json = payload.toJson();
      final parsed = SmsPayload.fromJson(json);
      expect(parsed.type, 'CAN');
      expect(parsed.motive, 'Cliente cancelo');
      expect(json, contains('"mo"'));
    });

    test('ACK payload is minimal', () {
      final payload = SmsPayload(
        type: 'ACK',
        orderId: 'R1-0712-007',
      );

      final json = payload.toJson();
      expect(json.length, lessThan(80),
          reason: 'ACK should be very small');
      expect(json, contains('"t":"ACK"'));
    });

    test('length getter returns JSON string length', () {
      final payload = SmsPayload(
        type: 'PED',
        orderId: 'R1-0712-007',
      );

      final json = payload.toJson();
      expect(payload.length, json.length);
    });

    test('HEC payload serializes correctly', () {
      final payload = SmsPayload(
        type: 'HEC',
        orderId: 'R1-0712-007',
      );

      final json = payload.toJson();
      expect(json, contains('"t":"HEC"'));
      expect(json, contains('"id":"R1-0712-007"'));
      expect(json.length, lessThan(100));
    });

    test('ENT payload includes payment and amount', () {
      final payload = SmsPayload(
        type: 'ENT',
        orderId: 'R1-0712-007',
        payment: 'EF',
        amount: 950.0,
      );

      final json = payload.toJson();
      expect(json, contains('"pg":"EF"'));
      expect(json, contains('"mt"'));
      final parsed = SmsPayload.fromJson(json);
      expect(parsed.payment, 'EF');
      expect(parsed.amount, 950.0);
    });
  });
}
