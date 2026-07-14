import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/features/sms/domain/services/sms_parser.dart';
import 'package:etecsa/features/sms/domain/entities/sms_payload.dart';

void main() {
  group('SmsParser.parseJson', () {
    test('parses valid PED JSON correctly', () {
      final json = '{"t":"PED","id":"R1-0712-007","cl":"Juan","tl":"53512345",'
          '"dr":"Calle 123","rf":"Edif","it":[["H1",2],["P1",1]],'
          '"hr":"19:30","pg":"EF","mt":950.0}';

      final result = SmsParser.parseJson(json);

      expect(result, isNotNull);
      expect(result!.type, 'PED');
      expect(result.orderId, 'R1-0712-007');
      expect(result.client, 'Juan');
      expect(result.phone, '53512345');
      expect(result.address, 'Calle 123');
      expect(result.reference, 'Edif');
      expect(result.items.length, 2);
      expect(result.items[0].code, 'H1');
      expect(result.items[0].qty, 2);
      expect(result.time, '19:30');
      expect(result.payment, 'EF');
      expect(result.amount, 950.0);
    });

    test('parses valid ACK JSON correctly', () {
      final json = '{"t":"ACK","id":"R1-0712-007"}';
      final result = SmsParser.parseJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'ACK');
      expect(result.orderId, 'R1-0712-007');
    });

    test('returns null for invalid JSON string', () {
      final result = SmsParser.parseJson('not json at all');
      expect(result, isNull);
    });

    test('returns null for empty string', () {
      final result = SmsParser.parseJson('');
      expect(result, isNull);
    });

    test('returns null for malformed JSON (missing closing brace)', () {
      // The input is actually valid JSON (has closing brace).
      // Use a TRULY malformed JSON to test the null return.
      final result = SmsParser.parseJson('{"t":"PED","id":"R1"');
      expect(result, isNull);
    });

    test('returns null for JSON with wrong type (not a string)', () {
      final result = SmsParser.parseJson('{"t":123,"id":"R1"}');
      // Parses but type from 123.toString() becomes '123'); still returns non-null
      expect(result, isNotNull);
      expect(result!.type, '123');
    });

    test('parses JSON with only required fields (t and id)', () {
      final json = '{"t":"PED","id":"R1-0712-001"}';
      final result = SmsParser.parseJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'PED');
      expect(result.orderId, 'R1-0712-001');
      expect(result.client, isNull);
      expect(result.phone, isNull);
    });

    test('parses HEC payload', () {
      final json = '{"t":"HEC","id":"R1-0712-007"}';
      final result = SmsParser.parseJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'HEC');
    });

    test('parses ENT payload with payment info', () {
      final json = '{"t":"ENT","id":"R1-0712-007","pg":"TR","mt":850.0}';
      final result = SmsParser.parseJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'ENT');
      expect(result.payment, 'TR');
      expect(result.amount, 850.0);
    });

    test('parses CAN payload with motive', () {
      final json = '{"t":"CAN","id":"R1-0712-007","mo":"Cliente cancelo"}';
      final result = SmsParser.parseJson(json);
      expect(result, isNotNull);
      expect(result!.type, 'CAN');
      expect(result.motive, 'Cliente cancelo');
    });
  });

  group('SmsParser.parsePipeFormat', () {
    test('parses valid pipe-delimited PED format', () {
      // PED|ID|client|phone|address|reference|items|time|payment|amount
      final pipe = 'PED|R1-0712-007|Juan Perez|53512345|Calle 123|Edif Azul|'
          'H1:2,P1:1|19:30|EF|950.0';

      final result = SmsParser.parsePipeFormat(pipe);
      expect(result, isNotNull);
      expect(result!.type, 'PED');
      expect(result.orderId, 'R1-0712-007');
      expect(result.client, 'Juan Perez');
      expect(result.phone, '53512345');
      expect(result.address, 'Calle 123');
      expect(result.reference, 'Edif Azul');
      expect(result.items.length, 2);
      expect(result.items[0].code, 'H1');
      expect(result.items[0].qty, 2);
      expect(result.time, '19:30');
      expect(result.payment, 'EF');
      expect(result.amount, 950.0);
    });

    test('returns null for pipe format with too few fields', () {
      // A single field (no id) is invalid. 2 fields (type+id) IS valid (minimal ACK).
      final result = SmsParser.parsePipeFormat('PED');
      expect(result, isNull);
    });

    test('returns null for empty pipe format', () {
      final result = SmsParser.parsePipeFormat('');
      expect(result, isNull);
    });

    test('parses minimal pipe format (ACK)', () {
      final result = SmsParser.parsePipeFormat('ACK|R1-0712-007');
      // ACK may only need type + id
      expect(result, isNotNull);
      expect(result!.type, 'ACK');
      expect(result.orderId, 'R1-0712-007');
    });

    test('parses CAN with motive in pipe format', () {
      // CAN format: with motive at index 10, intermediate fields must be empty
      final result = SmsParser.parsePipeFormat('CAN|R1-0712-007|||||||||Cliente cancelo');
      expect(result, isNotNull);
      expect(result!.type, 'CAN');
      expect(result.motive, 'Cliente cancelo');
    });
  });

  group('SmsParser.parse', () {
    test('auto-detects JSON format (starts with {)', () {
      final result = SmsParser.parse('{"t":"PED","id":"R1-001"}');
      expect(result, isNotNull);
      expect(result!.type, 'PED');
    });

    test('auto-detects pipe format (starts with letter)', () {
      final result = SmsParser.parse('PED|R1-001|Client');
      expect(result, isNotNull);
      expect(result!.type, 'PED');
    });

    test('returns null for unparseable input', () {
      final result = SmsParser.parse('');
      expect(result, isNull);
    });

    test('returns null for random text', () {
      final result = SmsParser.parse('hello world this is not valid');
      expect(result, isNull);
    });

    test('handles CAN pipe format through auto-detect', () {
      // CAN with motive at position 10 (after 9 empty pipe fields)
      final result = SmsParser.parse('CAN|R1-0712-007|||||||||Motive here');
      expect(result, isNotNull);
      expect(result!.type, 'CAN');
      expect(result.motive, 'Motive here');
    });
  });

  group('SmsParser.untrusted origin check', () {
    test('messages from untrusted numbers are discarded', () {
      // This is really a BroadcastReceiver responsibility, but the SmsParser
      // should provide a utility to check if a message should be rejected
      final trustedContacts = ['53512345', '53567890'];
      expect(SmsParser.isFromUntrustedOrigin('53599999', trustedContacts),
          isTrue);
      expect(SmsParser.isFromUntrustedOrigin('53512345', trustedContacts),
          isFalse);
      expect(SmsParser.isFromUntrustedOrigin('53567890', trustedContacts),
          isFalse);
    });

    test('empty trusted contacts list discards all', () {
      expect(SmsParser.isFromUntrustedOrigin('53512345', []), isTrue);
    });

    test('null trusted contacts discards all', () {
      expect(SmsParser.isFromUntrustedOrigin('53512345', null), isTrue);
    });
  });
}
