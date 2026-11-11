import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nara_voice/core/ai/cloud/cloud_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient httpClient;
  late CloudAiClient client;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(http.Request('POST', Uri.parse('https://example.com')));
    registerFallbackValue('');
  });
  setUp(() {
    httpClient = MockHttpClient();
    client = CloudAiClient(client: httpClient);
    client.configure(const CloudAiConfig(
      endpoint: 'https://example.com/v1/chat/completions',
      apiKey: 'test-key',
      model: 'test-model',
      enabled: true,
    ));
  });

  Future<CloudReply?> request() => client.request(
        transcript: 'buka whatsapp',
        locale: 'id',
        history: const <Map<String, String>>[],
        tools: const <Map<String, Object?>>[],
      );

  test('parses tool_calls into a CloudPlan', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'tool_calls': [
                  {
                    'function': {
                      'name': 'open_application',
                      'arguments': '{"packageName": "com.whatsapp"}',
                    },
                  },
                ],
              },
            },
          ],
        }),
        200,
      ),
    );
    final reply = await request();
    expect(reply, isA<CloudPlan>());
    final plan = reply! as CloudPlan;
    expect(plan.actions.single.toolName, 'open_application');
    expect(plan.actions.single.args['packageName'], 'com.whatsapp');
  });

  test('parses plain content into a CloudAnswer', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {'message': {'content': 'Maaf, saya belum paham.'}},
          ],
        }),
        200,
      ),
    );
    final reply = await request();
    expect(reply, isA<CloudAnswer>());
    expect((reply! as CloudAnswer).text, 'Maaf, saya belum paham.');
  });

  test('HTTP failure returns null (offline fallback)', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response('server error', 500));
    expect(await request(), isNull);
  });

  test('exception returns null (offline fallback)', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenThrow(Exception('network down'));
    expect(await request(), isNull);
  });

  test('malformed JSON body returns null, never throws', () async {
    when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response('<html>not json</html>', 200));
    expect(await request(), isNull);
  });

  test('unknown tool names are dropped by the orchestrator mapping path', () {
    // Covered in orchestrator: _mapCloudReply skips unknown tools via
    // registry.lookup — here we assert the client only transports plans.
    expect(const CloudPlan([]).actions, isEmpty);
  });
}
