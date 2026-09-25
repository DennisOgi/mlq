import 'package:flutter/foundation.dart';

typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

/// Defers notification deep-links until the navigator handler is registered.
class NotificationNavigation {
  static NotificationTapHandler? _handler;
  static Map<String, dynamic>? _pending;

  static void register(NotificationTapHandler handler) {
    _handler = handler;
    _tryFlush();
  }

  static void handleTap(Map<String, dynamic> data) {
    if (_handler != null) {
      _handler!(data);
      return;
    }
    _pending = data;
    if (kDebugMode) {
      debugPrint('[NotificationNavigation] Deferred tap: $data');
    }
  }

  static void setPending(Map<String, dynamic> data) {
    _pending = data;
    _tryFlush();
  }

  static void flushPending() => _tryFlush();

  static void _tryFlush() {
    if (_pending == null || _handler == null) return;
    final data = _pending!;
    _pending = null;
    _handler!(data);
  }

  static Map<String, dynamic> dataFromMessage(dynamic message) {
    if (message == null) return {};
    try {
      final dynamic raw = (message as dynamic).data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return {};
  }
}
