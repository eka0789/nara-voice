import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/tools/nara_tool.dart';
import 'package:nara_voice/core/tools/tools/integration_tools.dart';
import 'package:nara_voice/core/platform/intents_platform.dart';

class RecordingIntents extends IntentsPlatform {
  RecordingIntents();
  List<String> calls = [];

  @override
  Future<IntentHandoff> shareText(String text, {String? title, String? packageName}) async {
    calls.add('share:$text');
    return const IntentHandoff(launched: true);
  }

  @override
  Future<IntentHandoff> composeWhatsApp({String? phone, String? text}) async {
    calls.add('wa:${phone ?? ''}:$text');
    return const IntentHandoff(launched: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('tool input validation', () {
    test('missing required argument fails validation', () async {
      final tool = ShareTextTool(RecordingIntents());
      final result = await runTool(tool, <String, Object?>{}, const ToolContext(locale: 'id'));
      expect(result.success, isFalse);
      expect(result.errorCode, 'VALIDATION');
    });

    test('wrong argument type fails validation', () async {
      final tool = ShareTextTool(RecordingIntents());
      final result = await runTool(
        tool,
        <String, Object?>{'text': 42},
        const ToolContext(locale: 'id'),
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'VALIDATION');
    });

    test('unknown arguments are rejected', () async {
      final tool = ShareTextTool(RecordingIntents());
      final result = await runTool(
        tool,
        <String, Object?>{'text': 'hi', 'shellCommand': 'rm -rf /'},
        const ToolContext(locale: 'id'),
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'VALIDATION');
    });

    test('valid arguments execute the handler once', () async {
      final intents = RecordingIntents();
      final tool = ShareTextTool(intents);
      final result = await runTool(
        tool,
        <String, Object?>{'text': 'hello world'},
        const ToolContext(locale: 'id'),
      );
      expect(result.success, isTrue);
      expect(intents.calls, ['share:hello world']);
    });
  });
}
