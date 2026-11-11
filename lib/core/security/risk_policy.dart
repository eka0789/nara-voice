import '../models/execution.dart';

/// Risk classification per spec §14. HIGH-risk actions always require an
/// explicit user confirmation before execution.
class RiskPolicy {
  const RiskPolicy._();

  /// Tools whose success cannot be undone or that leave the device.
  static const Set<String> _highRiskTools = <String>{
    'send_message',
    'send_email',
    'delete_data',
    'make_purchase',
    'execute_workflow',
  };

  /// Tools that create/prepare content but do not send anything.
  static const Set<String> _mediumRiskTools = <String>{
    'compose_message',
    'compose_email',
    'create_calendar_event',
    'share_text',
    'set_reminder',
  };

  static RiskLevel forTool(String toolName) {
    if (_highRiskTools.contains(toolName)) return RiskLevel.high;
    if (_mediumRiskTools.contains(toolName)) return RiskLevel.medium;
    return RiskLevel.low;
  }

  /// Whether a plan requires a confirmation card before running.
  static bool requiresConfirmation(Iterable<RiskLevel> levels) =>
      levels.any((l) => l == RiskLevel.high);
}
