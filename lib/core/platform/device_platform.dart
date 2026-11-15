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

  /// Screen brightness. Returns `canWrite` (special access granted?) and the
  /// current `level` (1-100) when readable.
  Future<Map<String, Object?>> getBrightness() => _control('getBrightness');

  /// Sets screen brightness [level] (1-100). Requires the WRITE_SETTINGS
  /// special access; without it the call reports canWrite=false upstream as
  /// a typed failure.
  Future<Map<String, Object?>> setBrightness(int level) =>
      _control('setBrightness', {'level': level});

  /// Opens the system "Modify system settings" screen for this app.
  Future<void> openWriteSettings() async {
    try {
      await _channel.invokeMethod<void>(
        'openWriteSettings',
        const <String, Object?>{},
      );
    } on PlatformException {
      // Ignore — the Permission center still reflects the real state.
    }
  }
}
