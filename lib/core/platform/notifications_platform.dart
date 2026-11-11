import 'package:flutter/services.dart';

import '../models/notification_item.dart';
import 'platform_exception.dart';

/// Dart bridge over the optional notification listener (`nara/notifications`).
class NotificationsPlatform {
  NotificationsPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/notifications');

  final MethodChannel _channel;

  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openListenerSettings() =>
      _channel.invokeMethod<void>('openListenerSettings');

  Future<List<NotificationItem>> getRecent({int limit = 10}) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'getRecent',
        <String, Object?>{'limit': limit},
      );
      return (raw ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(NotificationItem.fromMap)
          .toList(growable: false);
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }
}
