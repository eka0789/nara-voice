import '../../models/execution.dart';
import '../../platform/intents_platform.dart';
import '../nara_tool.dart';

/// share_text — opens the Android share sheet; the user controls the target.
class ShareTextTool extends NaraTool {
  ShareTextTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'share_text';
  @override
  String get description => 'Open the share sheet with a text payload.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'text': ToolParam(type: ToolParamType.string, description: 'Text to share', required: true),
        'title': ToolParam(type: ToolParamType.string, description: 'Chooser title'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.shareText(
      args['text'] as String,
      title: (args['title'] as String?) ?? 'NARA Voice',
    );
    if (!handoff.launched) {
      return ActionResult.failure('Share sheet did not open', 'NOT_RESOLVED');
    }
    // Honest boundary: the sheet is open; delivery is the user's action.
    return ActionResult.ok('Share sheet opened', {'handler': handoff.handler});
  }
}

/// compose_message — prepares (never sends) a chat message.
class ComposeMessageTool extends NaraTool {
  ComposeMessageTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'compose_message';
  @override
  String get description =>
      'Prepare a message in a messaging app (WhatsApp by default). '
      'With a phone number opens the direct chat draft; without one opens the '
      'WhatsApp share target so the user picks the conversation.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'text': ToolParam(type: ToolParamType.string, description: 'Message body', required: true),
        'phone': ToolParam(type: ToolParamType.string, description: 'Phone number in international digits'),
        'app': ToolParam(type: ToolParamType.string, description: 'whatsapp | telegram | sms'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final app = (args['app'] as String?) ?? 'whatsapp';
    final text = args['text'] as String;
    final phone = args['phone'] as String?;
    switch (app) {
      case 'whatsapp':
        final handoff = await _intents.composeWhatsApp(phone: phone, text: text);
        if (!handoff.launched) {
          return ActionResult.failure('WhatsApp is not available', 'NOT_RESOLVED');
        }
        return ActionResult.ok(
          'WhatsApp draft prepared — user must press send',
          {'handler': handoff.handler, 'mode': phone != null ? 'direct_chat' : 'share_target'},
        );
      case 'sms':
        // SMS compose through the default messaging app share sheet.
        final handoff = await _intents.shareText(text, title: 'SMS');
        return ActionResult.ok('SMS app opened via share sheet', {'handler': handoff.handler});
      case 'telegram':
        final handoff = await _intents.shareText(text, title: 'Telegram', packageName: 'org.telegram.messenger');
        return ActionResult.ok('Telegram share prepared', {'handler': handoff.handler});
      default:
        return ActionResult.failure('Unsupported messaging app: $app', 'UNSUPPORTED');
    }
  }
}

