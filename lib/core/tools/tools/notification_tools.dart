import '../../models/execution.dart';
import '../../platform/notifications_platform.dart';
import '../nara_tool.dart';

/// get_notification_context — recent notification titles from the opt-in
/// listener. Reports only what the system granted.
class NotificationContextTool extends NaraTool {
  NotificationContextTool(this._notifications);

  final NotificationsPlatform _notifications;

  @override
  String get name => 'get_notification_context';
  @override
  String get description => 'Summarize recent notifications (requires listener access granted by the user).';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'limit': ToolParam(type: ToolParamType.integer, description: 'Max items', defaultValue: 8),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final items = await _notifications.getRecent(limit: (args['limit'] as int?) ?? 8);
    return ActionResult.ok(
      items.isEmpty ? 'No recent notifications' : 'Collected ${items.length} notifications',
      {
        'items': items
            .map((n) => <String, Object?>{
                  'packageName': n.packageName,
                  'title': n.title,
                  'text': n.text,
                  'postedAt': n.postedAt,
                })
            .toList(),
      },
    );
  }
}
