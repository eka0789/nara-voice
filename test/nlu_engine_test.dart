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

  group('universal control (any app via accessibility)', () {
    test('tap a visible control', () {
      final outcome = nlu.parse('tekan tombol play') as NluPlan;
      expect(outcome.drafts.single.tool, 'tap_by_label');
      expect(outcome.drafts.single.args['label'], 'tombol play');
    });

    test('tap strips the trailing target app', () {
      final outcome = nlu.parse('tekan play di spotify') as NluPlan;
      expect(outcome.drafts.single.tool, 'tap_by_label');
      expect(outcome.drafts.single.args['label'], 'play');
    });

    test('tap inside a compound command routes to the opened app context', () {
      final outcome = nlu.parse('buka spotify dan tekan play') as NluPlan;
      expect(outcome.drafts.length, 2);
      // "buka spotify" resolves through the Spotify integration matcher
      // (same as "buka spotify lalu putar jazz" in the compound group).
      expect(outcome.drafts[0].tool, 'open_spotify');
      expect(outcome.drafts[1].tool, 'tap_by_label');
      expect(outcome.drafts[1].args['label'], 'play');
    });

    test('english tap', () {
      final outcome = nlu.parse('tap the search button') as NluPlan;
      expect(outcome.drafts.single.tool, 'tap_by_label');
      expect(outcome.drafts.single.args['label'], contains('search'));
    });

    test('type into focused field', () {
      final outcome = nlu.parse('ketik halo dunia') as NluPlan;
      expect(outcome.drafts.single.tool, 'type_text');
      expect(outcome.drafts.single.args['value'], 'halo dunia');
    });

    test('system navigation: back, home, recents, shade', () {
      expect((nlu.parse('kembali') as NluPlan).drafts.single.tool, 'go_back');
      expect((nlu.parse('pulang') as NluPlan).drafts.single.tool, 'go_home');
      expect((nlu.parse('aplikasi terbaru') as NluPlan).drafts.single.tool, 'open_recents');
      expect(
        (nlu.parse('tarik notifikasi') as NluPlan).drafts.single.tool,
        'open_notification_shade',
      );
      expect(
        (nlu.parse('buka panel notifikasi') as NluPlan).drafts.single.tool,
        'open_notification_shade',
      );
    });

    test('navigation with a target goes to the app, not the system action', () {
      final outcome = nlu.parse('kembali ke youtube') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_application');
    });

    test('screenshot beats screen understanding', () {
      final outcome = nlu.parse('screenshot layar ini') as NluPlan;
      expect(outcome.drafts.single.tool, 'take_screenshot');
    });

    test('volume up, down, mute', () {
      final up = nlu.parse('naikkan volume') as NluPlan;
      expect(up.drafts.single.tool, 'volume_control');
      expect(up.drafts.single.args['action'], 'up');

      final down = nlu.parse('kecilkan suara') as NluPlan;
      expect(down.drafts.single.tool, 'volume_control');
      expect(down.drafts.single.args['action'], 'down');

      final mute = nlu.parse('bisukan volume') as NluPlan;
      expect(mute.drafts.single.tool, 'volume_control');
      expect(mute.drafts.single.args['action'], 'mute');
    });

    test('sound settings are not hijacked by volume control', () {
      final outcome = nlu.parse('buka pengaturan suara') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_device_settings');
      expect(outcome.drafts.single.args['screen'], 'sound');
    });

    test('flashlight on and off', () {
      final on = nlu.parse('nyalakan senter') as NluPlan;
      expect(on.drafts.single.tool, 'toggle_flashlight');
      expect(on.drafts.single.args['on'], true);

      final off = nlu.parse('matikan senter') as NluPlan;
      expect(off.drafts.single.tool, 'toggle_flashlight');
      expect(off.drafts.single.args['on'], false);
    });

    test('dial with number is prepare-only', () {
      final outcome = nlu.parse('telepon 081234567890') as NluPlan;
      expect(outcome.drafts.single.tool, 'dial_number');
      expect(outcome.drafts.single.args['number'], '081234567890');
      expect(outcome.drafts.single.risk.index, 1); // medium
    });

    test('dial without number asks for it, then slot fills', () {
      final first = nlu.parse('panggil ibu') as NluClarify;
      expect(first.questionKey, ResponseKey.clarifyPhoneNumber);
      final second = nlu.parse('081234567890', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'dial_number');
    });

    test('alarm with time', () {
      final outcome = nlu.parse('pasang alarm jam 6') as NluPlan;
      expect(outcome.drafts.single.tool, 'set_alarm');
      expect(outcome.drafts.single.args['hour'], 6);
      expect(outcome.drafts.single.args['minute'], 0);
    });

    test('alarm evening shifts to 24h clock', () {
      final outcome = nlu.parse('pasang alarm jam 9 malam') as NluPlan;
      expect(outcome.drafts.single.args['hour'], 21);
    });

    test('alarm without time asks, then slot fills', () {
      final first = nlu.parse('pasang alarm') as NluClarify;
      expect(first.questionKey, ResponseKey.clarifyAlarmTime);
      final second = nlu.parse('jam 7', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'set_alarm');
      expect(second.drafts.single.args['hour'], 7);
    });

    test('timer with duration', () {
      final outcome = nlu.parse('atur timer 10 menit') as NluPlan;
      expect(outcome.drafts.single.tool, 'set_timer');
      expect(outcome.drafts.single.args['seconds'], 600);
    });

    test('timer without duration asks, then slot fills', () {
      final first = nlu.parse('pasang timer') as NluClarify;
      expect(first.questionKey, ResponseKey.clarifyTimerDuration);
      final second = nlu.parse('5 menit', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'set_timer');
      expect(second.drafts.single.args['seconds'], 300);
    });

    test('a fresh command cancels pending universal slots', () {
      final first = nlu.parse('pasang alarm') as NluClarify;
      final second = nlu.parse('buka youtube', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'open_application');
    });
  });

  group('brightness control', () {
    test('absolute level', () {
      final outcome = nlu.parse('kecerahan 50') as NluPlan;
      expect(outcome.drafts.single.tool, 'set_brightness');
      expect(outcome.drafts.single.args['level'], 50);
    });

    test('relative brighten and dim', () {
      final up = nlu.parse('naikkan kecerahan') as NluPlan;
      expect(up.drafts.single.args['delta'], 30);
      final down = nlu.parse('gelapkan layar') as NluPlan;
      expect(down.drafts.single.args['delta'], -30);
    });

    test('full and minimum', () {
      final full = nlu.parse('kecerahan penuh') as NluPlan;
      expect(full.drafts.single.args['level'], 100);
      final low = nlu.parse('kecerahan minimum') as NluPlan;
      expect(low.drafts.single.args['level'], 20);
    });

    test('brightness settings screen is not hijacked', () {
      final outcome = nlu.parse('buka pengaturan kecerahan') as NluPlan;
      expect(outcome.drafts.single.tool, 'open_device_settings');
      expect(outcome.drafts.single.args['screen'], 'display');
    });

    test('calendar requests still go to the calendar', () {
      final outcome = nlu.parse('jadwalkan rapat besok jam 3') as NluPlan;
      expect(outcome.drafts.single.tool, 'create_calendar_event');
    });
  });

  group('scheduled routines', () {
    test('routine with time and command in one sentence', () {
      final outcome = nlu.parse('pasang rutin jam 7 buka youtube') as NluPlan;
      expect(outcome.drafts.single.tool, 'create_routine');
      expect(outcome.drafts.single.args['hour'], 7);
      expect(outcome.drafts.single.args['command'], 'buka youtube');
    });

    test('command before time also parses', () {
      final outcome = nlu.parse('pasang rutin buka youtube jam 7') as NluPlan;
      expect(outcome.drafts.single.tool, 'create_routine');
      expect(outcome.drafts.single.args['hour'], 7);
      expect(outcome.drafts.single.args['command'], 'buka youtube');
    });

    test('missing time asks for it, then slot fills', () {
      final first = nlu.parse('pasang rutin buka youtube') as NluClarify;
      expect(first.questionKey, ResponseKey.clarifyRoutineTime);
      final second = nlu.parse('jam 8', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'create_routine');
      expect(second.drafts.single.args['hour'], 8);
      expect(second.drafts.single.args['command'], 'buka youtube');
    });

    test('missing command asks for it, then slot fills', () {
      final first = nlu.parse('pasang rutin jam 6') as NluClarify;
      expect(first.questionKey, ResponseKey.clarifyRoutineCommand);
      final second = nlu.parse('buka whatsapp', pending: first.pending) as NluPlan;
      expect(second.drafts.single.tool, 'create_routine');
      expect(second.drafts.single.args['hour'], 6);
      expect(second.drafts.single.args['command'], 'buka whatsapp');
    });

    test('plain schedule requests stay calendar routines', () {
      final outcome = nlu.parse('jadwalkan rapat besok jam 3') as NluPlan;
      expect(outcome.drafts.single.tool, 'create_calendar_event');
    });
  });
}
