import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/models/execution.dart';
import 'package:nara_voice/core/security/risk_policy.dart';

void main() {
  group('RiskPolicy', () {
    test('send/execute tools are HIGH risk', () {
      expect(RiskPolicy.forTool('send_message'), RiskLevel.high);
      expect(RiskPolicy.forTool('send_email'), RiskLevel.high);
      expect(RiskPolicy.forTool('execute_workflow'), RiskLevel.high);
    });

    test('prepare tools are MEDIUM risk', () {
      expect(RiskPolicy.forTool('compose_message'), RiskLevel.medium);
      expect(RiskPolicy.forTool('compose_email'), RiskLevel.medium);
      expect(RiskPolicy.forTool('create_calendar_event'), RiskLevel.medium);
      expect(RiskPolicy.forTool('share_text'), RiskLevel.medium);
    });

    test('open/read tools are LOW risk', () {
      expect(RiskPolicy.forTool('open_application'), RiskLevel.low);
      expect(RiskPolicy.forTool('open_device_settings'), RiskLevel.low);
      expect(RiskPolicy.forTool('inspect_screen'), RiskLevel.low);
      expect(RiskPolicy.forTool('search_web'), RiskLevel.low);
    });

    test('plans containing HIGH risk require confirmation', () {
      expect(
        RiskPolicy.requiresConfirmation([RiskLevel.low, RiskLevel.low]),
        isFalse,
      );
      expect(
        RiskPolicy.requiresConfirmation([RiskLevel.low, RiskLevel.high]),
        isTrue,
      );
    });
  });

  group('ExecutionPlan outcomes', () {
    ExecutionStep step(StepStatus status) => ExecutionStep(
          action: PlannedAction(
            id: 's',
            toolName: 'open_application',
            args: const {'packageName': 'com.example'},
            riskLevel: RiskLevel.low,
          ),
        )..status = status;

    test('all done → completed', () {
      final plan = ExecutionPlan(steps: [step(StepStatus.done), step(StepStatus.done)]);
      expect(plan.outcomeLabel, 'completed');
    });

    test('mixed → partially_completed', () {
      final plan = ExecutionPlan(steps: [step(StepStatus.done), step(StepStatus.failed)]);
      expect(plan.outcomeLabel, 'partially_completed');
    });

    test('any HIGH risk flags confirmation', () {
      final plan = ExecutionPlan(steps: [
        ExecutionStep(
          action: PlannedAction(
            id: 's',
            toolName: 'compose_message',
            args: const {'text': 'x'},
            riskLevel: RiskLevel.high,
          ),
        ),
      ]);
      expect(plan.needsConfirmation || plan.hasHighRisk, isTrue);
    });
  });
}
