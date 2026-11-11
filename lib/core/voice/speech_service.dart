import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../platform/voice_platform.dart';

/// High-level speech-to-text facade with explicit lifecycle handling.
/// Emits partials while listening and one final (possibly null) transcript.
class SpeechService {
  SpeechService(this._platform);

  final VoicePlatform _platform;
  StreamSubscription<VoiceEvent>? _subscription;
  final _partialController = StreamController<String>.broadcast();
  final _finalController = StreamController<String?>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  bool _listening = false;

  Stream<String> get partials => _partialController.stream;
  Stream<String?> get finals => _finalController.stream;
  Stream<String> get errors => _errorController.stream;
  bool get isListening => _listening;

  Future<bool> isAvailable() => _platform.isSttAvailable();

  Future<void> start(String localeTag) async {
    if (_listening) return;
    _subscription?.cancel();
    _subscription = _platform.events.listen(_onEvent);
    _listening = true;
    await _platform.startStt(localeTag);
  }

  Future<void> stop() async {
    if (!_listening) return;
    _listening = false;
    await _platform.stopStt();
  }

  Future<void> cancel() async {
    if (!_listening) return;
    _listening = false;
    await _platform.cancelStt();
  }

  void _onEvent(VoiceEvent event) {
    switch (event) {
      case SttPartial(:final text):
        _partialController.add(text);
      case SttFinal(:final text):
        _listening = false;
        _finalController.add(text);
      case SttError(:final code):
        _listening = false;
        _errorController.add(code);
      case SttReady() || SttVolume() || TtsStart() || TtsDone() || TtsError():
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _partialController.close();
    _finalController.close();
    _errorController.close();
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = SpeechService(ref.watch(voicePlatformProvider));
  ref.onDispose(service.dispose);
  return service;
});
