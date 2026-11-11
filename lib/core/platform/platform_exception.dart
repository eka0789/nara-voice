/// Typed platform-channel failure surfaced by every NARA native bridge.
class NaraPlatformException implements Exception {
  NaraPlatformException(this.code, this.message, {this.details});

  final String code;
  final String message;
  final Object? details;

  /// The native handler could not resolve any application for the request.
  bool get isNotResolved => code == 'NOT_RESOLVED' || code == 'APP_NOT_LAUNCHABLE';

  /// The user (or Android policy) has not granted the required opt-in service.
  bool get isServiceNotEnabled => code == 'SERVICE_NOT_ENABLED';

  /// The device lacks the capability (e.g. no speech recognition service).
  bool get isUnavailable => code == 'STT_UNAVAILABLE' || code == 'TTS_UNAVAILABLE';

  @override
  String toString() => 'NaraPlatformException($code): $message';
}
