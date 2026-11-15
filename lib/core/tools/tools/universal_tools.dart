import '../../models/execution.dart';
import '../../models/screen_context.dart';
import '../../platform/accessibility_platform.dart';
import '../../platform/device_platform.dart';
import '../../platform/intents_platform.dart';
import '../nara_tool.dart';
import 'screen_tools.dart';

/// ===== Universal app control through the accessibility layer =====
///
/// These tools operate on ANY application's UI: tap a visible control by its
/// label, type into the focused field, navigate system-wide. Together with
/// discover/launch they make every installed app voice-controllable.

/// tap_by_label — taps a visible control whose label matches [label].
/// Auto-inspects the screen first when the last snapshot is stale, so the
/// user can command "tekan Play" straight away.
class TapByLabelTool extends NaraTool {
  TapByLabelTool(this._accessibility, this._screenMemory);

  final AccessibilityPlatform _accessibility;
  final ScreenMemory _screenMemory;

  /// Re-inspect when the cached snapshot is older than this.
  static const _snapshotTtl = Duration(milliseconds: 8000);

  @override
  String get name => 'tap_by_label';
  @override
  String get description =>
      'Tap a visible button/control in the current screen of any app by its label. '
      'Use after inspecting the screen or when the user names a visible control.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'label': ToolParam(
          type: ToolParamType.string,
          description: 'Visible text of the control to tap',
          required: true,
        ),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final query = (args['label'] as String).trim().toLowerCase();
    if (query.isEmpty) {
      return ActionResult.failure('No label given', 'VALIDATION');
    }

    var screen = _screenMemory.current;
    final stale = screen == null ||
        DateTime.now().millisecondsSinceEpoch - screen.timestamp >
            _snapshotTtl.inMilliseconds;
    if (stale) {
      screen = await _accessibility.inspectScreen();
      if (screen.status == 'ok') _screenMemory.remember(screen);
    }
    if (screen.status != 'ok') {
      return ActionResult.failure(
        'Cannot read the screen right now (accessibility disabled?)',
        'SERVICE_NOT_ENABLED',
      );
    }

    ScreenElement? best;
    var bestScore = 0.0;
    for (final element in screen.interactiveElements) {
      final score = labelMatchScore(element.label.toLowerCase(), query);
      if (score > bestScore || (score == bestScore && score > 0 && element.clickable && !(best?.clickable ?? false))) {
        best = element;
        bestScore = score;
      }
    }
    if (best == null) {
      return ActionResult.failure(
        'No visible control matches "$query" on this screen',
        'NOT_FOUND',
      );
    }

    final performed = await _accessibility.tapElement(best);
    return ActionResult.ok(
      performed ? 'Tapped "$query"' : 'Tap did not succeed',
      {
        'performed': performed,
        'label': best.label,
        'elementId': best.id,
        'score': bestScore,
      },
    );
  }

  /// 1.0 exact, 0.9 word-boundary contains, 0.7 substring, 0.6 all tokens.
  /// Public for tests and reuse.
  static double labelMatchScore(String label, String query) {
    if (label == query) return 1.0;
    if (label.contains(' $query') || label.startsWith('$query ')) return 0.9;
    if (label.contains(query)) return 0.7;
    final tokens = query.split(RegExp(r'\s+'));
    if (tokens.length > 1 && tokens.every(label.contains)) return 0.6;
    return 0;
  }
}

/// type_text — types into the currently focused input field of any app.
class TypeTextTool extends NaraTool {
  TypeTextTool(this._accessibility);

  final AccessibilityPlatform _accessibility;

  @override
  String get name => 'type_text';
  @override
  String get description =>
      'Type text into the focused input field of the active app (search boxes, '
      'chat fields, forms). Password fields are never typed into.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'value': ToolParam(type: ToolParamType.string, description: 'Text to type', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Duration get timeout => const Duration(seconds: 8);

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final performed = await _accessibility.typeText(args['value'] as String);
    return ActionResult.ok(
      performed ? 'Text typed' : 'No focused editable field — tap the field first',
      {'performed': performed},
    );
  }
}

/// Shared implementation of the one-shot global navigation actions.
abstract class GlobalActionTool extends NaraTool {
  GlobalActionTool(this._accessibility);

  final AccessibilityPlatform _accessibility;

  Future<bool> run();

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final performed = await run();
    return ActionResult.ok(
      performed ? 'Done' : 'System action refused (accessibility disabled?)',
      {'performed': performed},
    );
  }
}

class GoBackTool extends GlobalActionTool {
  GoBackTool(super._accessibility);
  @override
  String get name => 'go_back';
  @override
  String get description => 'Navigate back one step in the active app.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Future<bool> run() => _accessibility.goBack();
}

class GoHomeTool extends GlobalActionTool {
  GoHomeTool(super._accessibility);
  @override
  String get name => 'go_home';
  @override
  String get description => 'Return to the home screen.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Future<bool> run() => _accessibility.goHome();
}

class OpenRecentsTool extends GlobalActionTool {
  OpenRecentsTool(super._accessibility);
  @override
  String get name => 'open_recents';
  @override
  String get description => 'Show the recent-apps switcher.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Future<bool> run() => _accessibility.openRecents();
}

class OpenNotificationShadeTool extends GlobalActionTool {
  OpenNotificationShadeTool(super._accessibility);
  @override
  String get name => 'open_notification_shade';
  @override
  String get description => 'Pull down the system notification shade.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Future<bool> run() => _accessibility.openNotificationShade();
}

