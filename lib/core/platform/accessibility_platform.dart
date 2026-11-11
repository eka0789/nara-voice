import 'package:flutter/services.dart';

import '../models/screen_context.dart';
import 'platform_exception.dart';

/// Dart bridge over the optional accessibility engine (`nara/accessibility`).
class AccessibilityPlatform {
  AccessibilityPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/accessibility');

  final MethodChannel _channel;

  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  Future<ScreenContext> inspectScreen() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('inspectScreen');
      return ScreenContext.fromMap(raw ?? <Object?, Object?>{});
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  /// Taps a previously inspected element (matched by viewId + bounds).
  Future<bool> tapElement(ScreenElement element) async {
    final raw = await _channel.invokeMethod<bool>(
      'tapElement',
      <String, Object?>{'element': element.signatureJson},
    );
    return raw ?? false;
  }

  Future<bool> inputText(ScreenElement element, String value) async {
    final raw = await _channel.invokeMethod<bool>(
      'inputText',
      <String, Object?>{'element': element.signatureJson, 'value': value},
    );
    return raw ?? false;
  }

  Future<bool> scroll({bool forward = true}) async {
    final raw = await _channel.invokeMethod<bool>(
      'scroll',
      <String, Object?>{'forward': forward},
    );
    return raw ?? false;
  }

  Future<bool> goBack() async {
    final raw = await _channel.invokeMethod<bool>('goBack');
    return raw ?? false;
  }

  Future<String?> currentApp() async {
    try {
      final raw = await _channel
          .invokeMethod<Map<Object?, Object?>>('currentApp');
      return raw?['packageName'] as String?;
    } on PlatformException {
      return null;
    }
  }
}
