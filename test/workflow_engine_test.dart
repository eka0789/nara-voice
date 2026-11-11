import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nara_voice/core/ai/orchestrator.dart';
import 'package:nara_voice/core/models/execution.dart';
import 'package:nara_voice/features/automation/workflow_engine.dart';

class MockOrchestrator extends Mock implements Orchestrator {}

ExecutionStep makeStep(String id, RiskLevel risk) => ExecutionStep(
      action: PlannedAction(
        id: id,
        toolName: 'open_application',
        args: <String, Object?>{'packageName': 'com.example.$id'},
        riskLevel: risk,
        summary: 'Open $id',
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(ExecutionPlan(steps: [makeStep('fallback', RiskLevel.low)]));
  });

  group('WorkflowEngine', () {
    test('high-risk plan starts awaitingApproval', () {
      final orchestrator = MockOrchestrator();
      final engine = WorkflowEngine(orchestrator);
      final plan = ExecutionPlan(
        steps: [makeStep('a', RiskLevel.high)],
        needsConfirmation: true,
      );
      final run = engine.create(plan, locale: 'id');
      expect(run.state, WorkflowState.awaitingApproval);
    });

    test('approve executes and reaches completed', () async {
      final orchestrator = MockOrchestrator();
      when(
        () => orchestrator.execute(any(), locale: any(named: 'locale'), onUpdate: any(named: 'onUpdate')),
      ).thenAnswer((invocation) async {
        final plan = invocation.positionalArguments.first as ExecutionPlan;
        for (final step in plan.steps) {
          step
            ..status = StepStatus.done
            ..result = ActionResult.ok('done');
        }
        return 'Selesai.';
      });

      final engine = WorkflowEngine(orchestrator);
      final run = engine.create(
        ExecutionPlan(steps: [makeStep('a', RiskLevel.low)]),
        locale: 'id',
      );
      final response = await engine.approve(run);
      expect(response, 'Selesai.');
      expect(run.state, WorkflowState.completed);
      expect(run.steps.single.status, StepStatus.done);
    });

    test('retry re-runs only failed steps (no duplicate execution)', () async {
      final orchestrator = MockOrchestrator();
      final executedIds = <String>[];
      var firstRun = true;
      when(
        () => orchestrator.execute(any(), locale: any(named: 'locale'), onUpdate: any(named: 'onUpdate')),
      ).thenAnswer((invocation) async {
        final plan = invocation.positionalArguments.first as ExecutionPlan;
        for (final step in plan.steps) {
          if (step.status == StepStatus.done) continue; // orchestrator contract
          executedIds.add(step.action.id);
          if (step.action.id == 'b' && firstRun) {
            step
              ..status = StepStatus.failed
              ..result = ActionResult.failure('boom');
          } else {
            step
              ..status = StepStatus.done
              ..result = ActionResult.ok('done');
          }
        }
        firstRun = false;
        return 'ok';
      });

      final engine = WorkflowEngine(orchestrator);
      final run = engine.create(
        ExecutionPlan(steps: [makeStep('a', RiskLevel.low), makeStep('b', RiskLevel.low)]),
        locale: 'id',
      );
      await engine.approve(run);
      expect(run.state, WorkflowState.partiallyCompleted);
      expect(run.steps.where((s) => s.status == StepStatus.done), hasLength(1));

      await engine.retry(run);
      // 'a' was already done — it must NOT be re-executed.
      expect(executedIds.where((id) => id == 'a'), hasLength(1));
      expect(run.state, WorkflowState.completed);
    });

    test('cancel marks pending steps cancelled', () {
      final orchestrator = MockOrchestrator();
      final engine = WorkflowEngine(orchestrator);
      final run = engine.create(
        ExecutionPlan(steps: [makeStep('a', RiskLevel.low), makeStep('b', RiskLevel.low)]),
        locale: 'id',
      );
      engine.cancel(run);
      expect(run.state, WorkflowState.cancelled);
      expect(run.steps.every((s) => s.status == StepStatus.cancelled), isTrue);
    });
  });
}
