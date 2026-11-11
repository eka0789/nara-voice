/// Execution plan models used by the orchestrator and the workflow engine.
enum StepStatus { pending, running, done, failed, skipped, cancelled }

enum RiskLevel { low, medium, high }

class PlannedAction {
  const PlannedAction({
    required this.id,
    required this.toolName,
    required this.args,
    required this.riskLevel,
    this.summary,
  });

  final String id;
  final String toolName;
  final Map<String, Object?> args;
  final RiskLevel riskLevel;

  /// Short human-readable description shown in the UI (ID/EN aware upstream).
  final String? summary;

  PlannedAction copyWith({Map<String, Object?>? args, RiskLevel? riskLevel}) {
    return PlannedAction(
      id: id,
      toolName: toolName,
      args: args ?? this.args,
      riskLevel: riskLevel ?? this.riskLevel,
      summary: summary,
    );
  }
}

class ActionResult {
  const ActionResult({
    required this.success,
    required this.message,
    this.data = const <String, Object?>{},
    this.errorCode,
  });

  final bool success;
  final String message;
  final Map<String, Object?> data;
  final String? errorCode;

  static ActionResult ok(String message, [Map<String, Object?> data = const {}]) =>
      ActionResult(success: true, message: message, data: data);

  static ActionResult failure(String message,
      [String? code, Map<String, Object?> data = const {}]) =>
      ActionResult(success: false, message: message, errorCode: code, data: data);
}

/// One step of an execution plan with its live status.
class ExecutionStep {
  ExecutionStep({
    required this.action,
    this.status = StepStatus.pending,
    this.result,
  });

  final PlannedAction action;
  StepStatus status;
  ActionResult? result;

  bool get isTerminal =>
      status == StepStatus.done ||
      status == StepStatus.failed ||
      status == StepStatus.skipped ||
      status == StepStatus.cancelled;
}

class ExecutionPlan {
  ExecutionPlan({required this.steps, this.needsConfirmation = false})
      : assert(steps.isNotEmpty, 'An execution plan needs at least one step');

  final List<ExecutionStep> steps;
  bool needsConfirmation;

  bool get hasHighRisk => steps.any((s) => s.action.riskLevel == RiskLevel.high);

  bool get allDone => steps.every((s) => s.status == StepStatus.done);

  bool get anyFailed => steps.any((s) => s.status == StepStatus.failed);

  /// Aggregated outcome used for the final spoken/visual report.
  String get outcomeLabel {
    if (allDone) return 'completed';
    if (steps.any((s) => s.status == StepStatus.done) && anyFailed) {
      return 'partially_completed';
    }
    if (anyFailed) return 'failed';
    return 'pending';
  }
}
