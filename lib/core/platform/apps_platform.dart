import 'package:flutter/services.dart';

import '../models/app_descriptor.dart';
import 'platform_exception.dart';

/// Dart bridge over the native App Discovery Engine (`nara/apps`).
class AppsPlatform {
  AppsPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/apps');

  final MethodChannel _channel;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<List<AppDescriptor>> getInstalledApps() async {
    final raw = await _guard(() => _channel.invokeMethod<List<Object?>>('getInstalledApps'));
    return (raw ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(AppDescriptor.fromMap)
        .toList(growable: false);
  }

  Future<AppDescriptor?> getAppDetails(String packageName) async {
    final raw = await _guard(
      () => _channel.invokeMethod<Map<Object?, Object?>>(
        'getAppDetails',
        <String, Object?>{'packageName': packageName},
      ),
    );
    final map = raw;
    if (map == null) return null;
    return AppDescriptor.fromMap(map);
  }

  Future<Uint8List?> getAppIcon(String packageName, {int size = 96}) {
    return _guard(() => _channel.invokeMethod<Uint8List>(
          'getAppIcon',
          <String, Object?>{'packageName': packageName, 'size': size},
        ));
  }

  /// Launches the app and reports whether Android actually accepted the launch
  /// intent. This is a *handoff* signal, not proof the app finished starting.
  Future<bool> launchApp(String packageName) async {
    final raw = await _guard(
      () => _channel.invokeMethod<Map<Object?, Object?>>(
        'launchApp',
        <String, Object?>{'packageName': packageName},
      ),
    );
    return (raw?['launched'] as bool?) ?? false;
  }

  Future<bool> isAppInstalled(String packageName) async {
    final raw = await _guard(
      () => _channel.invokeMethod<bool>(
        'isAppInstalled',
        <String, Object?>{'packageName': packageName},
      ),
    );
    return raw ?? false;
  }

  Future<bool> canHandleUrl(String url) async {
    final raw = await _guard(
      () => _channel.invokeMethod<bool>(
        'canHandleUrl',
        <String, Object?>{'url': url},
      ),
    );
    return raw ?? false;
  }
}
