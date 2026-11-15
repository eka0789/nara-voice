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

  /// Best-effort navigation to Android accessibility settings.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on PlatformException {
      // Ignore — the Permission center still reflects the real state.
    }
  }

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
    final raw = await _channel.invokeMethod<bool>(
      'goBack',
      const <String, Object?>{},
    );
    return raw ?? false;
  }

  /// Universal system navigation via the accessibility service. All best-effort.
  Future<bool> _globalAction(String method) async {
    try {
      final raw = await _channel.invokeMethod<bool>(
        method,
        const <String, Object?>{},
      );
      return raw ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> goHome() => _globalAction('goHome');

  Future<bool> openRecents() => _globalAction('openRecents');

  Future<bool> openNotificationShade() => _globalAction('openNotificationShade');

  Future<bool> openQuickSettings() => _globalAction('openQuickSettings');

  Future<bool> takeScreenshot() => _globalAction('takeScreenshot');

  /// Types [value] into the focused input field of the active window
  /// (works in any app; refused for password fields).
  Future<bool> typeText(String value) async {
    try {
      final raw = await _channel.invokeMethod<bool>(
        'typeText',
        <String, Object?>{'value': value},
      );
      return raw ?? false;
    } on PlatformException {
      return false;
    }
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
