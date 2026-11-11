import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ai/orchestrator.dart';
import '../../core/ai/response_localizer.dart';
import '../../core/di.dart';
import '../../core/models/execution.dart';
import '../../core/voice/speech_service.dart';
import '../../core/voice/tts_service.dart';
import '../../core/voice/voice_state.dart';
import '../automation/workflow_engine.dart';

/// A UI-facing result card (screen text, notifications, device info).
class ResultCard {
  const ResultCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;
}

/// Full orchestration state for the voice UI.
class AssistantUiState {
  const AssistantUiState({
    this.voiceState = VoiceState.idle,
    this.transcript = '',
    this.partialTranscript = '',
    this.responseText = '',
    this.activePlan,
    this.pendingPlan,
    this.resultCard,
    this.listeningAvailable = true,
    this.statusHint,
  });

  final VoiceState voiceState;
  final String transcript;
  final String partialTranscript;
  final String responseText;
  final ExecutionPlan? activePlan;
  final ExecutionPlan? pendingPlan;
  final ResultCard? resultCard;
  final bool listeningAvailable;
  final String? statusHint;

  AssistantUiState copyWith({
    VoiceState? voiceState,
    String? transcript,
    String? partialTranscript,
    String? responseText,
    ExecutionPlan? activePlan,
    ExecutionPlan? pendingPlan,
    ResultCard? resultCard,
    bool? listeningAvailable,
    String? statusHint,
    bool clearPendingPlan = false,
    bool clearResultCard = false,
    bool clearStatusHint = false,
  }) {
    return AssistantUiState(
      voiceState: voiceState ?? this.voiceState,
      transcript: transcript ?? this.transcript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      responseText: responseText ?? this.responseText,
      activePlan: activePlan ?? this.activePlan,
      pendingPlan: pendingPlan ?? this.pendingPlan,
      resultCard: clearResultCard ? null : (resultCard ?? this.resultCard),
      listeningAvailable: listeningAvailable ?? this.listeningAvailable,
      statusHint: clearStatusHint ? null : (statusHint ?? this.statusHint),
    );
  }
}

/// The voice assistant controller: STT → orchestrator → confirmation gate →
/// execution → TTS, with every state visually represented (spec §7/§13).
class VoiceAssistantController extends StateNotifier<AssistantUiState> {
  VoiceAssistantController(this._ref) : super(const AssistantUiState()) {
    _speech = _ref.read(speechServiceProvider);
    _tts = _ref.read(ttsServiceProvider);
    _bootstrap();
  }

  final Ref _ref;

  late final SpeechService _speech;
  late final TtsService _tts;
  StreamSubscription<String>? _partialsSub;
  StreamSubscription<String?>? _finalsSub;
  StreamSubscription<String>? _errorsSub;
  bool _busy = false;

  Future<void> _bootstrap() async {
    final settings = await _ref.read(settingsStoreProvider).load();
    final available = await _speech.isAvailable();
    state = state.copyWith(listeningAvailable: available);
    await _ref.read(appLookupProvider).warmUp();
    _wireSpeech(settings.locale);
  }

  void _wireSpeech(String locale) {
    _partialsSub?.cancel();
    _finalsSub?.cancel();
    _errorsSub?.cancel();
    _partialsSub = _speech.partials.listen((text) {
      state = state.copyWith(partialTranscript: text);
    });
    _finalsSub = _speech.finals.listen((text) {
      if (text == null) {
        // Nothing understood — report honestly.
        state = state.copyWith(
          voiceState: VoiceState.idle,
          statusHint: locale == 'id' ? 'Tidak ada suara yang terdeteksi.' : 'No speech detected.',
        );
      } else {
        handleSubmit(text);
      }
    });
    _errorsSub = _speech.errors.listen((code) {
      state = state.copyWith(
        voiceState: VoiceState.error,
        statusHint: _sttErrorText(code),
      );
    });
  }

  String _sttErrorText(String code) {
    switch (code) {
      case 'PERMISSIONS':
        return 'Izin mikrofon belum aktif.';
      case 'NETWORK':
      case 'NETWORK_TIMEOUT':
        return 'Pengenalan suara butuh koneksi internet.';
      case 'LANGUAGE_NOT_SUPPORTED':
      case 'LANGUAGE_UNAVAILABLE':
        return 'Bahasa tersebut tidak tersedia untuk pengenalan suara.';
      default:
        return 'Pengenalan suara gagal ($code).';
    }
  }

  // ===== Listening =====

