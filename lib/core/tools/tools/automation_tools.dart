import '../../models/execution.dart';
import '../../routines/routine_store.dart';
import '../nara_tool.dart';

/// create_routine — schedules a daily (or one-shot) tap-to-run routine.
/// At the chosen time NARA posts a notification; tapping it replays the
/// stored command through the normal voice pipeline in the foreground.
class CreateRoutineTool extends NaraTool {
  CreateRoutineTool(this._store);

  final RoutineStore _store;

  @override
  String get name => 'create_routine';
  @override
  String get description =>
      'Schedule a daily routine: at the given time NARA reminds with a '
      'tap-to-run notification that replays the given command.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'hour': ToolParam(type: ToolParamType.integer, description: 'Hour 0-23', required: true),
        'minute': ToolParam(type: ToolParamType.integer, description: 'Minute 0-59'),
        'command': ToolParam(
          type: ToolParamType.string,
          description: 'The NARA command to schedule (e.g. "buka whatsapp")',
          required: true,
        ),
        'daily': ToolParam(type: ToolParamType.boolean, description: 'Repeat daily (default true)'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final hour = args['hour'] as int;
    final minute = (args['minute'] as int?) ?? 0;
    final command = (args['command'] as String).trim();
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return ActionResult.failure('Time out of range', 'VALIDATION');
    }
    if (command.isEmpty) {
      return ActionResult.failure('Routine needs a command to run', 'VALIDATION');
    }
    final now = DateTime.now();
    final time = DateTime(now.year, now.month, now.day, hour, minute);
    final daily = (args['daily'] as bool?) ?? true;
    final routine = await _store.add(
      time: time,
      daily: daily,
      title: command,
      commands: [command],
    );
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    return ActionResult.ok(
      daily
          ? 'Daily routine scheduled at $hh:$mm'
          : 'One-shot routine scheduled at $hh:$mm',
      {'time': '$hh:$mm', 'command': command, 'id': routine.id, 'daily': daily},
    );
  }
}