/// compose_email — prepares a draft in the user's email client.
class ComposeEmailTool extends NaraTool {
  ComposeEmailTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'compose_email';
  @override
  String get description => 'Prepare an email draft (recipient, subject, body).';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'to': ToolParam(type: ToolParamType.string, description: 'Recipient email'),
        'subject': ToolParam(type: ToolParamType.string, description: 'Email subject'),
        'body': ToolParam(type: ToolParamType.string, description: 'Email body', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.composeEmail(
      to: args['to'] as String?,
      subject: args['subject'] as String?,
      body: args['body'] as String,
    );
    if (!handoff.launched) {
      return ActionResult.failure('No email application available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Email draft prepared — user must review and send', {'handler': handoff.handler});
  }
}

/// open_maps — location search or navigation via public geo intents.
class OpenMapsTool extends NaraTool {
  OpenMapsTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'open_maps';
  @override
  String get description => 'Search a location or start directions in maps.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'query': ToolParam(type: ToolParamType.string, description: 'Place or destination'),
        'mode': ToolParam(type: ToolParamType.string, description: 'search | directions'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.openMaps(
      query: args['query'] as String?,
      mode: args['mode'] as String?,
    );
    if (!handoff.launched) {
      return ActionResult.failure('No maps application available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Maps opened', {'handler': handoff.handler});
  }
}

/// search_web — opens a browser search for a query.
class SearchWebTool extends NaraTool {
  SearchWebTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'search_web';
  @override
  String get description => 'Open a web search in the default browser.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'query': ToolParam(type: ToolParamType.string, description: 'Search query', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final query = Uri.encodeComponent(args['query'] as String);
    final handoff = await _intents.openUrl('https://www.google.com/search?q=$query');
    if (!handoff.launched) {
      return ActionResult.failure('No browser available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Browser opened with search results', {'handler': handoff.handler});
  }
}

/// youtube_search — YouTube app (or browser) search.
class YouTubeSearchTool extends NaraTool {
  YouTubeSearchTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'youtube_search';
  @override
  String get description => 'Search YouTube for a query.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'query': ToolParam(type: ToolParamType.string, description: 'Search query', required: true),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.openYouTubeSearch(args['query'] as String);
    if (!handoff.launched) {
      return ActionResult.failure('YouTube is not available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('YouTube search opened', {'handler': handoff.handler});
  }
}

/// open_spotify — app or web fallback.
class OpenSpotifyTool extends NaraTool {
  OpenSpotifyTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'open_spotify';
  @override
  String get description => 'Open Spotify, optionally searching for content.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'query': ToolParam(type: ToolParamType.string, description: 'Search query'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.openSpotify(query: args['query'] as String?);
    if (!handoff.launched) {
      return ActionResult.failure('Spotify is not available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Spotify opened', {'handler': handoff.handler});
  }
}

/// create_calendar_event — intent-based draft; the calendar app shows it
/// for the user to confirm and save (no calendar permission needed).
class CreateCalendarEventTool extends NaraTool {
  CreateCalendarEventTool(this._intents);

  final IntentsPlatform _intents;

  @override
  String get name => 'create_calendar_event';
  @override
  String get description => 'Open a pre-filled calendar event draft.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'title': ToolParam(type: ToolParamType.string, description: 'Event title', required: true),
        'description': ToolParam(type: ToolParamType.string, description: 'Event description'),
        'beginMillis': ToolParam(type: ToolParamType.integer, description: 'Start time in epoch millis'),
        'endMillis': ToolParam(type: ToolParamType.integer, description: 'End time in epoch millis'),
        'allDay': ToolParam(type: ToolParamType.boolean, description: 'All-day event'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.medium;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final handoff = await _intents.insertCalendarEvent(
      title: args['title'] as String,
      description: args['description'] as String?,
      beginMillis: args['beginMillis'] as int?,
      endMillis: args['endMillis'] as int?,
      allDay: (args['allDay'] as bool?) ?? false,
    );
    if (!handoff.launched) {
      return ActionResult.failure('No calendar application available', 'NOT_RESOLVED');
    }
    return ActionResult.ok('Calendar draft opened — user must save', {'handler': handoff.handler});
  }
}

/// open_device_settings — whitelisted settings screens only.
class OpenSettingsTool extends NaraTool {
  OpenSettingsTool(this._intents);

  final IntentsPlatform _intents;

  static const allowedScreens = <String>{
    'main', 'wifi', 'bluetooth', 'display', 'sound', 'battery',
    'accessibility', 'notifications', 'apps', 'security', 'locale',
    'date', 'storage', 'dataUsage', 'appDetails',
  };

  @override
  String get name => 'open_device_settings';
  @override
  String get description => 'Open a supported Android settings screen.';

  @override
  Map<String, ToolParam> get inputSchema => const <String, ToolParam>{
        'screen': ToolParam(type: ToolParamType.string, description: 'Settings screen key'),
        'packageName': ToolParam(type: ToolParamType.string, description: 'Package for appDetails'),
      };

  @override
  RiskLevel get riskLevel => RiskLevel.low;

  @override
  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context) async {
    final screen = (args['screen'] as String?) ?? 'main';
    if (!allowedScreens.contains(screen)) {
      return ActionResult.failure('Unsupported settings screen: $screen', 'UNSUPPORTED');
    }
    final handoff = await _intents.openSettings(screen, packageName: args['packageName'] as String?);
    if (!handoff.launched) {
      return ActionResult.failure('Could not open $screen settings', 'NOT_RESOLVED');
    }
    return ActionResult.ok('$screen settings opened', {'handler': handoff.handler});
  }
}