  Future<void> startListening() async {
    if (state.voiceState.isBusy || _busy) return;
    final micGranted = await _ref
        .read(permissionsPlatformProvider)
        .requestMicrophone();
    if (!micGranted) {
      state = state.copyWith(
        voiceState: VoiceState.error,
        statusHint: 'Izinkan akses mikrofon di Pengaturan untuk berbicara dengan NARA.',
      );
      return;
    }
    final settings = await _ref.read(settingsStoreProvider).load();
    state = state.copyWith(
      voiceState: VoiceState.listening,
      partialTranscript: '',
      clearResultCard: true,
      clearStatusHint: true,
    );
    try {
      await _speech.start(settings.locale == 'id' ? 'id-ID' : 'en-US');
    } catch (e) {
      state = state.copyWith(voiceState: VoiceState.error, statusHint: 'Mikrofon tidak dapat dimulai.');
    }
  }

  Future<void> stopListening() async {
    await _speech.stop();
    if (state.voiceState == VoiceState.listening) {
      state = state.copyWith(voiceState: VoiceState.processing);
    }
  }

  // ===== Command handling (voice or text) =====

  Future<void> handleSubmit(String transcript) async {
    final text = transcript.trim();
    if (text.isEmpty || _busy) return;
    _busy = true;

    // 1. Confirmation answers take priority when a plan is pending.
    if (state.pendingPlan != null) {
      if (_isAffirmative(text)) {
        await _confirmPending();
        _busy = false;
        return;
      }
      if (_isNegative(text)) {
        await _cancelPending();
        _busy = false;
        return;
      }
    }

    // 2. Cancel commands stop everything.
    final lower = text.toLowerCase();
    if (lower == 'batal' || lower == 'cancel' || lower == 'berhenti' || lower == 'stop') {
      await _cancelPending();
      _busy = false;
      return;
    }

    state = state.copyWith(
      voiceState: VoiceState.thinking,
      transcript: text,
      partialTranscript: '',
      clearStatusHint: true,
    );
    _ref.read(conversationMemoryProvider).addUserMessage(text);

    try {
      final orchestrator = _ref.read(orchestratorProvider);
      final outcome = await orchestrator.plan(text);
      final memory = _ref.read(conversationMemoryProvider);

      switch (outcome) {
        case DirectAnswer(:final text, :final locale):
          memory.addAssistantMessage(text);
          await _speakAndSettle(text, locale);

        case NeedClarify(:final question, :final pending):
          // Keep the question answerable: persist the pending slot.
          memory.setPending(pending);
          memory.addAssistantMessage(question);
          state = state.copyWith(voiceState: VoiceState.idle, responseText: question);
          await _speak(question);

        case PlanReady(:final plan, :final locale, :final source):
          if (plan.needsConfirmation) {
            _stashForConfirmation(plan, locale);
          } else {
            await _execute(plan, locale, source);
          }
      }
    } catch (e) {
      state = state.copyWith(
        voiceState: VoiceState.error,
        statusHint: 'Terjadi kesalahan internal: ${_short(e.toString())}',
      );
    } finally {
      _busy = false;
    }
  }

  /// Public confirmation actions for the UI confirmation card.
  Future<void> confirmPendingPlan() async {
    if (state.pendingPlan == null) return;
    await _confirmPending();
  }

  Future<void> cancelPendingPlan() async {
    if (state.pendingPlan == null) return;
    await _cancelPending();
  }

  bool _isAffirmative(String text) {
    final t = text.toLowerCase().trim();
    return ['ya', 'yaa', 'oke', 'ok', 'yes', 'yeah', 'lanjut', 'lanjutkan', 'confirm', 'setuju', 'go', 'silakan']
        .contains(t);
  }

  bool _isNegative(String text) {
    final t = text.toLowerCase().trim();
    return ['tidak', 'jangan', 'no', 'cancel', 'batal', 'batalkan', 'jangan dulu', "don't", 'stop'].contains(t);
  }

  void _stashForConfirmation(ExecutionPlan plan, String locale) {
    final highRisk = plan.steps.firstWhere(
      (s) => s.action.riskLevel == RiskLevel.high,
      orElse: () => plan.steps.first,
    );
    final body = ResponseLocalizer.confirmationBody(highRisk, locale);
    _ref.read(conversationMemoryProvider).addAssistantMessage(body);
    state = state.copyWith(
      voiceState: VoiceState.awaitingConfirmation,
      pendingPlan: plan,
      responseText: body,
    );
    unawaited(_speak(locale.startsWith('id') ? 'Perlu konfirmasi Anda.' : 'I need your confirmation.'));
  }

  Future<void> _confirmPending() async {
    final plan = state.pendingPlan;
    if (plan == null) return;
    state = state.copyWith(clearPendingPlan: true);
    final settings = await _ref.read(settingsStoreProvider).load();
    await _execute(plan, settings.locale, 'offline');
  }

