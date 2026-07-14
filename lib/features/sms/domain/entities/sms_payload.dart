import 'dart:convert';

/// Represents a single item within an SMS payload.
class Item {
  final String code;
  final int qty;

  const Item({required this.code, required this.qty});

  factory Item.fromJson(dynamic json) {
    if (json is List && json.length >= 2) {
      return Item(code: json[0].toString(), qty: (json[1] as num).toInt());
    }
    if (json is Map<String, dynamic>) {
      return Item(
        code: json['code']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toInt() ?? 0,
      );
    }
    return Item(code: '', qty: 0);
  }

  dynamic toJson() => [code, qty];

  Map<String, dynamic> toMap() => {'code': code, 'qty': qty};
}

/// Minified SMS payload with short keys to fit in 160-character SMS segments.
///
/// Field mapping:
/// - t: type (PED | ACK | HEC | ENT | CAN)
/// - id: orderId (e.g. R1-0712-007)
/// - cl: client name
/// - tl: phone
/// - dr: address
/// - rf: reference
/// - it: items as [[code, qty], ...]
/// - hr: time
/// - pg: payment method (EF | TR | PD)
/// - mt: amount
/// - mo: motive (cancellation reason)
class SmsPayload {
  final String type;
  final String orderId;
  final String? client;
  final String? phone;
  final String? address;
  final String? reference;
  final List<Item> items;
  final String? time;
  final String? payment;
  final double? amount;
  final String? motive;

  const SmsPayload({
    required this.type,
    required this.orderId,
    this.client,
    this.phone,
    this.address,
    this.reference,
    this.items = const [],
    this.time,
    this.payment,
    this.amount,
    this.motive,
  });

  /// Create from minified JSON string (short keys).
  factory SmsPayload.fromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return SmsPayload._fromMap(map);
  }

  /// Create from decoded JSON map.
  factory SmsPayload.fromMap(Map<String, dynamic> map) {
    return SmsPayload._fromMap(map);
  }

  SmsPayload._fromMap(Map<String, dynamic> map) :
    type = map['t']?.toString() ?? '',
    orderId = map['id']?.toString() ?? '',
    client = map['cl']?.toString(),
    phone = map['tl']?.toString(),
    address = map['dr']?.toString(),
    reference = map['rf']?.toString(),
    items = _parseItems(map['it']),
    time = map['hr']?.toString(),
    payment = map['pg']?.toString(),
    amount = (map['mt'] as num?)?.toDouble(),
    motive = map['mo']?.toString();

  static List<Item> _parseItems(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      // Support both [["H1",2], ...] and compact string format
      return raw.map((e) => Item.fromJson(e)).toList();
    }
    // Compact string format: "H1:2,P1:1"
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((pair) {
        final kv = pair.split(':');
        if (kv.length >= 2) {
          return Item(code: kv[0], qty: int.tryParse(kv[1]) ?? 0);
        }
        return Item(code: pair, qty: 0);
      }).toList();
    }
    return [];
  }

  /// Serialize to minified JSON string with short keys.
  ///
  /// Items are serialized as a compact string "H1:2,P1:1" to save space.
  String toJson() {
    final map = <String, dynamic>{
      't': type,
      'id': orderId,
    };
    if (client != null) map['cl'] = client;
    if (phone != null) map['tl'] = phone;
    if (address != null) map['dr'] = address;
    if (reference != null) map['rf'] = reference;
    if (items.isNotEmpty) {
      // Compact format: "H1:2,P1:1" instead of [["H1",2],["P1",1]]
      map['it'] = items.map((e) => '${e.code}:${e.qty}').join(',');
    }
    if (time != null) map['hr'] = time;
    if (payment != null) map['pg'] = payment;
    if (amount != null) map['mt'] = (amount! * 100).round() / 100; // avoid trailing zeros
    if (motive != null) map['mo'] = motive;

    return jsonEncode(map);
  }

  /// Returns the length of the minified JSON string.
  int get length => toJson().length;
}
