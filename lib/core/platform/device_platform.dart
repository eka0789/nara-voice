import 'package:flutter/services.dart';

/// Read-only device facts (`nara/device`).
class DevicePlatform {
  DevicePlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/device');

  final MethodChannel _channel;

  Future<Map<String, Object?>> getDeviceInfo() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('getDeviceInfo');
      return raw?.cast<String, Object?>() ?? <String, Object?>{};
    } on PlatformException {
      return <String, Object?>{};
    }
  }

  Future<Map<String, Object?>> getBattery() async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>('getBattery');
      return raw?.cast<String, Object?>() ?? <String, Object?>{};
    } on PlatformException {
      return <String, Object?>{};
    }
  }
}
