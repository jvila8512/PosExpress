import 'dart:convert';
import '../entities/sms_payload.dart';

/// Parses incoming SMS messages into [SmsPayload] objects.
///
/// Supports two formats:
/// - **JSON** (preferred): minified JSON with short keys
/// - **Pipe-delimited** (fallback): `TYPE|ID|client|phone|address|reference|items|time|payment|amount|motive`
///
/// Also provides a utility to check if a message origin is trusted.
class SmsParser {
  /// Parse an SMS string, auto-detecting format.
  ///
  /// Returns `null` if the input cannot be parsed.
  static SmsPayload? parse(String raw) {
    if (raw.isEmpty) return null;

    final trimmed = raw.trim();

    // Auto-detect: JSON starts with '{'
    if (trimmed.startsWith('{')) {
      return parseJson(trimmed);
    }

    // Otherwise try pipe-delimited format
    return parsePipeFormat(trimmed);
  }

  /// Parse a JSON-formatted SMS payload.
  ///
  /// Returns `null` if the JSON is invalid or missing required fields.
  static SmsPayload? parseJson(String raw) {
    try {
      final trimmed = raw.trim();
      if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;

      final map = jsonDecode(trimmed) as Map<String, dynamic>;

      // Must have at least 't' (type) field
      if (map['t'] == null) return null;

      return SmsPayload.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Parse a pipe-delimited SMS payload.
  ///
  /// Format: `TYPE|ID|client|phone|address|reference|items|time|payment|amount|motive`
  ///
  /// Items format within the pipe: `code:qty,code:qty` (e.g. `H1:2,P1:1`)
  ///
  /// Returns `null` if the format is invalid.
  static SmsPayload? parsePipeFormat(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;

      final parts = trimmed.split('|');
      if (parts.isEmpty) return null;

      final type = parts[0];
      if (type.isEmpty) return null;

      // Minimum: type + id (2 parts) for ACK
      // Full: type + id + client + phone + address + reference + items + time + payment + amount (10 parts)
      if (parts.length < 2) return null;

      final orderId = parts[1];

      String? client;
      String? phone;
      String? address;
      String? reference;
      List<Item> items = [];
      String? time;
      String? payment;
      double? amount;
      String? motive;

      if (parts.length > 2) client = _nullIfEmpty(parts[2]);
      if (parts.length > 3) phone = _nullIfEmpty(parts[3]);
      if (parts.length > 4) address = _nullIfEmpty(parts[4]);
      if (parts.length > 5) reference = _nullIfEmpty(parts[5]);
      if (parts.length > 6) items = _parsePipeItems(parts[6]);
      if (parts.length > 7) time = _nullIfEmpty(parts[7]);
      if (parts.length > 8) payment = _nullIfEmpty(parts[8]);
      if (parts.length > 9) {
        final amt = double.tryParse(parts[9]);
        if (amt != null) amount = amt;
      }
      if (parts.length > 10) motive = _nullIfEmpty(parts[10]);

      return SmsPayload(
        type: type,
        orderId: orderId,
        client: client,
        phone: phone,
        address: address,
        reference: reference,
        items: items,
        time: time,
        payment: payment,
        amount: amount,
        motive: motive,
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if a phone number is NOT in the trusted list.
  static bool isFromUntrustedOrigin(String? phoneNumber, List<String>? trustedContacts) {
    if (phoneNumber == null || phoneNumber.isEmpty) return true;
    if (trustedContacts == null || trustedContacts.isEmpty) return true;
    return !trustedContacts.contains(phoneNumber);
  }

  static List<Item> _parsePipeItems(String raw) {
    if (raw.isEmpty) return [];
    final pairs = raw.split(',');
    return pairs.map((pair) {
      final kv = pair.split(':');
      if (kv.length >= 2) {
        return Item(
          code: kv[0].trim(),
          qty: int.tryParse(kv[1].trim()) ?? 0,
        );
      }
      return Item(code: kv[0].trim(), qty: 0);
    }).toList();
  }

  static String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
