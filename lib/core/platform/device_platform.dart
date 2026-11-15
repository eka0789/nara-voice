import 'package:flutter/services.dart';

/// Read-only device facts plus universal device controls (`nara/device`).
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

  Future<Map<String, Object?>> _control(String method,
      [Map<String, Object?> args = const <String, Object?>{}]) async {
    try {
      final raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(method, args);
      return raw?.cast<String, Object?>() ?? <String, Object?>{};
    } on PlatformException {
      return <String, Object?>{};
    }
  }

  Future<Map<String, Object?>> volumeUp() => _control('volumeUp');

  Future<Map<String, Object?>> volumeDown() => _control('volumeDown');

  Future<Map<String, Object?>> toggleMute() => _control('toggleMute');

  Future<Map<String, Object?>> setTorch({bool on = true}) =>
      _control('setTorch', {'on': on});
}
