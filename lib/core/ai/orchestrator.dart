import '../models/conversation.dart';
import '../models/execution.dart';
import '../security/risk_policy.dart';
import '../tools/nara_tool.dart';
import '../tools/tool_registry.dart';
import 'app_lookup.dart';
import 'cloud/cloud_client.dart';
import 'conversation_memory.dart';
import 'nlu/nlu_engine.dart';
import 'response_keys.dart';
import 'response_localizer.dart';

/// Result of planning one utterance.
sealed class PlanningOutcome {
  PlanningOutcome({required this.locale});
  final String locale;
}

class PlanReady extends PlanningOutcome {
  PlanReady({required this.plan, required super.locale, this.source = 'offline'});
  final ExecutionPlan plan;

  /// 'offline' | 'cloud' — surfaced in the UI for transparency.
  final String source;
}

class NeedClarify extends PlanningOutcome {
  NeedClarify({required this.question, this.pending, required super.locale});
  final String question;

  /// Slot-filling state to persist in the conversation memory (may be null).
  final PendingSlot? pending;
}

class DirectAnswer extends PlanningOutcome {
  DirectAnswer({required this.text, required super.locale});
  final String text;
}

/// Central AI Orchestrator (spec §8): plans, gates risk, executes, verifies.
class Orchestrator {
  Orchestrator({
    required NluEngine nlu,
    required ToolRegistry registry,
    required ConversationMemory memory,
    required AppCatalogLookup appLookup,
    CloudAiClient? cloudClient,
  })  : _nlu = nlu,
        _registry = registry,
        _memory = memory,
        _appLookup = appLookup,
        _cloud = cloudClient;

  final NluEngine _nlu;
  final ToolRegistry _registry;
  final ConversationMemory _memory;
  final AppCatalogLookup _appLookup;
  final CloudAiClient? _cloud;

  // ===== Planning =====

  Future<PlanningOutcome> plan(String transcript) async {
    final locale = _memory.messages.lastOrNull?.language ??
        detectLocale(transcript);

    // Cloud first when configured; fall back to offline NLU on any failure.
    final cloud = _cloud;
    if (cloud != null) {
      final reply = await cloud.request(
        transcript: transcript,
        locale: locale,
        history: _historyForCloud(),
        tools: _registry.describeForCloud(),
      );
      final fromCloud = _mapCloudReply(reply, locale, transcript);
      if (fromCloud != null) return fromCloud;
    }

    final outcome = _nlu.parse(
      transcript,
      pending: _memory.pending,
    );
    return _mapNluOutcome(outcome, locale);
  }

  String detectLocale(String text) {
    final normalized = text.toLowerCase();
    const idWords = ['yang', 'tolong', 'buka', 'cari', 'kirim', 'layar', 'pesannya', 'ke ', 'dan '];
    for (final w in idWords) {
      if (normalized.contains(w)) return 'id';
    }
    return 'en';
  }

  PlanningOutcome? _mapCloudReply(CloudReply? reply, String locale, String transcript) {
    if (reply == null) return null;
    switch (reply) {
      case CloudAnswer(:final text):
        return DirectAnswer(text: text, locale: locale);
      case CloudPlan(:final actions):
        final drafts = <ActionDraft>[];
        for (final action in actions) {
          final tool = _registry.lookup(action.toolName);
          if (tool == null) continue; // Never hallucinate tools.
          drafts.add(ActionDraft(
            tool: tool.name,
            args: action.args,
            risk: RiskPolicy.forTool(tool.name),
            summaryKey: _summaryKeyFor(tool.name),
          ));
        }
        if (drafts.isEmpty) return null;
        return PlanReady(
          plan: _planFromDrafts(drafts, locale),
          locale: locale,
          source: 'cloud',
        );
    }
  }

  ResponseKey _summaryKeyFor(String toolName) => switch (toolName) {
        'open_application' => ResponseKey.summaryOpenApp,
        'open_device_settings' => ResponseKey.summaryOpenSettings,
        'open_maps' => ResponseKey.summaryOpenMaps,
        'youtube_search' => ResponseKey.summaryYouTubeSearch,
        'open_spotify' => ResponseKey.summarySpotifySearch,
        'compose_email' => ResponseKey.summaryComposeEmail,
        'compose_message' => ResponseKey.summaryComposeMessage,
        'share_text' => ResponseKey.summaryShare,
        'create_calendar_event' => ResponseKey.summaryCalendar,
        'inspect_screen' => ResponseKey.summaryInspectScreen,
        'get_notification_context' => ResponseKey.summaryNotifications,
        'get_device_information' => ResponseKey.summaryDeviceInfo,
        'search_web' => ResponseKey.summaryWebSearch,
        _ => ResponseKey.summaryOpenApp,
      };

  PlanningOutcome _mapNluOutcome(NluOutcome outcome, String locale) {
    switch (outcome) {
      case NluPlan(:final drafts):
        return PlanReady(plan: _planFromDrafts(drafts, locale), locale: locale);
      case NluClarify(:final questionKey, :final pending):
        return NeedClarify(
          question: ResponseLocalizer.question(questionKey, locale),
          pending: pending,
          locale: locale,
        );
      case NluAnswer(:final answerKey):
        return DirectAnswer(text: ResponseLocalizer.answer(answerKey, locale), locale: locale);
    }
  }

  ExecutionPlan _planFromDrafts(List<ActionDraft> drafts, String locale) {
    final steps = drafts.map((d) {
      final action = PlannedAction(
        id: 'step-${DateTime.now().microsecondsSinceEpoch}-${d.tool}',
        toolName: d.tool,
        args: d.args,
        riskLevel: d.risk,
        summary: ResponseLocalizer.summary(d, locale),
      );
      return ExecutionStep(action: action);
    }).toList();
    return ExecutionPlan(
      steps: steps,
      needsConfirmation: RiskPolicy.requiresConfirmation(drafts.map((d) => d.risk)),
    );
  }

  // ===== Execution =====

  /// Executes a plan sequentially, reporting every step. Returns the final
  /// localized response grounded in actual step results.
  Future<String> execute(
    ExecutionPlan plan, {
    String locale = 'id',
    void Function()? onUpdate,
  }) async {
    final context = ToolContext(locale: locale);

    for (final step in plan.steps) {
      if (step.status == StepStatus.done || step.status == StepStatus.cancelled) {
        continue; // Retry-safe: never re-run completed work.
      }
      step.status = StepStatus.running;
      onUpdate?.call();
      final result = await _registry.execute(step.action.toolName, step.action.args, context);
      step
        ..result = result
        ..status = result.success ? StepStatus.done : StepStatus.failed;
      onUpdate?.call();
    }

    return ResponseLocalizer.outcome(
      outcomeLabel: plan.outcomeLabel,
      steps: plan.steps,
      locale: locale,
    );
  }

  /// Re-runs only failed/pending steps of an existing plan (workflow retry).
  Future<String> retry(
    ExecutionPlan plan, {
    String locale = 'id',
    void Function()? onUpdate,
  }) =>
      execute(plan, locale: locale, onUpdate: onUpdate);

  List<Map<String, String>> _historyForCloud() => _memory.messages
      .takeLast(8)
      .map((m) => <String, String>{
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.text,
          })
      .toList();

  Future<(String, double)?> lookupApp(String name) => _appLookup.lookup(name);
}

extension _TakeLastX on List<ConversationMessage> {
  Iterable<ConversationMessage> takeLast(int n) =>
      length <= n ? this : skip(length - n);
}
