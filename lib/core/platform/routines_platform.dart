import 'package:flutter/services.dart';

import 'platform_exception.dart';

/// Dart bridge over the routine scheduler (`nara/routines`). Routines never
/// execute silently: at their time a tap-to-run notification appears, and the
/// stored commands replay inside NARA only after the user taps it.
class RoutinesPlatform {
  RoutinesPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/routines');

  final MethodChannel _channel;

  /// Arms the alarm for a routine. [commands] are plain text commands that
  /// replay through the normal voice pipeline when the user taps.
  Future<void> save({
    required String id,
    required int hour,
    required int minute,
    required bool daily,
    required String title,
    required List<String> commands,
  }) async {
    try {
      await _channel.invokeMethod<void>('save', <String, Object?>{
        'id': id,
        'hour': hour,
        'minute': minute,
        'daily': daily,
        'title': title,
        'commands': commands,
      });
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  /// Re-arms every stored routine (mirror of the native boot/start hook).
  Future<void> rescheduleAll() async {
    try {
      await _channel.invokeMethod<void>(
        'rescheduleAll',
        const <String, Object?>{},
      );
    } on PlatformException {
      // Best-effort: the native side also re-arms on app start.
    }
  }

  /// Drains command lists queued by fired routine notifications. Returns one
  /// list per pending notification, in arrival order.
  Future<List<List<String>>> consumePending() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'consumePending',
        const <String, Object?>{},
      );
      final entries = (raw?['commands'] as List<Object?>?) ?? const <Object?>[];
      return entries
          .whereType<List<Object?>>()
          .map((list) => list.whereType<String>().toList(growable: false))
          .toList(growable: false);
    } on PlatformException {
      return const <List<String>>[];
    }
  }
}
