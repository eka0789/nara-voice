import 'package:flutter/services.dart';

import 'platform_exception.dart';

/// Result of handing an intent off to Android.
class IntentHandoff {
  const IntentHandoff({required this.launched, this.handler, this.description});

  final bool launched;

  /// Package that Android resolved to receive the intent (may be null when
  /// the chooser lets the user decide).
  final String? handler;
  final String? description;

  static IntentHandoff fromMap(Map<Object?, Object?>? map) => IntentHandoff(
        launched: (map?['launched'] as bool?) ?? false,
        handler: map?['handler'] as String?,
        description: map?['description'] as String?,
      );
}

class ContactPickResult {
  const ContactPickResult({required this.picked, this.name, this.phone});

  final bool picked;
  final String? name;
  final String? phone;
}

/// Dart bridge over the App Integration Engine (`nara/intents`).
/// Every action is an honest handoff: NARA never claims an in-app effect.
class IntentsPlatform {
  IntentsPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('nara/intents');

  final MethodChannel _channel;

  Future<IntentHandoff> _run(
    String method, [
    Map<String, Object?> args = const <String, Object?>{},
  ]) async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(method, args);
      return IntentHandoff.fromMap(raw);
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<IntentHandoff> openUrl(String url) => _run('openUrl', {'url': url});

  Future<IntentHandoff> openDeepLink(String url) =>
      _run('openDeepLink', {'url': url});

  Future<IntentHandoff> shareText(String text, {String? title, String? packageName}) =>
      _run('shareText', {'text': text, 'title': title, 'packageName': packageName});

  Future<IntentHandoff> composeWhatsApp({String? phone, String? text}) =>
      _run('composeWhatsApp', {'phone': phone, 'text': text});

  Future<IntentHandoff> composeEmail({String? to, String? subject, String? body}) =>
      _run('composeEmail', {'to': to, 'subject': subject, 'body': body});

  Future<IntentHandoff> openMaps({String? query, String? mode}) =>
      _run('openMaps', {'query': query, 'mode': mode});

  Future<IntentHandoff> openYouTubeSearch(String query) =>
      _run('openYouTubeSearch', {'query': query});

  Future<IntentHandoff> openSpotify({String? query}) =>
      _run('openSpotify', {'query': query});

  Future<IntentHandoff> openSettings(String screen, {String? packageName}) =>
      _run('openSettings', {'screen': screen, 'packageName': packageName});

  Future<IntentHandoff> openAppDetails(String packageName) =>
      _run('openAppDetails', {'packageName': packageName});

  Future<IntentHandoff> insertCalendarEvent({
    required String title,
    String? description,
    int? beginMillis,
    int? endMillis,
    bool allDay = false,
  }) =>
      _run('insertCalendarEvent', {
        'title': title,
        'description': description,
        'beginMillis': beginMillis,
        'endMillis': endMillis,
        'allDay': allDay,
      });

  Future<ContactPickResult> pickContact() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>('pickContact');
      return ContactPickResult(
        picked: (raw?['picked'] as bool?) ?? false,
        name: raw?['name'] as String?,
        phone: raw?['phone'] as String?,
      );
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }
}
