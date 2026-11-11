import '../../models/app_descriptor.dart';
import '../../models/execution.dart';
import '../../platform/apps_platform.dart';
import '../../platform/intents_platform.dart';
import '../nara_tool.dart';

/// discover_installed_apps — lists launchable, enabled applications.
class DiscoverAppsTool extends NaraTool {
  DiscoverAppsTool(this._apps);

  final AppsPlatform _apps;

  @override
  String get name => 'discover_installed_apps';
  @override
  String get description => 'List launchable installed applications.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'limit': ToolParam(type: ToolParamType.integer, description: 'Max apps returned', defaultValue: 200),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final apps = await _apps.getInstalledApps();
    final launchable = apps.where((a) => a.launchable && a.enabled).toList();
    final limit = (args['limit'] as int?) ?? 200;
    return ActionResult.ok(
      'Found ${launchable.length} launchable apps',
      {
        'apps': launchable
            .take(limit)
            .map((a) => {'appName': a.appName, 'packageName': a.packageName})
            .toList(),
        'total': launchable.length,
      },
    );
  }
}

/// search_installed_app — fuzzy search over the local app catalog.
class SearchAppTool extends NaraTool {
  SearchAppTool(this._catalog);

  final Future<List<AppDescriptor>> Function() _catalog;

  @override
  String get name => 'search_installed_app';
  @override
  String get description => 'Search the installed-app catalog by name or package.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'query': ToolParam(type: ToolParamType.string, description: 'Search text', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final query = (args['query'] as String).trim().toLowerCase();
    final apps = await _catalog();
    final matches = apps
        .where((a) => a.launchable && a.enabled)
        .map((a) => (app: a, score: scoreAppMatch(a, query)))
        .where((m) => m.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ActionResult.ok(
      matches.isEmpty ? 'No app matches "$query"' : 'Found ${matches.length} matches for "$query"',
      {
        'query': query,
        'matches': matches
            .take(5)
            .map((m) => {'appName': m.app.appName, 'packageName': m.app.packageName, 'score': m.score})
            .toList(),
      },
    );
  }

  /// Token-containment scoring shared with the NLU. >0 means a match.
  static double scoreAppMatch(AppDescriptor app, String query) {
    final name = app.appName.toLowerCase();
    final pkgTail = app.packageName.split('.').last.toLowerCase();
    if (name == query || pkgTail == query) return 1.0;
    if (name.startsWith(query)) return 0.9;
    if (name.contains(' $query') || name.contains(query)) return 0.8;
    if (pkgTail.contains(query)) return 0.7;
    final queryTokens = query.split(RegExp(r'\s+'));
    final nameTokens = name.split(RegExp(r'\s+'));
    var hits = 0;
    for (final qt in queryTokens) {
      for (final nt in nameTokens) {
        if (nt.startsWith(qt) || qt.startsWith(nt)) {
          hits++;
          break;
        }
      }
    }
    if (hits == queryTokens.length) return 0.6;
    return 0;
  }
}

/// open_application — launches an app by package, honest about handoff.
class OpenAppTool extends NaraTool {
  OpenAppTool(this._apps);

  final AppsPlatform _apps;

  @override
  String get name => 'open_application';
  @override
  String get description => 'Launch an installed application by package name.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'packageName': ToolParam(type: ToolParamType.string, description: 'Target package', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final packageName = args['packageName'] as String;
    final launched = await _apps.launchApp(packageName);
    if (!launched) {
      return ActionResult.failure('Android refused to launch $packageName', 'LAUNCH_FAILED');
    }
    return ActionResult.ok('Handed off to $packageName', {'packageName': packageName});
  }
}

/// open_app_details — opens the system page for a single app.
class OpenAppDetailsTool extends NaraTool {
  OpenAppDetailsTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'open_app_details';
  @override
  String get description => 'Open Android settings page for an application.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'packageName': ToolParam(type: ToolParamType.string, description: 'Target package', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.openAppDetails(args['packageName'] as String);
    return ActionResult.ok(
      handoff.launched ? 'App settings opened' : 'Could not open app settings',
      {'handler': handoff.handler},
    );
  }
}
