import '../../domain/entities/sms_payload.dart';
import '../../domain/services/sms_parser.dart';
import 'sms_service.dart';

/// Callback type for when a parsed SMS payload is received.
typedef OnSmsReceived = void Function(SmsPayload payload, String origin);

/// Android BroadcastReceiver for background SMS reception.
///
/// Filters incoming SMS by trusted contacts and dispatches parsed
/// payloads to the order handler.
///
/// In production, this wraps the `telephony` package's
/// `Telephony.listenToSmsOnNative` callback. On non-Android platforms,
/// it is a no-op.
class BroadcastReceiver {
  final SmsService _smsService;
  List<String> _trustedPhones = [];
  OnSmsReceived? _onSmsReceived;

  BroadcastReceiver(this._smsService);

  /// Set the callback for when a valid SMS is received.
  void setOnSmsReceived(OnSmsReceived callback) {
    _onSmsReceived = callback;
  }

  /// Update the list of trusted phone numbers.
  void updateTrustedPhones(List<String> phones) {
    _trustedPhones = phones;
  }

  /// Register the BroadcastReceiver for background SMS.
  ///
  /// In production, this calls `telephony.listenToSmsOnNative`.
  /// For now, this sets up the handler that will be invoked by the native layer.
  void register() {
    // TODO: In production, wrap telephony.listenToSmsOnNative:
    // Telephony.instance.listenToSmsOnNative(
    //   onSmsReceived: (SmsMessage message) {
    //     _handleIncomingSms(message.body ?? '', message.sender ?? '');
    //   },
    // );
    print('BroadcastReceiver registered (placeholder)');
  }

  /// Unregister the BroadcastReceiver.
  void unregister() {
    // TODO: In production, stop listening:
    // Telephony.instance.stopListenToSmsOnNative();
    print('BroadcastReceiver unregistered (placeholder)');
  }

  /// Handle an incoming SMS message.
  ///
  /// 1. Check origin against trusted contacts
  /// 2. Parse the message body
  /// 3. Check dedup
  /// 4. Dispatch to handler
  void handleIncomingSms(String body, String sender) {
    // 1. Origin filter
    if (SmsParser.isFromUntrustedOrigin(sender, _trustedPhones)) {
      print('Discarded SMS from untrusted number $sender');
      return;
    }

    // 2. Parse
    final payload = SmsParser.parse(body);
    if (payload == null) {
      print('Discarded unparseable SMS from $sender: $body');
      return;
    }

    // 3. Dedup check for PED messages
    if (payload.type == 'PED' && _smsService.isDuplicate(payload.orderId)) {
      print('Discarded duplicate PED for order ${payload.orderId}');
      return;
    }

    // 4. Mark as processed (for PED type) and dispatch
    if (payload.type == 'PED') {
      _smsService.markOrderProcessed(payload.orderId);
    }

    _onSmsReceived?.call(payload, sender);
  }
}
