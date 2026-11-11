import '../models/app_descriptor.dart';
import '../models/execution.dart';
import '../platform/accessibility_platform.dart';
import '../platform/apps_platform.dart';
import '../platform/device_platform.dart';
import '../platform/intents_platform.dart';
import '../platform/notifications_platform.dart';
import 'nara_tool.dart';
import 'tools/app_tools.dart';
import 'tools/integration_tools.dart';
import 'tools/notification_tools.dart';
import 'tools/screen_tools.dart';

/// Wires every concrete tool to its platform bridge and provides lookup.
class ToolRegistry {
  ToolRegistry._(this.screenMemory, this._tools);

  factory ToolRegistry({
    required AppsPlatform apps,
    required IntentsPlatform intents,
    required AccessibilityPlatform accessibility,
    required NotificationsPlatform notifications,
    required DevicePlatform device,
    required Future<List<AppDescriptor>> Function() catalogSource,
  }) {
    final screenMemory = ScreenMemory();
    final tools = <String, NaraTool>{
      DiscoverAppsTool(apps).name: DiscoverAppsTool(apps),
      SearchAppTool(catalogSource).name: SearchAppTool(catalogSource),
      OpenAppTool(apps).name: OpenAppTool(apps),
      OpenAppDetailsTool(intents).name: OpenAppDetailsTool(intents),
      ShareTextTool(intents).name: ShareTextTool(intents),
      ComposeMessageTool(intents).name: ComposeMessageTool(intents),
      ComposeEmailTool(intents).name: ComposeEmailTool(intents),
      OpenMapsTool(intents).name: OpenMapsTool(intents),
      SearchWebTool(intents).name: SearchWebTool(intents),
      YouTubeSearchTool(intents).name: YouTubeSearchTool(intents),
      OpenSpotifyTool(intents).name: OpenSpotifyTool(intents),
      CreateCalendarEventTool(intents).name: CreateCalendarEventTool(intents),
      OpenSettingsTool(intents).name: OpenSettingsTool(intents),
      InspectScreenTool(accessibility, screenMemory).name: InspectScreenTool(accessibility, screenMemory),
      GetActiveAppTool(accessibility).name: GetActiveAppTool(accessibility),
      TapElementTool(accessibility, screenMemory).name: TapElementTool(accessibility, screenMemory),
      InputTextTool(accessibility, screenMemory).name: InputTextTool(accessibility, screenMemory),
      ScrollScreenTool(accessibility).name: ScrollScreenTool(accessibility),
      DeviceInfoTool(device).name: DeviceInfoTool(device),
      NotificationContextTool(notifications).name: NotificationContextTool(notifications),
    };
    return ToolRegistry._(screenMemory, tools);
  }

  final ScreenMemory screenMemory;
  final Map<String, NaraTool> _tools;

  NaraTool? lookup(String name) => _tools[name];

  Iterable<NaraTool> get all => _tools.values;

  /// JSON-schema style descriptors for the cloud function-calling adapter.
  List<Map<String, Object?>> describeForCloud() => all
      .map((tool) => <String, Object?>{
            'type': 'function',
            'function': <String, Object?>{
              'name': tool.name,
              'description': tool.description,
              'parameters': <String, Object?>{
                'type': 'object',
                'properties': tool.inputSchema.map(
                  (key, param) => MapEntry(key, <String, Object?>{
                    'type': param.type.name,
                    'description': param.description,
                  }),
                ),
                'required': tool.inputSchema.entries
                    .where((e) => e.value.required)
                    .map((e) => e.key)
                    .toList(),
              },
            },
          })
      .toList(growable: false);

  /// Executes a tool by name with full validation + timeout handling.
  Future<ActionResult> execute(
    String toolName,
    Map<String, Object?> args,
    ToolContext context,
  ) async {
    final tool = lookup(toolName);
    if (tool == null) {
      return ActionResult.failure('Unknown tool: $toolName', 'UNKNOWN_TOOL');
    }
    return runTool(tool, args, context);
  }
}
