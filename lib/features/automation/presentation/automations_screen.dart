import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/models/execution.dart';
import '../../../l10n/app_localizations.dart';
import '../workflow_engine.dart';

/// Automation dashboard: workflow runs with live states and retry.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final runs = ref.watch(workflowEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workflowHistory),
        actions: [
          if (runs.isNotEmpty)
            IconButton(
              tooltip: l10n.clearMemory,
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => ref.read(workflowEngineProvider.notifier).clearHistory(),
            ),
        ],
      ),
      body: runs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.noWorkflows,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NaraTheme.textSecondary, height: 1.5),
                ),
              ),
            )
          : ListView.builder(
              itemCount: runs.length,
              itemBuilder: (context, index) => _RunTile(run: runs[index]),
            ),
      bottomNavigationBar: const NaraNavigationBar(current: '/automations'),
    );
  }
}

class _RunTile extends ConsumerWidget {
  const _RunTile({required this.run});

  final WorkflowRun run;

  (String, Color, IconData) _meta(AppLocalizations l10n) {
    switch (run.state) {
      case WorkflowState.running:
        return (l10n.workflowRunning, NaraTheme.accentPurple, Icons.autorenew_rounded);
      case WorkflowState.completed:
        return (l10n.workflowCompleted, NaraTheme.success, Icons.check_circle_rounded);
      case WorkflowState.partiallyCompleted:
        return (l10n.workflowPartial, NaraTheme.warning, Icons.rule_rounded);
      case WorkflowState.failed:
        return (l10n.workflowFailed, NaraTheme.danger, Icons.error_rounded);
      case WorkflowState.cancelled:
        return (l10n.workflowCancelled, NaraTheme.textSecondary, Icons.block_rounded);
      case WorkflowState.awaitingApproval:
        return (l10n.workflowAwaiting, NaraTheme.warning, Icons.help_outline_rounded);
      case WorkflowState.paused:
      case WorkflowState.draft:
        return (l10n.planStepPending, NaraTheme.textSecondary, Icons.pause_circle_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color, icon) = _meta(l10n);
    final canRetry = run.state == WorkflowState.failed ||
        run.state == WorkflowState.partiallyCompleted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    run.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            for (final step in run.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      step.status == StepStatus.done
                          ? Icons.check_rounded
                          : step.status == StepStatus.failed
                              ? Icons.close_rounded
                              : Icons.remove_rounded,
                      size: 14,
                      color: step.status == StepStatus.done
                          ? NaraTheme.success
                          : step.status == StepStatus.failed
                              ? NaraTheme.danger
                              : NaraTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.action.summary ?? step.action.toolName,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (run.finalResponse != null) ...[
              const SizedBox(height: 6),
              Text(
                run.finalResponse!,
                style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary, height: 1.4),
              ),
            ],
            if (canRetry)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final engine = ref.read(workflowEngineProvider.notifier);
                    await engine.retry(run);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.retry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
