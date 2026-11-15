import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/models/execution.dart';
import '../../../core/routines/routine_store.dart';
import '../../../l10n/app_localizations.dart';
import '../workflow_engine.dart';

/// Automation dashboard: daily routines (tap-to-run schedules) plus workflow
/// runs with live states and retry.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final runs = ref.watch(workflowEngineProvider);
    final routines = ref.watch(routineStoreProvider);

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoutineEditor(context, ref),
        icon: const Icon(Icons.schedule_rounded),
        label: Text(l10n.addRoutine),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          _RoutinesSection(routines: routines),
          if (runs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                l10n.noWorkflows,
                textAlign: TextAlign.center,
                style: TextStyle(color: NaraTheme.textSecondary, height: 1.5),
              ),
            )
          else
            for (final run in runs) _RunTile(run: run),
        ],
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

/// Daily-routines section: tap-to-run schedules, managed here or via voice
/// ("pasang rutin jam 7 buka youtube").
class _RoutinesSection extends ConsumerWidget {
  const _RoutinesSection({required this.routines});

  final List<Routine> routines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.routines,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.routineTapToRun,
            style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary, height: 1.4),
          ),
        ),
        if (routines.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              l10n.routinesEmpty,
              style: TextStyle(fontSize: 13, color: NaraTheme.textSecondary, height: 1.5),
            ),
          )
        else
          for (final routine in routines) _RoutineTile(routine: routine),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final time = '${routine.time.hour.toString().padLeft(2, '0')}:'
        '${routine.time.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          routine.daily ? Icons.alarm_rounded : Icons.schedule_rounded,
          color: routine.enabled ? NaraTheme.accentPurple : NaraTheme.textSecondary,
        ),
        title: Text(
          '$time · ${routine.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: routine.enabled ? null : NaraTheme.textSecondary,
          ),
        ),
        subtitle: Text(
          '${routine.commands.join(' • ')} · ${routine.daily ? l10n.routineDaily : l10n.planStepPending}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: NaraTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: routine.enabled,
              onChanged: (v) => ref
                  .read(routineStoreProvider.notifier)
                  .setEnabled(routine, enabled: v),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () =>
                  ref.read(routineStoreProvider.notifier).remove(routine),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showRoutineEditor(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  var time = DateTime.now().add(const Duration(hours: 1));
  var daily = true;
  final commandsController = TextEditingController();

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(l10n.addRoutine),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.routineTime),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: TimeOfDay.fromDateTime(time),
                    );
                    if (picked != null) {
                      setState(() {
                        time = DateTime(time.year, time.month, time.day, picked.hour, picked.minute);
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time_rounded, size: 18),
                  label: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commandsController,
              maxLines: 3,
              decoration: InputDecoration(hintText: l10n.routineCommandsHint),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.routineDaily, style: const TextStyle(fontSize: 14)),
              value: daily,
              onChanged: (v) => setState(() => daily = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    ),
  );

  final commands = commandsController.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (saved == true && commands.isNotEmpty) {
    await ref.read(routineStoreProvider.notifier).add(
          time: time,
          daily: daily,
          title: commands.first,
          commands: commands,
        );
  }
}
