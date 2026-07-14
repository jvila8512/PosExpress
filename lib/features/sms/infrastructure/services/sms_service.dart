import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service for sending and receiving SMS messages via the `telephony` package.
///
/// Provides ACK timer management (5-minute timeout per sent PED)
/// and deduplication by order ID.
class SmsService {
  final Map<String, Timer> _ackTimers = {};
  final Set<String> _processedOrders = {};

  /// Send an SMS message programmatically.
  ///
  /// In production this wraps `telephony` package's `sendSms()`.
  /// For now, returns true to indicate the message was queued.
  Future<bool> sendSms(String phoneNumber, String message) async {
    // TODO: Wrap telephony.sendSms(phoneNumber, message)
    // The telephony package is available but requires Android platform.
    // For now we log and return success.
    print('SMS to $phoneNumber: $message');
    return true;
  }

  /// Start an ACK timer for the given [orderId].
  ///
  /// The [onTimeout] callback is invoked after [timeoutMs] milliseconds
  /// (default 5 minutes = 300000 ms).
  ///
  /// If a timer already exists for this order, it is cancelled and replaced.
  void startAckTimer(
    String orderId,
    VoidCallback onTimeout, {
    int timeoutMs = 300000,
  }) {
    cancelAckTimer(orderId);
    _ackTimers[orderId] = Timer(Duration(milliseconds: timeoutMs), () {
      _ackTimers.remove(orderId);
      onTimeout();
    });
  }

  /// Cancel an ACK timer for the given [orderId].
  ///
  /// Does nothing if no timer exists.
  void cancelAckTimer(String orderId) {
    _ackTimers.remove(orderId)?.cancel();
  }

  /// Check if an ACK timer is currently active for [orderId].
  bool isTimerActive(String orderId) {
    return _ackTimers.containsKey(orderId) && _ackTimers[orderId]!.isActive;
  }

  /// Mark an order as processed (for deduplication).
  void markOrderProcessed(String orderId) {
    _processedOrders.add(orderId);
  }

  /// Check if an order ID has already been processed.
  bool isDuplicate(String orderId) {
    return _processedOrders.contains(orderId);
  }

  /// Clear the deduplication set.
  void clearProcessedOrders() {
    _processedOrders.clear();
  }

  /// Dispose all active timers and clear state.
  void dispose() {
    for (final timer in _ackTimers.values) {
      timer.cancel();
    }
    _ackTimers.clear();
    _processedOrders.clear();
  }
}
