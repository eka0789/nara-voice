import 'package:flutter/services.dart';

import 'platform_exception.dart';

/// Dart bridge over the runtime permission surface (`nara/permissions`).
/// Only RECORD_AUDIO and POST_NOTIFICATIONS are ever requested — NARA's
/// entire runtime-permission footprint.
class PermissionsPlatform {
  PermissionsPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/permissions');

  final MethodChannel _channel;

  Future<Map<String, Object?>> getStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('getStatus');
      return raw?.cast<String, Object?>() ?? <String, Object?>{};
    } on PlatformException {
      return <String, Object?>{};
    }
  }

  Future<bool> requestMicrophone() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('requestMicrophone');
      return (raw?['granted'] as bool?) ?? false;
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<bool> requestNotifications() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('requestNotifications');
      return (raw?['granted'] as bool?) ?? false;
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<void> openAppSettings() => _channel.invokeMethod<void>('openAppSettings');
}
