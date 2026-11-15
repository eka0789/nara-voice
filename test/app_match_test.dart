import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/models/app_descriptor.dart';
import 'package:nara_voice/core/tools/tools/app_tools.dart';
import 'package:nara_voice/core/tools/tools/universal_tools.dart';

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

  group('tap-by-label element matching', () {
    test('exact label scores highest', () {
      expect(TapByLabelTool.labelMatchScore('play', 'play'), 1.0);
    });

    test('word-boundary containment scores high', () {
      expect(TapByLabelTool.labelMatchScore('play store', 'play'), 0.9);
    });

    test('substring scores mid', () {
      expect(TapByLabelTool.labelMatchScore('replay video', 'play'), 0.7);
    });

    test('all query tokens found scores lower but matches', () {
      // "tombol play musik" contains the whole query "play musik" at a word
      // boundary, which scores 0.9 — the token-fallback (0.6) only applies
      // when the tokens are scattered.
      expect(TapByLabelTool.labelMatchScore('tombol play musik', 'play musik'), 0.9);
      expect(TapByLabelTool.labelMatchScore('putar musik tombol play', 'play musik'), 0.6);
    });

    test('unrelated label does not match', () {
      expect(TapByLabelTool.labelMatchScore('settings', 'play'), 0);
    });
  });
}
