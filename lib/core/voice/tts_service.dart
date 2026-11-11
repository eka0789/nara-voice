import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di.dart';
import '../platform/voice_platform.dart';

/// Text-to-speech facade with queue-of-one semantics: starting a new
/// utterance flushes the previous one (barge-in friendly).
class TtsService {
  TtsService(this._platform) {
    _eventsSub = _platform.events.listen(_onEvent);
  }

  final VoicePlatform _platform;
  late final StreamSubscription<VoiceEvent> _eventsSub;
  final Completer<void> _initialised = Completer<void>();
  bool _ready = false;
  bool _speaking = false;

  bool get isReady => _ready;
  bool get isSpeaking => _speaking;

  Future<void> ensureReady() async {
    if (_ready) return;
    if (!_initialised.isCompleted) {
      unawaited(_platform.ttsInit());
    }
    // Wait briefly for the engine to report readiness.
    try {
      await _initialised.future.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      // TTS stays unavailable; callers report the honest state.
    }
  }

  Future<void> speak({
    required String text,
    required String locale,
    double pitch = 1.0,
    double rate = 1.0,
  }) async {
    if (text.trim().isEmpty) return;
    await ensureReady();
    if (!_ready) return;
    _speaking = true;
    await _platform.ttsSpeak(id: 'nara-${DateTime.now().microsecondsSinceEpoch}', text: text, locale: locale);
  }

  Future<void> stop() async {
    _speaking = false;
    await _platform.ttsStop();
  }

  void _onEvent(VoiceEvent event) {
    switch (event) {
      case TtsDone():
        _speaking = false;
      case TtsError(:final id):
        _speaking = false;
        if (id == 'init' && !_initialised.isCompleted) {
          // Init attempt finished (unsuccessfully) — stop waiting.
          _initialised.complete();
        }
      case TtsStart(:final id):
        if (id.isEmpty) {
          // Engine readiness signal from the native init listener.
          _ready = true;
          if (!_initialised.isCompleted) _initialised.complete();
        } else {
          _speaking = true;
        }
      case SttReady() || SttVolume() || SttPartial() || SttFinal() || SttError():
        break;
    }
  }

  void dispose() {
    _eventsSub.cancel();
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService(ref.watch(voicePlatformProvider));
  ref.onDispose(service.dispose);
  return service;
});
