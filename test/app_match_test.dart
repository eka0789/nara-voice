import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/models/app_descriptor.dart';
import 'package:nara_voice/core/tools/tools/app_tools.dart';

AppDescriptor app(String name, String pkg) => AppDescriptor(
      appName: name,
      packageName: pkg,
      launchable: true,
      enabled: true,
      isSystem: false,
    );

void main() {
  group('fuzzy app matching', () {
    test('exact name scores highest', () {
      final score = SearchAppTool.scoreAppMatch(app('WhatsApp', 'com.whatsapp'), 'whatsapp');
      expect(score, 1.0);
    });

    test('prefix match scores high', () {
      final score = SearchAppTool.scoreAppMatch(app('YouTube', 'com.google.android.youtube'), 'you');
      expect(score, greaterThanOrEqualTo(0.9));
    });

    test('package tail matches', () {
      final score = SearchAppTool.scoreAppMatch(app('Music', 'com.spotify.music'), 'music');
      expect(score, greaterThanOrEqualTo(0.7));
    });

    test('multi-token query matches', () {
      final score = SearchAppTool.scoreAppMatch(app('Google Maps', 'com.google.android.apps.maps'), 'google maps');
      expect(score, greaterThanOrEqualTo(0.6));
    });

    test('unrelated query scores zero', () {
      final score = SearchAppTool.scoreAppMatch(app('Calculator', 'com.calc'), 'whatsapp');
      expect(score, 0);
    });
  });
}