  Future<void> _cancelPending() async {
    final plan = state.pendingPlan;
    state = state.copyWith(clearPendingPlan: true, voiceState: VoiceState.idle);
    if (plan != null) {
      for (final step in plan.steps) {
        if (!step.isTerminal) step.status = StepStatus.cancelled;
      }
    }
    final settings = await _ref.read(settingsStoreProvider).load();
    final text = settings.locale.startsWith('id') ? 'Dibatalkan. Tidak ada yang dijalankan.' : 'Cancelled. Nothing was executed.';
    _ref.read(conversationMemoryProvider).addAssistantMessage(text);
    state = state.copyWith(responseText: text);
    await _speak(text);
  }

  Future<void> _execute(ExecutionPlan plan, String locale, String source) async {
    state = state.copyWith(
      voiceState: VoiceState.executing,
      activePlan: plan,
    );

    // Multi-step plans also appear in the Automations screen.
    final workflowEngine = _ref.read(workflowEngineProvider.notifier);
    if (plan.steps.length > 1) {
      workflowEngine.create(plan, locale: locale);
    }

    final orchestrator = _ref.read(orchestratorProvider);
    final response = await orchestrator.execute(
      plan,
      locale: locale,
      onUpdate: () {
        state = state.copyWith(activePlan: _clonePlan(plan));
      },
    );

    _ref.read(conversationMemoryProvider).addAssistantMessage(response);
    _updateResultCard(plan);
    await _speakAndSettle(response, locale);
  }

  ExecutionPlan _clonePlan(ExecutionPlan plan) => ExecutionPlan(steps: plan.steps);

  void _updateResultCard(ExecutionPlan plan) {
    for (final step in plan.steps.reversed) {
      final data = step.result?.data ?? const <String, Object?>{};
      if (step.action.toolName == 'inspect_screen' && step.status == StepStatus.done) {
        state = state.copyWith(
          resultCard: ResultCard(
            title: 'Layar: ${data['windowTitle'] ?? data['packageName'] ?? '-'}',
            lines: _splitLines(data['visibleText'] as String? ?? ''),
          ),
        );
        return;
      }
      if (step.action.toolName == 'get_notification_context' && step.status == StepStatus.done) {
        final items = (data['items'] as List?) ?? const [];
        state = state.copyWith(
          resultCard: ResultCard(
            title: 'Notifikasi terbaru',
            lines: items
                .whereType<Map>()
                .map((m) => '${m['title'] ?? m['packageName']}: ${m['text'] ?? ''}')
                .cast<String>()
                .toList(),
          ),
        );
        return;
      }
      if (step.action.toolName == 'get_device_information' && step.status == StepStatus.done) {
        state = state.copyWith(
          resultCard: ResultCard(
            title: 'Perangkat',
            lines: [
              '${data['manufacturer'] ?? ''} ${data['model'] ?? ''}'.trim(),
              'Android ${data['androidRelease'] ?? ''} (SDK ${data['sdkInt'] ?? ''})',
              if (data['batteryLevel'] != null) 'Baterai ${data['batteryLevel']}%',
            ],
          ),
        );
        return;
      }
    }
  }

  List<String> _splitLines(String text) {
    if (text.isEmpty) return const <String>[];
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(12)
        .toList();
    return lines;
  }

  // ===== TTS =====

  Future<void> _speakAndSettle(String text, String locale) async {
    state = state.copyWith(voiceState: VoiceState.speaking, responseText: text);
    await _speak(text);
    state = state.copyWith(voiceState: VoiceState.idle);
  }

  Future<void> _speak(String text) async {
    final settings = await _ref.read(settingsStoreProvider).load();
    if (!settings.ttsEnabled) return;
    try {
      await _tts.speak(
        text: text,
        locale: settings.locale == 'id' ? 'id-ID' : 'en-US',
        rate: settings.ttsRate,
        pitch: settings.ttsPitch,
      );
    } catch (_) {
      // TTS unavailable: the visual response still carries the message.
    }
  }

  String _short(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;

  void clearError() {
    if (state.voiceState == VoiceState.error) {
      state = state.copyWith(voiceState: VoiceState.idle, clearStatusHint: true);
    }
  }

  @override
  void dispose() {
    _partialsSub?.cancel();
    _finalsSub?.cancel();
    _errorsSub?.cancel();
    super.dispose();
  }
}

final voiceAssistantProvider =
    StateNotifierProvider<VoiceAssistantController, AssistantUiState>(
  (ref) => VoiceAssistantController(ref),
);