class OpenQuickSettingsTool extends GlobalActionTool {
  OpenQuickSettingsTool(super._accessibility);
  @override
  String get name => 'open_quick_settings';
  @override
  String get description => 'Open the system quick-settings panel.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Future<bool> run() => _accessibility.openQuickSettings();
}

class TakeScreenshotTool extends GlobalActionTool {
  TakeScreenshotTool(super._accessibility);
  @override
  String get name => 'take_screenshot';
  @override
  String get description => 'Capture a screenshot of the current screen.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};
  @override
  RiskLevel get riskLevel => RiskLevel.low;
  @override
  Duration get timeout => const Duration(seconds: 6);
  @override
  Future<bool> run() => _accessibility.takeScreenshot();
}

/// ===== Device controls =====

/// volume_control — media volume up/down/mute with the system HUD.
class VolumeControlTool extends NaraTool {
  VolumeControlTool(this._device);

  final DevicePlatform _device;

  @override
  String get name => 'volume_control';
  @override
  String get description => 'Raise, lower or mute the media volume.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'action': ToolParam(
          type: ToolParamType.string,
          description: 'up | down | mute',
          required: true,
        ),
      };
  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final action = (args['action'] as String?) ?? '';
    final Map<String, Object?> result;
    switch (action) {
      case 'up':
        result = await _device.volumeUp();
      case 'down':
        result = await _device.volumeDown();
      case 'mute':
        result = await _device.toggleMute();
      default:
        return ActionResult.failure('Unsupported volume action: $action', 'UNSUPPORTED');
    }
    if (result['performed'] != true) {
      return ActionResult.failure('Volume could not be changed', 'UNSUPPORTED');
    }
    final level = result['level'];
    final muted = result['muted'] == true;
    final detail = muted
        ? 'muted'
        : level != null
            ? 'volume $level%'
            : 'adjusted';
    return ActionResult.ok('Media $detail', {...result, 'action': action});
  }
}

/// toggle_flashlight — camera torch (needs no user prompt: normal permission).
class FlashlightTool extends NaraTool {
  FlashlightTool(this._device);

  final DevicePlatform _device;

  @override
  String get name => 'toggle_flashlight';
  @override
  String get description => 'Turn the camera flash (torch) on or off.';
  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'on': ToolParam(type: ToolParamType.boolean, description: 'true = on, false = off'),
      };
  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final on = (args['on'] as bool?) ?? true;
    final result = await _device.setTorch(on: on);
    if (result['performed'] != true) {
      return ActionResult.failure('No flashlight available on this device', 'UNSUPPORTED');
    }
    return ActionResult.ok(on ? 'Flashlight on' : 'Flashlight off', {'on': on});
  }
}

/// ===== Prepare-only phone & clock handoffs =====

/// dial_number — opens the dialer prefilled; the user presses call.
class DialNumberTool extends NaraTool {
  DialNumberTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'dial_number';
  @override
  String get description =>
      'Open the phone dialer with a number prefilled. The user presses call.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'number': ToolParam(
          type: ToolParamType.string,
          description: 'Phone number to dial',
          required: true,
        ),
      };
  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.dialNumber(args['number'] as String);
    if (!handoff.launched) {
      return ActionResult.failure('No dialer application available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Dialer opened — user must press call', {'handler': handoff.handler});
  }
}

/// set_alarm — opens the clock app with a prefilled alarm draft.
class SetAlarmTool extends NaraTool {
  SetAlarmTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'set_alarm';
  @override
  String get description =>
      'Open the clock app with a pre-filled alarm draft at the given time '
      '(the user reviews and saves it).';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'hour': ToolParam(type: ToolParamType.integer, description: 'Hour 0-23', required: true),
        'minute': ToolParam(type: ToolParamType.integer, description: 'Minute 0-59'),
        'label': ToolParam(type: ToolParamType.string, description: 'Alarm label'),
      };
  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.setAlarm(
      hour: args['hour'] as int,
      minute: (args['minute'] as int?) ?? 0,
      label: args['label'] as String?,
    );
    if (!handoff.launched) {
      return ActionResult.failure('No clock application available', 'NOT_RESOLVED');
    }
    final hh = (args['hour'] as int).toString().padLeft(2, '0');
    final mm = (((args['minute'] as int?) ?? 0)).toString().padLeft(2, '0');
    return ActionResult.ok(
      'Alarm draft at $hh:$mm opened — user must save',
      {'handler': handoff.handler, 'time': '$hh:$mm'},
    );
  }
}

/// set_timer — opens the clock app with a prefilled countdown draft.
class SetTimerTool extends NaraTool {
  SetTimerTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'set_timer';
  @override
  String get description =>
      'Open the clock app with a pre-filled countdown timer draft '
      '(the user reviews and starts it).';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'seconds': ToolParam(type: ToolParamType.integer, description: 'Duration in seconds', required: true),
        'label': ToolParam(type: ToolParamType.string, description: 'Timer label'),
      };
  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.setTimer(
      seconds: args['seconds'] as int,
      label: args['label'] as String?,
    );
    if (!handoff.launched) {
      return ActionResult.failure('No clock application available', 'NOT_RESOLVED');
    }
    final total = args['seconds'] as int;
    final mins = total ~/ 60;
    final secs = total % 60;
    final shown = mins > 0 ? '${mins}m${secs > 0 ? ' ${secs}s' : ''}' : '${secs}s';
    return ActionResult.ok(
      'Timer draft $shown opened — user must start it',
      {'handler': handoff.handler, 'seconds': total},
    );
  }
}
