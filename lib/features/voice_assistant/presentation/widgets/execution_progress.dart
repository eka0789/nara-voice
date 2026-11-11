import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/models/execution.dart';

/// Live execution progress stepper (spec §13: execution progress).
class ExecutionProgress extends StatelessWidget {
  const ExecutionProgress({super.key, required this.plan});

  final ExecutionPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progres eksekusi',
              style: TextStyle(
                color: NaraTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            for (final step in plan.steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    _icon(step.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.action.summary ?? step.action.toolName,
                        style: TextStyle(
                          fontSize: 14,
                          color: step.status == StepStatus.failed
                              ? NaraTheme.danger
                              : Colors.white,
                        ),
                      ),
                    ),
                    if (step.status == StepStatus.failed && step.result != null)
                      Text(
                        step.result!.errorCode ?? '',
                        style: TextStyle(color: NaraTheme.danger, fontSize: 11),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _icon(StepStatus status) {
    switch (status) {
      case StepStatus.done:
        return Icon(Icons.check_circle_rounded, size: 18, color: NaraTheme.success);
      case StepStatus.failed:
        return Icon(Icons.cancel_rounded, size: 18, color: NaraTheme.danger);
      case StepStatus.running:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: NaraTheme.accentPurple),
        );
      case StepStatus.cancelled:
        return Icon(Icons.block_rounded, size: 18, color: NaraTheme.textSecondary);
      case StepStatus.skipped:
      case StepStatus.pending:
        return Icon(Icons.radio_button_unchecked_rounded, size: 18, color: NaraTheme.textSecondary);
    }
  }
}
