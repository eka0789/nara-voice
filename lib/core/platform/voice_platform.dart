import 'dart:async';

import 'package:flutter/services.dart';

import 'platform_exception.dart';

/// Streaming events from the native voice engine.
sealed class VoiceEvent {
  const VoiceEvent();
}

class SttReady extends VoiceEvent {
  const SttReady();
}

class SttVolume extends VoiceEvent {
  const SttVolume(this.level);
  final double level;
}

class SttPartial extends VoiceEvent {
  const SttPartial(this.text);
  final String text;
}

/// Final recognition result. [text] is null when nothing was understood
/// (silence / no match) — the engine reports this honestly.
class SttFinal extends VoiceEvent {
  const SttFinal(this.text);
  final String? text;
}

class SttError extends VoiceEvent {
  const SttError(this.code);
  final String code;
}

class TtsStart extends VoiceEvent {
  const TtsStart(this.id);
  final String id;
}

class TtsDone extends VoiceEvent {
  const TtsDone(this.id);
  final String id;
}

class TtsError extends VoiceEvent {
  const TtsError(this.id);
  final String id;
}

/// Dart bridge over the native voice engine (`nara/voice` + event channel).
class VoicePlatform {
  VoicePlatform({
    MethodChannel? channel,
    EventChannel? eventChannel,
  })  : _channel = channel ?? const MethodChannel('nara/voice'),
        _events = eventChannel ?? const EventChannel('nara/voice/events');

  final MethodChannel _channel;
  final EventChannel _events;
  StreamController<VoiceEvent>? _controller;
  StreamSubscription<dynamic>? _subscription;

  Stream<VoiceEvent> get events {
    _controller ??= StreamController<VoiceEvent>.broadcast(
      onListen: _attach,
      onCancel: () {
        _subscription?.cancel();
        _subscription = null;
      },
    );
    return _controller!.stream;
  }

  void _attach() {
    _subscription = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (raw is! Map) return;
        final event = _decode(raw);
        if (event != null) _controller?.add(event);
      },
      onError: (Object e) {
        _controller?.add(SttError('STREAM'));
      },
    );
  }

  VoiceEvent? _decode(Map raw) {
    final kind = raw['kind'] as String?;
    final event = raw['event'] as String?;
    final text = raw['text'] as String?;
    switch (kind) {
      case 'stt':
        switch (event) {
          case 'ready':
            return const SttReady();
          case 'begin':
            return const SttReady();
          case 'volume':
            return SttVolume((raw['volume'] as num?)?.toDouble() ?? 0);
          case 'partial':
            return SttPartial(text ?? '');
          case 'final':
            return SttFinal(text);
          case 'error':
            return SttError(text ?? 'UNKNOWN');
        }
        return null;
      case 'tts':
        switch (event) {
          case 'ready':
            // Empty id signals engine readiness (distinct from an utterance).
            return const TtsStart('');
          case 'init_failed':
            return const TtsError('init');
          case 'start':
            return TtsStart(text ?? '');
          case 'done':
            return TtsDone(text ?? '');
          case 'error':
            return TtsError(text ?? '');
        }
        return null;
    }
    return null;
  }

  Future<bool> isSttAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isSttAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> startStt(String locale) async {
    try {
      await _channel.invokeMethod<void>('startStt', {'locale': locale});
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<void> stopStt() => _channel.invokeMethod<void>('stopStt');

  Future<void> cancelStt() => _channel.invokeMethod<void>('cancelStt');

  /// Initialises TTS; readiness arrives later through [events] (`TtsStart` is
  /// utterance start, readiness is signalled by a `tts ready` event mapped to
  /// [TtsStart] with an empty id — see native handler emissions).
  Future<void> ttsInit() => _channel.invokeMethod<void>('ttsInit');

  Future<void> ttsSpeak({
    required String id,
    required String text,
    required String locale,
    double pitch = 1.0,
    double rate = 1.0,
  }) async {
    try {
      await _channel.invokeMethod<void>('ttsSpeak', {
        'id': id,
        'text': text,
        'locale': locale,
        'pitch': pitch,
        'rate': rate,
      });
    } on PlatformException catch (e) {
      throw NaraPlatformException(e.code, e.message ?? e.code, details: e.details);
    }
  }

  Future<void> ttsStop() => _channel.invokeMethod<void>('ttsStop');

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }
}
