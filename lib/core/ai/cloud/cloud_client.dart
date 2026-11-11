import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// User-provided cloud AI configuration. The API key lives only in secure
/// storage — never in code, never in the repo.
class CloudAiConfig {
  const CloudAiConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    this.enabled = false,
  });

  final String endpoint; // e.g. https://api.openai.com/v1/chat/completions
  final String apiKey;
  final String model;
  final bool enabled;

  bool get isUsable => enabled && endpoint.startsWith('https://') && apiKey.isNotEmpty;

  static const defaultEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const defaultModel = 'gpt-4o-mini';
}

/// One planned action returned by the cloud model.
class CloudPlannedAction {
  const CloudPlannedAction({required this.toolName, required this.args});
  final String toolName;
  final Map<String, Object?> args;
}

/// The cloud model either plans tool calls or answers conversationally.
sealed class CloudReply {
  const CloudReply();
}

class CloudPlan extends CloudReply {
  const CloudPlan(this.actions);
  final List<CloudPlannedAction> actions;
}

class CloudAnswer extends CloudReply {
  const CloudAnswer(this.text);
  final String text;
}

/// OpenAI-compatible function-calling client. All failures return null so the
/// orchestrator can fall back to the offline NLU without user-visible errors.
class CloudAiClient {
  CloudAiClient({http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 15);

  final http.Client _client;
  final Duration _timeout;

  static const _systemPrompt = '''
You are NARA, a voice assistant on the user's Android phone.
Rules:
- Use ONLY the provided tools to act. Never invent tools or app features.
- Prefer one tool call per concrete user request; split compound requests ("A and then B") into sequential calls.
- For messages and emails: compose only. You never send on the user's behalf.
- If the request is ambiguous, reply with one short clarifying question in the user's language (Indonesian or English).
- If no tool fits, reply with a short honest answer in the user's language.
''';

  Future<CloudReply?> request({
    required String transcript,
    required String locale,
    required List<Map<String, String>> history,
    required List<Map<String, Object?>> tools,
  }) async {
    try {
      final body = jsonEncode(<String, Object?>{
        'model': _model,
        'messages': <Object?>[
          <String, String>{'role': 'system', 'content': _systemPrompt},
          ...history,
          <String, String>{'role': 'user', 'content': transcript},
        ],
        'tools': tools,
        'tool_choice': 'auto',
        'temperature': 0.2,
      });
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: body,
          )
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) return null;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final message = (choices.first as Map)['message'];
      if (message is! Map) return null;

      final toolCalls = message['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        final actions = <CloudPlannedAction>[];
        for (final call in toolCalls.whereType<Map>()) {
          final function = call['function'];
          if (function is! Map) continue;
          final name = function['name'];
          final rawArgs = function['arguments'];
          if (name is! String) continue;
          final args = rawArgs is String
              ? (jsonDecode(rawArgs) as Map?)?.cast<String, Object?>() ?? <String, Object?>{}
              : (rawArgs as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
          actions.add(CloudPlannedAction(toolName: name, args: args));
        }
        if (actions.isNotEmpty) return CloudPlan(actions);
        return null;
      }
      final content = message['content'];
      if (content is String && content.trim().isNotEmpty) {
        return CloudAnswer(content.trim());
      }
      return null;
    } on TimeoutException {
      return null;
    } catch (e) {
      return null;
    }
  }

  // Bound at construction time by the settings provider.
  String get _endpoint => _config.endpoint;
  String get _apiKey => _config.apiKey;
  String get _model => _config.model;
  CloudAiConfig _config = const CloudAiConfig(
    endpoint: CloudAiConfig.defaultEndpoint,
    apiKey: '',
    model: CloudAiConfig.defaultModel,
  );

  void configure(CloudAiConfig config) => _config = config;

  void dispose() => _client.close();
}
