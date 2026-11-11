import '../../models/execution.dart';
import '../../models/screen_context.dart';
import '../../platform/accessibility_platform.dart';
import '../../platform/device_platform.dart';
import '../nara_tool.dart';

/// inspect_screen — reads visible content through the opt-in accessibility
/// service. Password fields are excluded by the native layer.
class InspectScreenTool extends NaraTool {
  InspectScreenTool(this._accessibility, this._screenMemory);

  final AccessibilityPlatform _accessibility;
  final ScreenMemory _screenMemory;

  @override
  String get name => 'inspect_screen';
  @override
  String get description => 'Read visible screen content (requires accessibility enabled by the user).';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Duration get timeout => const Duration(seconds: 6);

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final screen = await _accessibility.inspectScreen();
    if (screen.status == 'empty') {
      return ActionResult.failure('Nothing readable on screen right now', 'EMPTY');
    }
    _screenMemory.remember(screen);
    return ActionResult.ok(
      'Screen content extracted (${screen.nodeCount} nodes)',
      {
        'packageName': screen.packageName,
        'windowTitle': screen.windowTitle,
        'visibleText': screen.visibleText,
        'elements': screen.interactiveElements
            .take(30)
            .map((e) => <String, Object?>{
                  'id': e.id,
                  'label': e.label,
                  'type': e.isInputElement ? 'input' : (e.scrollable ? 'scrollable' : 'button'),
                })
            .toList(),
      },
    );
  }
}

/// get_active_application — foreground package via accessibility (read-only).
class GetActiveAppTool extends NaraTool {
  GetActiveAppTool(this._accessibility);

  final AccessibilityPlatform _accessibility;

  @override
  String get name => 'get_active_application';
  @override
  String get description => 'Identify the currently active application.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final pkg = await _accessibility.currentApp();
    if (pkg == null) {
      return ActionResult.failure('Active app unknown (accessibility disabled?)', 'SERVICE_NOT_ENABLED');
    }
    return ActionResult.ok('Active app: $pkg', {'packageName': pkg});
  }
}

/// tap_accessibility_element — taps a previously inspected element.
class TapElementTool extends NaraTool {
  TapElementTool(this._accessibility, this._screenMemory);

  final AccessibilityPlatform _accessibility;
  final ScreenMemory _screenMemory;

  @override
  String get name => 'tap_accessibility_element';
  @override
  String get description => 'Tap a button/element found by inspect_screen.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'elementId': ToolParam(type: ToolParamType.string, description: 'Element id from inspect_screen', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final element = _screenMemory.element(args['elementId'] as String);
    if (element == null) {
      return ActionResult.failure('Element not found — inspect the screen first', 'NOT_FOUND');
    }
    final performed = await _accessibility.tapElement(element);
    return ActionResult.ok(
      performed ? 'Element tapped' : 'Tap did not succeed',
      {'performed': performed, 'elementId': element.id, 'label': element.label},
    );
  }
}

/// input_accessibility_text — types into a field found by inspect_screen.
class InputTextTool extends NaraTool {
  InputTextTool(this._accessibility, this._screenMemory);

  final AccessibilityPlatform _accessibility;
  final ScreenMemory _screenMemory;

  @override
  String get name => 'input_accessibility_text';
  @override
  String get description => 'Type text into an input field found by inspect_screen.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'elementId': ToolParam(type: ToolParamType.string, description: 'Element id from inspect_screen', required: true),
        'value': ToolParam(type: ToolParamType.string, description: 'Text to input', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final element = _screenMemory.element(args['elementId'] as String);
    if (element == null) {
      return ActionResult.failure('Element not found — inspect the screen first', 'NOT_FOUND');
    }
    if (!element.isInputElement) {
      return ActionResult.failure('Element is not an input field', 'NOT_EDITABLE');
    }
    final performed = await _accessibility.inputText(element, args['value'] as String);
    return ActionResult.ok(
      performed ? 'Text entered' : 'Input did not succeed',
      {'performed': performed, 'elementId': element.id},
    );
  }
}

/// scroll_screen — scrolls the scrollable container.
class ScrollScreenTool extends NaraTool {
  ScrollScreenTool(this._accessibility);

  final AccessibilityPlatform _accessibility;

  @override
  String get name => 'scroll_screen';
  @override
  String get description => 'Scroll the current screen up or down.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'forward': ToolParam(type: ToolParamType.boolean, description: 'true = down, false = up', defaultValue: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final performed = await _accessibility.scroll(forward: (args['forward'] as bool?) ?? true);
    return ActionResult.ok(
      performed ? 'Scrolled' : 'Nothing to scroll',
      {'performed': performed},
    );
  }
}

/// get_device_information — model, OS version, battery, locale.
class DeviceInfoTool extends NaraTool {
  DeviceInfoTool(this._device);

  final DevicePlatform _device;

  @override
  String get name => 'get_device_information';
  @override
  String get description => 'Report device model, Android version and battery.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{};

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final info = await _device.getDeviceInfo();
    final battery = await _device.getBattery();
    return ActionResult.ok('Device information collected', {
      ...info,
      'batteryLevel': battery['level'],
      'batteryCharging': battery['charging'],
    });
  }
}

/// Shared memory of the most recent [ScreenContext] for follow-up actions.
class ScreenMemory {
  ScreenContext? _last;

  void remember(ScreenContext screen) => _last = screen;

  ScreenContext? get current => _last;

  ScreenElement? element(String id) {
    try {
      return _last?.interactiveElements.firstWhere((e) => e.id == id);
    } on StateError {
      return null;
    }
  }
}
