import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/orchestrator.dart';
import '../../core/di.dart';
import '../../core/models/execution.dart';

/// Workflow run states (spec §11).
enum WorkflowState {
  draft,
  awaitingApproval,
  running,
  paused,
  completed,
  partiallyCompleted,
  failed,
  cancelled,
}

/// A persisted multi-step run with retry support. Completed steps are never
/// re-executed on retry — recovery without duplicating actions.
class WorkflowRun {
  WorkflowRun({required this.steps, String? id, WorkflowState? state, DateTime? createdAt})
      : id = id ?? const Uuid().v4(),
        state = state ?? WorkflowState.draft,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = DateTime.now();

  final String id;
  final List<ExecutionStep> steps;
  WorkflowState state;
  final DateTime createdAt;
  DateTime updatedAt;
  String? finalResponse;

  String get title {
    final first = steps.firstOrNull;
    return first?.action.summary ?? first?.action.toolName ?? 'Workflow';
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'finalResponse': finalResponse,
        'steps': steps
            .map((s) => <String, Object?>{
                  'action': <String, Object?>{
                    'id': s.action.id,
                    'toolName': s.action.toolName,
                    'args': s.action.args,
                    'riskLevel': s.action.riskLevel.name,
                    'summary': s.action.summary,
                  },
                  'status': s.status.name,
                  'resultMessage': s.result?.message,
                  'resultSuccess': s.result?.success,
                  'errorCode': s.result?.errorCode,
                })
            .toList(),
      };

  static WorkflowRun fromMap(Map<Object?, Object?> map) {
    final rawSteps = (map['steps'] as List<Object?>?) ?? const <Object?>[];
    final steps = rawSteps.whereType<Map<Object?, Object?>>().map((raw) {
      final actionMap = (raw['action'] as Map<Object?, Object?>?) ?? const {};
      final action = PlannedAction(
        id: (actionMap['id'] as String?) ?? '',
        toolName: (actionMap['toolName'] as String?) ?? '',
        args: (actionMap['args'] as Map<Object?, Object?>?)?.cast<String, Object?>() ?? {},
        riskLevel: RiskLevel.values.firstWhere(
          (r) => r.name == (actionMap['riskLevel'] as String?),
          orElse: () => RiskLevel.low,
        ),
        summary: actionMap['summary'] as String?,
      );
      final step = ExecutionStep(action: action);
      step.status = StepStatus.values.firstWhere(
        (s) => s.name == (raw['status'] as String?),
        orElse: () => StepStatus.pending,
      );
      final success = raw['resultSuccess'] as bool?;
      if (success != null) {
        step.result = ActionResult(
          success: success,
          message: (raw['resultMessage'] as String?) ?? '',
          errorCode: raw['errorCode'] as String?,
        );
      }
      return step;
    }).toList();
    final run = WorkflowRun(
      id: map['id'] as String?,
      steps: steps,
      state: WorkflowState.values.firstWhere(
        (s) => s.name == (map['state'] as String?),
        orElse: () => WorkflowState.failed,
      ),
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ?? DateTime.now(),
    );
    run.finalResponse = map['finalResponse'] as String?;
    return run;
  }
}

/// The workflow engine: owns runs, drives execution through the orchestrator,
/// persists the last few runs to a local JSON file, and supports retry of
/// failed runs without duplicating completed steps.
class WorkflowEngine extends StateNotifier<List<WorkflowRun>> {
  WorkflowEngine(this._orchestrator) : super(const <WorkflowRun>[]) {
    _load();
  }

  static const _maxRuns = 20;

  final Orchestrator _orchestrator;

  /// Creates a run from a plan. HIGH-risk plans stay awaitingApproval until
  /// [approve] is called.
  WorkflowRun create(ExecutionPlan plan, {required String locale}) {
    final run = WorkflowRun(steps: plan.steps);
    run.state = plan.needsConfirmation ? WorkflowState.awaitingApproval : WorkflowState.draft;
    state = [run, ...state].take(_maxRuns).toList();
    _persist();
    return run;
  }

  Future<String> approve(WorkflowRun run, {String locale = 'id'}) async {
    return _executeRun(run, locale: locale);
  }

  void cancel(WorkflowRun run) {
    if (run.state == WorkflowState.running) return; // cannot cancel mid-flight step
    run.state = WorkflowState.cancelled;
    run.updatedAt = DateTime.now();
    for (final step in run.steps) {
      if (step.status == StepStatus.pending || step.status == StepStatus.running) {
        step.status = StepStatus.cancelled;
      }
    }
    _refresh();
  }

  /// Retries only failed/pending steps. Completed steps stay done.
  Future<String> retry(WorkflowRun run, {String locale = 'id'}) async {
    if (run.state == WorkflowState.running) return run.finalResponse ?? '';
    return _executeRun(run, locale: locale);
  }

  Future<String> _executeRun(WorkflowRun run, {required String locale}) async {
    run.state = WorkflowState.running;
    run.updatedAt = DateTime.now();
    _refresh();

    final response = await _orchestrator.execute(
      ExecutionPlan(steps: run.steps),
      locale: locale,
      onUpdate: _refresh,
    );
    run.finalResponse = response;
    run.updatedAt = DateTime.now();
    run.state = _outcomeState(run);
    _persist();
    _refresh();
    return response;
  }

  WorkflowState _outcomeState(WorkflowRun run) {
    final anyFailed = run.steps.any((s) => s.status == StepStatus.failed);
    final allDone = run.steps.every((s) => s.status == StepStatus.done);
    final anyDone = run.steps.any((s) => s.status == StepStatus.done);
    if (allDone) return WorkflowState.completed;
    if (anyFailed && anyDone) return WorkflowState.partiallyCompleted;
    if (anyFailed) return WorkflowState.failed;
    return WorkflowState.cancelled;
  }

  void _refresh() {
    // StateNotifier mutates WorkflowRun objects in place; emit a new list so
    // listeners rebuild.
    state = List.of(state);
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nara_workflows.json');
      await file.writeAsString(jsonEncode(state.map((r) => r.toMap()).toList()));
    } catch (_) {
      // Persistence is best-effort; runs still work in memory.
    }
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/nara_workflows.json');
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return;
      state = decoded
          .whereType<Map<Object?, Object?>>()
          .map(WorkflowRun.fromMap)
          .toList()
          .take(_maxRuns)
          .toList();
    } catch (_) {
      // Corrupt file: start clean rather than crash.
    }
  }

  void clearHistory() {
    state = const <WorkflowRun>[];
    _persist();
  }
}

final workflowEngineProvider =
    StateNotifierProvider<WorkflowEngine, List<WorkflowRun>>(
  (ref) => WorkflowEngine(ref.watch(orchestratorProvider)),
);
