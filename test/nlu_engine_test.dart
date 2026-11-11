import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/ai/nlu/nlu_engine.dart';
import 'package:nara_voice/core/ai/response_keys.dart';

/// Deterministic app lookup for tests: registry names only.
(String, double)? fakeLookup(String query) {
  final q = query.trim().toLowerCase();
  const registry = <String, String>{
    'whatsapp': 'com.whatsapp',
    'wa': 'com.whatsapp',
    'youtube': 'com.google.android.youtube',
    'spotify': 'com.spotify.music',
    'chrome': 'com.android.chrome',
  };
  final pkg = registry[q];
  return pkg == null ? null : (pkg, 1.0);
}

void main() {
  late NluEngine nlu;

  setUp(() {
    nlu = NluEngine(appLookup: fakeLookup);
  });

  group('Indonesian commands', () {
    test('open app', () {
      final outcome = nlu.parse('buka whatsapp') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_application');
      expect(outcome.drafts.single.args['packageName'], 'com.whatsapp');
      expect(outcome.language, 'id');
    });

    test('open app with politeness fillers', () {
      final outcome = nlu.parse('tolong buka whatsapp ya dong') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_application');
    });

    test('wifi settings', () {
      final outcome = nlu.parse('buka pengaturan wifi') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_device_settings');
      expect(outcome.drafts.single.args['screen'], 'wifi');
    });

    test('maps navigation', () {
      final outcome = nlu.parse('navigasi ke rumah sakit terdekat') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_maps');
      expect(outcome.drafts.single.args['mode'], 'directions');
      expect(outcome.drafts.single.args['query'], contains('rumah sakit'));
    });

    test('youtube search', () {
      final outcome = nlu.parse('cari tutorial flutter di youtube') as NluPlan;
      expect(outcome.drafts.single.tool, 'youtube_search');
    });

    test('web search', () {
      final outcome = nlu.parse('cari berita hari ini') as NluPlan;
      expect(outcome.drafts.single.tool, 'search_web');
      expect(outcome.drafts.single.args['query'], contains('berita'));
    });

    test('compose message asks for content when missing', () {
      final outcome = nlu.parse('kirim pesan whatsapp') as NluClarify;
      expect(outcome.questionKey, ResponseKey.clarifyMessageContent);
      expect(outcome.pending.intent, 'compose_message');
    });

    test('compose message with content', () {
      final outcome = nlu.parse('siapkan pesan whatsapp isi saya akan terlambat') as NluPlan;
      expect(outcome.drafts.single.tool, 'compose_message');
      expect(outcome.drafts.single.args['text'], contains('terlambat'));
    });

    test('direct whatsapp message to phone is HIGH risk', () {
      final outcome = nlu.parse('kirim pesan whatsapp ke 081234567890 isi halo') as NluPlan;
      expect(outcome.drafts.single.args['phone'], '081234567890');
      expect(outcome.drafts.single.risk.index, greaterThanOrEqualTo(2)); // high
    });

    test('compose email with body', () {
      final outcome =
          nlu.parse('siapkan email ke budi@contoh.com subjek rapat isi sampai jumpa besok') as NluPlan;
      expect(outcome.drafts.single.tool, 'compose_email');
      expect(outcome.drafts.single.args['to'], 'budi@contoh.com');
      expect(outcome.drafts.single.args['body'], contains('sampai jumpa'));
    });

    test('calendar draft with tomorrow 3pm', () {
      final outcome = nlu.parse('jadwalkan rapat besok jam 3') as NluPlan;
      expect(outcome.drafts.single.tool, 'create_calendar_event');
      final begin = DateTime.fromMillisecondsSinceEpoch(
        outcome.drafts.single.args['beginMillis'] as int,
      );
      expect(begin.hour, 15);
      final now = DateTime.now();
      expect(begin.day, now.day + 1);
    });

    test('unknown command asks for clarification (never guesses)', () {
      final outcome = nlu.parse('asdkjhasd kajshdkajshd') as NluClarify;
      expect(outcome.questionKey, ResponseKey.clarifyUnknown);
    });
  });

  group('English commands', () {
    test('open app', () {
      final outcome = nlu.parse('open whatsapp') as NluPlan;
      expect(outcome.drafts.single.args['packageName'], 'com.whatsapp');
      expect(outcome.language, 'en');
    });

    test('search youtube', () {
      final outcome = nlu.parse('search youtube for flutter tutorial') as NluPlan;
      expect(outcome.drafts.single.tool, 'youtube_search');
    });

    test('settings screen', () {
      final outcome = nlu.parse('open bluetooth settings') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_device_settings');
      expect(outcome.drafts.single.args['screen'], 'bluetooth');
    });

    test('help answer', () {
      final outcome = nlu.parse('what can you do') as NluAnswer;
      expect(outcome.answerKey, ResponseKey.answerHelp);
    });
  });

  group('compound commands (multi-step)', () {
    test('open youtube and search flutter', () {
      final outcome = nlu.parse('buka youtube dan cari tutorial flutter') as NluPlan;
      expect(outcome.drafts.length, 2);
      expect(outcome.drafts[0].tool, 'open_application');
      expect(outcome.drafts[1].tool, 'youtube_search');
    });

    test('sequential with lalu', () {
      final outcome = nlu.parse('buka spotify lalu putar jazz') as NluPlan;
      expect(outcome.drafts.length, 2);
      expect(outcome.drafts[1].tool, 'open_spotify');
    });
  });

  group('slot filling', () {
    test('message content answered later completes the plan', () {
      final first = nlu.parse('kirim pesan whatsapp') as NluClarify;
      final second = nlu.parse('saya sudah sampai rumah', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'compose_message');
      expect(second.drafts.single.args['text'], contains('sampai rumah'));
    });

    test('a fresh command cancels the pending slot', () {
      final first = nlu.parse('kirim pesan whatsapp') as NluClarify;
      final second = nlu.parse('buka youtube', pending: first.pending);
      expect(second, isA<NluPlan>());
      expect((second as NluPlan).drafts.single.tool, 'open_application');
    });
  });
}
