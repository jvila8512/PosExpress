import 'package:flutter/foundation.dart';
import 'package:telephony_sdt/telephony.dart';
import '../../domain/entities/sms_payload.dart';
import '../../domain/services/sms_parser.dart';
import 'sms_service.dart';

/// Callback type for when a parsed SMS payload is received.
typedef OnSmsReceived = void Function(SmsPayload payload, String origin);

/// Top-level background handler for incoming SMS.
///
/// Called by telephony_sdt when the app is not in the foreground.
/// MUST be a top-level or static function with `@pragma('vm:entry-point')`.
/// Cannot access BroadcastReceiver instance — kept minimal.
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) {
  debugPrint('[SMS BG] From: ${message.address} | Body: ${message.body}');
  // Background processing is limited; messages are processed
  // by the foreground handler when the app is active.
  // For future: implement local notification + store to Drift.
}

/// Manages foreground SMS reception via telephony_sdt.
///
/// Filters incoming SMS by trusted contacts and dispatches parsed
/// payloads to the order handler.
class BroadcastReceiver {
  final SmsService _smsService;
  List<String> _trustedPhones = [];
  OnSmsReceived? _onSmsReceived;
  bool _isListening = false;

  BroadcastReceiver(this._smsService);

  /// Set the callback for when a valid SMS is received.
  void setOnSmsReceived(OnSmsReceived callback) {
    _onSmsReceived = callback;
  }

  /// Update the list of trusted phone numbers.
  void updateTrustedPhones(List<String> phones) {
    _trustedPhones = phones;
  }

  /// Start listening for incoming SMS via telephony_sdt.
  ///
  /// Registers both foreground and background handlers.
  /// Safe to call multiple times — subsequent calls are no-ops.
  void register() {
    if (_isListening) {
      debugPrint('BroadcastReceiver already listening');
      return;
    }

    try {
      Telephony.instance.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          handleIncomingSms(message.body ?? '', message.address ?? '');
        },
        onBackgroundMessage: backgroundSmsHandler,
      );
      _isListening = true;
      debugPrint('BroadcastReceiver registered — listening for SMS');
    } catch (e) {
      debugPrint('Failed to register BroadcastReceiver: $e');
    }
  }

  /// Stop processing incoming SMS.
  ///
  /// Note: telephony_sdt does not expose a native stop-listening API.
  /// This sets a flag to ignore further callbacks.
  void unregister() {
    _isListening = false;
    debugPrint('BroadcastReceiver unregistered — ignoring SMS');
  }

  /// Handle an incoming SMS message (called from foreground handler).
  ///
  /// 1. Check origin against trusted contacts
  /// 2. Parse the message body
  /// 3. Check dedup
  /// 4. Dispatch to handler
  void handleIncomingSms(String body, String sender) {
    if (!_isListening) return;

    // 1. Origin filter
    if (SmsParser.isFromUntrustedOrigin(sender, _trustedPhones)) {
      debugPrint('Discarded SMS from untrusted number $sender');
      return;
    }

    // 2. Parse
    final payload = SmsParser.parse(body);
    if (payload == null) {
      debugPrint('Discarded unparseable SMS from $sender: $body');
      return;
    }

    // 3. Dedup check for PED messages
    if (payload.type == 'PED' && _smsService.isDuplicate(payload.orderId)) {
      debugPrint('Discarded duplicate PED for order ${payload.orderId}');
      return;
    }

    // 4. Mark as processed (for PED type) and dispatch
    if (payload.type == 'PED') {
      _smsService.markOrderProcessed(payload.orderId);
    }

    _onSmsReceived?.call(payload, sender);
  }
}
