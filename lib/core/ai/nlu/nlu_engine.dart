import '../../models/execution.dart';
import '../response_keys.dart';
import 'text_normalizer.dart';

/// A single parsed action draft before tool execution.
class ActionDraft {
  ActionDraft({
    required this.tool,
    required this.args,
    required this.summaryKey,
    this.summaryArgs = const <String, String>{},
    RiskLevel? risk,
  }) : risk = risk ?? RiskLevel.low;

  final String tool;
  final Map<String, Object?> args;
  final ResponseKey summaryKey;
  final Map<String, String> summaryArgs;
  final RiskLevel risk;
}

/// What the NLU decided for one utterance.
sealed class NluOutcome {
  NluOutcome({required this.language});
  final String language;
}

/// A ready-to-execute (or confirmation-gated) plan.
class NluPlan extends NluOutcome {
  NluPlan({required this.drafts, required super.language});
  final List<ActionDraft> drafts;
}

/// The assistant must ask a question before it can proceed.
class NluClarify extends NluOutcome {
  NluClarify({
    required this.questionKey,
    required this.pending,
    this.partialDrafts = const <ActionDraft>[],
    required super.language,
  });

  final ResponseKey questionKey;

  /// Slot-filling state to keep until the user answers.
  final PendingSlot pending;
  final List<ActionDraft> partialDrafts;
}

/// A direct conversational answer that needs no tool.
class NluAnswer extends NluOutcome {
  NluAnswer({
    required this.answerKey,
    this.answerArgs = const <String, String>{},
    required super.language,
  });

  final ResponseKey answerKey;
  final Map<String, String> answerArgs;
}

/// Slot-filling state persisted in the session context.
class PendingSlot {
  PendingSlot({
    required this.intent,
    required this.questionKey,
    this.args = const <String, Object?>{},
    this.expiresAt,
  });

  final String intent; // compose_message | compose_email | open_app | compose_share
  final ResponseKey questionKey;
  final Map<String, Object?> args;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Internal per-segment parse results.
sealed class _SegmentResult {
  const _SegmentResult();
}

class _Draft extends _SegmentResult {
  const _Draft(this.draft);
  final ActionDraft draft;
}

class _Clarify extends _SegmentResult {
  const _Clarify(this.questionKey, this.pending);
  final ResponseKey questionKey;
  final PendingSlot pending;
}

class _None extends _SegmentResult {
  const _None();
}

/// Deterministic offline NLU for Indonesian and English commands.
/// Ambiguity never guesses: it returns [NluClarify] so the orchestrator asks.
class NluEngine {
  NluEngine({required this.appLookup});

  /// Resolves a free-text app name against registry + live catalog.
  /// Returns (packageName, score), or null when nothing matches.
  final (String packageName, double score)? Function(String query) appLookup;

  static final _emailRegex =
      RegExp(r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}');
  static final _phoneRegex = RegExp(r'\+?\d[\d\s\-]{7,}\d');

  NluOutcome parse(String transcript, {PendingSlot? pending}) {
    final language = TextNormalizer.detectLanguage(transcript);

    // 1. Slot filling for a pending question.
    if (pending != null && !pending.isExpired) {
      final fromSlot = _fillSlot(transcript, pending, language);
      if (fromSlot != null) return fromSlot;
    }

    final normalized = TextNormalizer.normalize(transcript);
    if (normalized.isEmpty) {
      return _clarifyUnknown(language);
    }
    // Help patterns are checked on the raw text too — normalization strips
    // fillers like "can you" that are part of the phrase itself.
    final rawLower = transcript.toLowerCase();
    if (_hasAny(rawLower, const ['apa yang bisa', 'what can you do', 'bantuan', 'fitur']) ||
        normalized.contains('help')) {
      return NluAnswer(answerKey: ResponseKey.answerHelp, language: language);
    }

    // 2. Compound commands → one step per segment, with app context carried
    // forward ("buka youtube dan cari X" → the search happens in YouTube).
    final segments = TextNormalizer.splitSegments(normalized);
    final drafts = <ActionDraft>[];
    String? appContext; // package name opened by a previous segment
    for (final segment in segments) {
      final result = _parseSegment(segment, language, appContext);
      switch (result) {
        case _Draft(:final draft):
          drafts.add(draft);
          appContext = switch (draft.tool) {
            'open_application' => draft.args['packageName'] as String?,
            'youtube_search' => 'com.google.android.youtube',
            'open_spotify' => 'com.spotify.music',
            'open_maps' => 'com.google.android.apps.maps',
            _ => appContext,
          };
        case _Clarify(questionKey: final key, pending: final pendingSlot):
          return NluClarify(
            questionKey: key,
            pending: pendingSlot,
            partialDrafts: List.of(drafts),
            language: language,
          );
        case _None():
          // In a compound command, skip unmatched fragments; a lone
          // unmatched segment means NARA must ask what the user meant.
          if (segments.length == 1) return _clarifyUnknown(language);
      }
    }
    if (drafts.isEmpty) return _clarifyUnknown(language);
    return NluPlan(drafts: drafts, language: language);
  }

  NluClarify _clarifyUnknown(String language) => NluClarify(
        questionKey: ResponseKey.clarifyUnknown,
        pending: PendingSlot(
          intent: 'none',
          questionKey: ResponseKey.clarifyUnknown,
          expiresAt: DateTime.now().add(const Duration(minutes: 1)),
        ),
        language: language,
      );

  // ===== Slot filling =====

  NluOutcome? _fillSlot(String transcript, PendingSlot pending, String language) {
    final normalized = TextNormalizer.normalize(transcript);
    // A fresh full command cancels slot filling — EXCEPT for routine
    // commands, where "buka youtube" is a likely scheduled action, not a
    // command to run right now.
    if (pending.intent != 'create_routine' &&
        _hasAny(normalized, const ['buka ', 'open ', 'kirim ', 'cari ', 'search ', 'send '])) {
      return null;
    }
    final args = Map<String, Object?>.from(pending.args);
    final value = _cleanSlotValue(transcript);
    switch (pending.intent) {
      case 'compose_message':
        args['text'] = value;
        return _segmentToOutcome(_messageOutcome(args, language), language);
      case 'compose_email':
        final email = _emailRegex.firstMatch(normalized)?.group(0);
        if (email != null) args['to'] = email;
        args['body'] = value;
        return _segmentToOutcome(_emailOutcome(args, language), language);
      case 'open_app':
        final lookup = appLookup(value);
        if (lookup != null && lookup.$2 >= 0.6) {
          return NluPlan(
            drafts: [
              ActionDraft(
                tool: 'open_application',
                args: {'packageName': lookup.$1},
                summaryKey: ResponseKey.summaryOpenApp,
                summaryArgs: {'app': value},
              ),
            ],
            language: language,
          );
        }
        return NluClarify(
          questionKey: ResponseKey.clarifyAppNotFound,
          pending: PendingSlot(
            intent: 'open_app',
            questionKey: ResponseKey.clarifyAppNotFound,
            args: args,
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
          ),
          language: language,
        );
      case 'compose_share':
        args['text'] = value;
        return NluPlan(
          drafts: [
            ActionDraft(
              tool: 'share_text',
              args: args,
              risk: RiskLevel.medium,
              summaryKey: ResponseKey.summaryShare,
            ),
          ],
          language: language,
        );
      case 'dial_number':
        final phone = _phoneRegex
            .firstMatch(normalized)
            ?.group(0)
            ?.replaceAll(RegExp(r'[\s\-]'), '');
        if (phone != null && phone.length >= 6) {
          return NluPlan(
            drafts: [
              ActionDraft(
                tool: 'dial_number',
                args: {'number': phone},
                risk: RiskLevel.medium,
                summaryKey: ResponseKey.summaryDial,
                summaryArgs: {'number': phone},
              ),
            ],
            language: language,
          );
        }
        return NluClarify(
          questionKey: ResponseKey.clarifyPhoneNumber,
          pending: pending,
          language: language,
        );
      case 'set_alarm':
        final time = _parseAlarmClockTime(normalized);
        if (time != null) {
          final label = args['label'] as String?;
          return _segmentToOutcome(_alarmDraft(time.$1, time.$2, label), language);
        }
        return NluClarify(
          questionKey: ResponseKey.clarifyAlarmTime,
          pending: pending,
          language: language,
        );
      case 'set_timer':
        final seconds = _parseDurationSeconds(normalized);
        if (seconds != null) {
          return _segmentToOutcome(_timerDraft(seconds), language);
        }
        return NluClarify(
          questionKey: ResponseKey.clarifyTimerDuration,
          pending: pending,
          language: language,
        );
      case 'create_routine':
        final knownCommand = args['command'] as String?;
        final knownHour = args['hour'] as int?;
        if (knownCommand == null) {
          // Answering the command question; time may already be known.
          final command = _extractRoutineCommand(normalized) ?? normalized;
          final hour = args['hour'] as int?;
          final minute = args['minute'] as int?;
          if (hour != null) {
            return _segmentToOutcome(_routineDraft(hour, minute ?? 0, command), language);
          }
          return NluClarify(
            questionKey: ResponseKey.clarifyRoutineTime,
            pending: PendingSlot(
              intent: 'create_routine',
              questionKey: ResponseKey.clarifyRoutineTime,
              args: <String, Object?>{'command': command},
              expiresAt: DateTime.now().add(const Duration(minutes: 2)),
            ),
            language: language,
          );
        }
        if (knownHour != null) {
          return _segmentToOutcome(_routineDraft(knownHour, (args['minute'] as int?) ?? 0, knownCommand), language);
        }
        final time = _parseAlarmClockTime(normalized);
        if (time != null) {
          return _segmentToOutcome(_routineDraft(time.$1, time.$2, knownCommand), language);
        }
        return NluClarify(
          questionKey: ResponseKey.clarifyRoutineTime,
          pending: pending,
          language: language,
        );
      default:
        return null;
    }
  }

  String _cleanSlotValue(String raw) =>
      raw.trim().replaceAll(RegExp('^["\']+|["\']+\$'), '');

  /// Converts a segment parse result into a full NLU outcome (slot filling).
  NluOutcome _segmentToOutcome(_SegmentResult result, String language) =>
      switch (result) {
        _Draft(:final draft) => NluPlan(drafts: [draft], language: language),
        _Clarify(:final questionKey, :final pending) => NluClarify(
            questionKey: questionKey,
            pending: pending,
            language: language,
          ),
        _None() => _clarifyUnknown(language),
      };

  // ===== Segment parser =====

  _SegmentResult _parseSegment(String segment, String language, String? appContext) {
    // Messaging and email match first: their verb+object patterns are the
    // most specific and must beat broader matchers (e.g. "rapat" inside an
    // email subject must not trigger the calendar).
    final messageResult = _matchMessage(segment, language);
    if (messageResult != null) return messageResult;

    final emailResult = _matchEmail(segment, language);
    if (emailResult != null) return emailResult;

    // Universal control: device + any-app commands via the accessibility
    // layer. Runs before the settings matcher ("naikkan volume" vs "buka
    // pengaturan suara") and before open-app ("aplikasi terbaru" is not an
    // app name).
    final universal = _matchUniversal(segment);
    if (universal != null) return universal;

    final draft =
        _matchScreenUnderstanding(segment) ??
        _matchNotifications(segment) ??
        _matchDeviceInfo(segment) ??
        _matchSettings(segment) ??
        _matchMaps(segment) ??
        _matchYouTube(segment) ??
        _matchSpotify(segment) ??
        _matchCalendar(segment) ??
        _matchShare(segment);
    if (draft != null) return _Draft(draft);

    final openResult = _matchOpenApp(segment);
    if (openResult != null) return openResult;

    // Generic search last, routed to the app opened earlier in the same
    // compound command when that app has its own search capability.
    final routed = _matchContextSearch(segment, appContext);
    if (routed != null) return routed;

    final web = _matchWebSearch(segment);
    if (web != null) return _Draft(web);

    return const _None();
  }

  /// Routes a bare search/play fragment to the app opened earlier in the same
  /// compound command ("buka youtube dan cari X" → youtube_search).
  _SegmentResult? _matchContextSearch(String segment, String? appContext) {
    if (appContext == null) return null;
    switch (appContext) {
      case 'com.google.android.youtube':
        final query = _afterAny(segment, const ['cari ', 'search ', 'putar ', 'play ', 'temukan ', 'find ']);
        if (query == null) return null;
        return _Draft(ActionDraft(
          tool: 'youtube_search',
          args: <String, Object?>{'query': query},
          summaryKey: ResponseKey.summaryYouTubeSearch,
          summaryArgs: {'query': query},
        ));
      case 'com.spotify.music':
        final query = _afterAny(segment, const ['putar ', 'play ', 'cari ', 'search ']);
        if (query == null) return null;
        return _Draft(ActionDraft(
          tool: 'open_spotify',
          args: <String, Object?>{'query': query},
          summaryKey: ResponseKey.summarySpotifySearch,
          summaryArgs: const {'app': 'Spotify'},
        ));
      case 'com.google.android.apps.maps':
        final query = _afterAny(segment, const ['cari ', 'search ', 'find ', 'temukan ', 'ke ', 'to ']);
        if (query == null) return null;
        return _Draft(ActionDraft(
          tool: 'open_maps',
          args: <String, Object?>{'query': query, 'mode': 'search'},
          summaryKey: ResponseKey.summaryMapsSearch,
          summaryArgs: {'destination': query},
        ));
      default:
        return null;
    }
  }

  bool _hasAny(String text, Iterable<String> needles) =>
      needles.any(text.contains);

  // --- device/screen read-only intents ---

  ActionDraft? _matchScreenUnderstanding(String s) {
    final screenWord = _hasAny(s, const ['layar', 'screen', 'tampilan']);
    final readWord = _hasAny(s, const ['baca', 'apa', 'jelaskan', 'read', 'what', 'describe', 'lihat', 'check', 'isi']);
    if (screenWord && readWord) {
      return ActionDraft(
        tool: 'inspect_screen',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryInspectScreen,
      );
    }
    return null;
  }

  ActionDraft? _matchNotifications(String s) {
    final notifWord = _hasAny(s, const ['notifikasi', 'notification']);
    final readWord = _hasAny(s, const ['baca', 'lihat', 'apa', 'read', 'check', 'what', 'terbaru', 'recent']);
    if (notifWord && readWord) {
      return ActionDraft(
        tool: 'get_notification_context',
        args: const <String, Object?>{'limit': 8},
        summaryKey: ResponseKey.summaryNotifications,
      );
    }
    return null;
  }

  ActionDraft? _matchDeviceInfo(String s) {
    if (_hasAny(s, const ['baterai', 'battery']) ||
        (_hasAny(s, const ['info ', 'informasi', 'information', 'tipe ']) &&
            _hasAny(s, const ['hp', 'device', 'perangkat', 'phone']))) {
      return ActionDraft(
        tool: 'get_device_information',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryDeviceInfo,
      );
    }
    return null;
  }

  ActionDraft? _matchSettings(String s) {
    if (!_hasAny(s, const ['pengaturan', 'setting', 'aturan'])) return null;
    final screen = _settingsScreen(s);
    return ActionDraft(
      tool: 'open_device_settings',
      args: <String, Object?>{'screen': screen},
      summaryKey: ResponseKey.summaryOpenSettings,
      summaryArgs: {'screen': screen},
    );
  }

  String _settingsScreen(String s) {
    if (s.contains('wifi') || s.contains('wi fi')) return 'wifi';
    if (s.contains('kecerahan') || s.contains('brightness')) return 'display';
    if (s.contains('bluetooth')) return 'bluetooth';
    if (s.contains('tampilan') || s.contains('display')) return 'display';
    if (s.contains('suara') || s.contains('sound')) return 'sound';
    if (s.contains('aksesibilitas') || s.contains('accessibility')) return 'accessibility';
    if (s.contains('notifikasi') || s.contains('notification')) return 'notifications';
    if (s.contains('aplikasi') || s.contains('app')) return 'apps';
    if (s.contains('keamanan') || s.contains('security')) return 'security';
    if (s.contains('bahasa') || s.contains('language') || s.contains('locale')) return 'locale';
    if (s.contains('tanggal') || s.contains('date')) return 'date';
    if (s.contains('penyimpanan') || s.contains('storage')) return 'storage';
    if (s.contains('data')) return 'dataUsage';
    return 'main';
  }

  // --- app-specific integrations ---

  ActionDraft? _matchMaps(String s) {
    final mapsWord = _hasAny(s, const [
      'maps', 'peta', 'google maps', 'navigasi', 'navigate', 'directions',
      'rute', 'route', 'petunjuk arah',
    ]);
    if (!mapsWord) return null;
    final directions = _hasAny(s, const ['navigasi', 'navigate', 'directions', 'rute', 'route', 'arah', 'petunjuk arah']);
    final query = _afterAny(s, const ['ke ', 'to ', 'menuju ', 'cari ', 'search ', 'find ', 'temukan ']);
    if (query == null && !directions) {
      return ActionDraft(
        tool: 'open_maps',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryOpenMaps,
      );
    }
    return ActionDraft(
      tool: 'open_maps',
      args: <String, Object?>{
        'query': ?query,
        'mode': directions ? 'directions' : 'search',
      },
      summaryKey: directions ? ResponseKey.summaryDirections : ResponseKey.summaryMapsSearch,
      summaryArgs: {'destination': ?query},
    );
  }

  ActionDraft? _matchYouTube(String s) {
    if (!_hasAny(s, const ['youtube', 'yt '])) return null;
    var query = _afterAny(s, const ['cari ', 'search ', 'putar ', 'play ', 'temukan ', 'find ']);
    if (query != null) {
      // "cari X di youtube" — the platform word is not part of the query.
      query = query
          .replaceAll(RegExp(r'\s+(di|on|in)\s+youtube\s*$'), '')
          .replaceAll(RegExp(r'\s+di\s+yt\s*$'), '')
          .trim();
    }
    if (query == null || query.isEmpty) {
      return ActionDraft(
        tool: 'open_application',
        args: const <String, Object?>{'packageName': 'com.google.android.youtube'},
        summaryKey: ResponseKey.summaryOpenApp,
        summaryArgs: const {'app': 'YouTube'},
      );
    }
    return ActionDraft(
      tool: 'youtube_search',
      args: <String, Object?>{'query': query},
      summaryKey: ResponseKey.summaryYouTubeSearch,
      summaryArgs: {'query': query},
    );
  }

  ActionDraft? _matchSpotify(String s) {
    if (!s.contains('spotify')) return null;
    final query = _afterAny(s, const ['putar ', 'play ', 'cari ', 'search ']);
    return ActionDraft(
      tool: 'open_spotify',
      args: <String, Object?>{'query': ?query},
      summaryKey: query != null ? ResponseKey.summarySpotifySearch : ResponseKey.summaryOpenApp,
      summaryArgs: const {'app': 'Spotify'},
    );
  }

  // --- messaging / email (prepare-only, never auto-send) ---

  _SegmentResult? _matchMessage(String s, String language) {
    final appWord = _hasAny(s, const ['whatsapp', 'wa ', 'telegram', 'sms', 'pesan', 'message', 'chat', 'dm ']);
    if (!appWord || !_hasAny(s, const ['kirim', 'send', 'tulis', 'siapkan', 'buat', 'prepare', 'compose'])) {
      return null;
    }
    final args = <String, Object?>{};
    String app = 'whatsapp';
    if (s.contains('telegram')) app = 'telegram';
    if (s.contains('sms')) app = 'sms';
    args['app'] = app;

    final phoneMatch = _phoneRegex.firstMatch(s);
    if (phoneMatch != null) {
      args['phone'] = phoneMatch.group(0)!.replaceAll(RegExp(r'[\s\-]'), '');
    }
    final content = _afterAny(s, const [
      'isi ', 'yaitu ', 'bertuliskan ', 'saying ', 'yang isinya ', 'katakan ',
      'tell ', 'bilang ', 'tulis ',
    ]);
    if (content != null) {
      args['text'] = _trimAt(content, const [' ke ', ' to ', '. ']);
    }
    return _messageOutcome(args, language);
  }

  _SegmentResult _messageOutcome(Map<String, Object?> args, String language) {
    if (!args.containsKey('text')) {
      return _Clarify(
        ResponseKey.clarifyMessageContent,
        PendingSlot(
          intent: 'compose_message',
          questionKey: ResponseKey.clarifyMessageContent,
          args: args,
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        ),
      );
    }
    final needsConfirmation = args.containsKey('phone');
    return _Draft(ActionDraft(
      tool: 'compose_message',
      args: args,
      risk: needsConfirmation ? RiskLevel.high : RiskLevel.medium,
      summaryKey: ResponseKey.summaryComposeMessage,
      summaryArgs: {
        'app': (args['app'] as String?) ?? 'whatsapp',
        if (args.containsKey('phone')) 'phone': args['phone'] as String,
      },
    ));
  }

  _SegmentResult? _matchEmail(String s, String language) {
    final emailWord = _hasAny(s, const ['email', 'gmail', 'surel', 'surat']);
    if (!emailWord || !_hasAny(s, const ['kirim', 'tulis', 'siapkan', 'buat', 'compose', 'prepare', 'draft', 'send'])) {
      return null;
    }
    final args = <String, Object?>{};
    final to = _emailRegex.firstMatch(s)?.group(0);
    if (to != null) args['to'] = to;
    final subject = _afterAny(s, const ['subjek ', 'subject ', 'perihal ', 'tentang ', 'regarding ']);
    if (subject != null) {
      args['subject'] = _trimAt(subject, const [' isi ', ' body ', ' dan ', ', ']);
    }
    final body = _afterAny(s, const ['isi ', 'body ', 'yaitu ', 'bertuliskan ', 'saying ']);
    if (body != null) args['body'] = body;
    return _emailOutcome(args, language);
  }

  _SegmentResult _emailOutcome(Map<String, Object?> args, String language) {
    if (!args.containsKey('body')) {
      return _Clarify(
        ResponseKey.clarifyEmailBody,
        PendingSlot(
          intent: 'compose_email',
          questionKey: ResponseKey.clarifyEmailBody,
          args: args,
          expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        ),
      );
    }
    return _Draft(ActionDraft(
      tool: 'compose_email',
      args: args,
      risk: RiskLevel.medium,
      summaryKey: ResponseKey.summaryComposeEmail,
      summaryArgs: {'to': ?(args['to'] as String?)},
    ));
  }

  // --- productivity ---

  ActionDraft? _matchCalendar(String s) {
    final calWord = _hasAny(s, const [
      'jadwal', 'jadwalkan', 'kalender', 'calendar', 'acara', 'event',
      'rapat', 'meeting', 'schedule', 'ingatkan', 'reminder',
    ]);
    if (!calWord) return null;
    var title = _afterAny(s, const ['tentang ', 'untuk ', 'judul ', 'about ', 'named ', 'acara ']);
    title ??= _afterAny(s, const [
      'jadwalkan ', 'buat acara ', 'buat jadwal ', 'tambah jadwal ',
      'create event ', 'add event ', 'schedule ', 'new event ',
      'buat rapat ', 'meeting ', 'rapat ', 'jadwal ', 'ingatkan ',
    ]);
    if (title == null || title.isEmpty) title = s;
    final timing = _parseTimeWords(s);
    final args = <String, Object?>{
      'title': _trimAt(title, const [' besok', ' hari ini', ' jam ', ' pukul ', ' tomorrow', ' today', ' at ']).trim(),
      if (timing != null) ...timing,
    };
    return ActionDraft(
      tool: 'create_calendar_event',
      args: args,
      risk: RiskLevel.medium,
      summaryKey: ResponseKey.summaryCalendar,
      summaryArgs: {'title': args['title'] as String},
    );
  }

  /// Parses simple relative date/time phrases. Returns begin/end millis or null.
  Map<String, Object?>? _parseTimeWords(String s) {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (_hasAny(s, const [' besok', ' tomorrow'])) {
      day = day.add(const Duration(days: 1));
    } else if (s.contains(' lusa')) {
      day = day.add(const Duration(days: 2));
    } else if (!_hasAny(s, const [' hari ini', ' today'])) {
      final weekday = _weekdayOffset(s);
      if (weekday != null) day = day.add(Duration(days: weekday));
    }

    var hour = 9;
    var minute = 0;
    final timeMatch = RegExp(r'(?:jam|pukul|at)\s*(\d{1,2})(?:[.:](\d{2}))?').firstMatch(s);
    if (timeMatch != null) {
      hour = int.tryParse(timeMatch.group(1)!) ?? 9;
      minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      // Word-boundary am/pm so the substring inside "jam" never matches.
      final hasAm = RegExp(r'\b(?:am|a\.m)\b').hasMatch(s);
      final hasPm = RegExp(r'\b(?:pm|p\.m)\b').hasMatch(s);
      final evening = _hasAny(s, const [' malam', ' sore', ' night']) || hasPm;
      final morning = _hasAny(s, const [' pagi', ' morning']) || hasAm;
      if (evening && hour < 12) {
        hour += 12;
      } else if (!evening && !morning && hour <= 7) {
        // Bare "jam 3" in Indonesian means afternoon (15:00); mornings are
        // usually said explicitly ("jam 3 pagi").
        hour += 12;
      }
    }
    if (hour > 23 || minute > 59) return null;
    final begin = DateTime(day.year, day.month, day.day, hour, minute);
    final allDay = _hasAny(s, const ['seharian', 'all day']);
    return <String, Object?>{
      'beginMillis': begin.millisecondsSinceEpoch,
      if (!allDay) 'endMillis': begin.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'allDay': allDay,
    };
  }

  int? _weekdayOffset(String s) {
    const days = <String, int>{
      'senin': 1, 'monday': 1,
      'selasa': 2, 'tuesday': 2,
      'rabu': 3, 'wednesday': 3,
      'kamis': 4, 'thursday': 4,
      'jumat': 5, 'friday': 5,
      'sabtu': 6, 'saturday': 6,
      'minggu': 7, 'sunday': 7,
    };
    for (final entry in days.entries) {
      if (s.contains(' ${entry.key}')) {
        final today = DateTime.now().weekday; // 1..7
        var diff = entry.value - today;
        if (diff <= 0) diff += 7;
        return diff;
      }
    }
    return null;
  }

  ActionDraft? _matchShare(String s) {
    if (!_hasAny(s, const ['bagikan', 'share'])) return null;
    final content = _afterAny(s, const ['bagikan ', 'share ']);
    if (content == null || content.isEmpty || content == 'ini' || content == 'this') {
      return null;
    }
    return ActionDraft(
      tool: 'share_text',
      args: <String, Object?>{'text': content},
      risk: RiskLevel.medium,
      summaryKey: ResponseKey.summaryShare,
    );
  }

  ActionDraft? _matchWebSearch(String s) {
    if (!_hasAny(s, const ['cari', 'search', 'find', 'googling', 'temukan'])) return null;
    final query = _afterAny(s, const [
      'cari tentang ', 'cari ', 'search for ', 'search ', 'find ', 'googling ', 'temukan ',
    ]);
    if (query == null || query.isEmpty) return null;
    return ActionDraft(
      tool: 'search_web',
      args: <String, Object?>{'query': query},
      summaryKey: ResponseKey.summaryWebSearch,
      summaryArgs: {'query': query},
    );
  }

  _SegmentResult? _matchOpenApp(String s) {
    final target = _afterAny(s, const [
      'buka ', 'open ', 'jalankan ', 'launch ', 'start ', 'bukain ', 'run ',
    ]);
    if (target == null || target.trim().isEmpty) return null;
    final name = target.trim();
    final lookup = appLookup(name);
    if (lookup != null && lookup.$2 >= 0.6) {
      return _Draft(ActionDraft(
        tool: 'open_application',
        args: <String, Object?>{'packageName': lookup.$1},
        summaryKey: ResponseKey.summaryOpenApp,
        summaryArgs: {'app': name},
      ));
    }
    return _Clarify(
      ResponseKey.clarifyAppNotFound,
      PendingSlot(
        intent: 'open_app',
        questionKey: ResponseKey.clarifyAppNotFound,
        args: <String, Object?>{'hint': name},
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      ),
    );
  }

  // ===== universal control: device + any-app UI commands =====

  _SegmentResult? _matchUniversal(String s) {
    // Screenshot first: the word contains "screen", which would otherwise
    // collide with screen-understanding matching in the chain below.
    if (_hasAny(s, const ['screenshot', 'tangkap layar', 'tangkapan layar']) ||
        _tokens(s).contains('ss')) {
      return _Draft(ActionDraft(
        tool: 'take_screenshot',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryScreenshot,
      ));
    }

    // Tap a visible control of ANY app ("tekan play", "tap tombol simpan").
    final tap = _afterAny(s, const ['tekan ', 'tap ', 'klik ', 'press ', 'click ', 'tap on ']);
    if (tap != null && tap.trim().isNotEmpty) {
      final label = _trimAt(tap, const [' di ', ' on ', ' pada ']).trim();
      if (label.isNotEmpty) {
        return _Draft(ActionDraft(
          tool: 'tap_by_label',
          args: <String, Object?>{'label': label},
          risk: RiskLevel.medium,
          summaryKey: ResponseKey.summaryTapElement,
          summaryArgs: {'label': label},
        ));
      }
    }

    // Type into the focused field of the active app.
    final typed = _afterAny(s, const ['ketik ', 'type ']);
    if (typed != null && typed.trim().isNotEmpty) {
      return _Draft(ActionDraft(
        tool: 'type_text',
        args: <String, Object?>{'value': typed.trim()},
        risk: RiskLevel.medium,
        summaryKey: ResponseKey.summaryTypeText,
      ));
    }

    // System navigation — standalone phrases only so "kembali ke youtube"
    // still opens the app.
    if (_equalsAny(s, const ['kembali', 'balik', 'back', 'go back', 'ke sebelumnya', 'halaman sebelumnya'])) {
      return _Draft(ActionDraft(
        tool: 'go_back',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryGoBack,
      ));
    }
    if (_equalsAny(s, const ['pulang', 'beranda', 'ke beranda', 'home', 'go home', 'layar utama', 'ke layar utama', 'home screen'])) {
      return _Draft(ActionDraft(
        tool: 'go_home',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryGoHome,
      ));
    }
    if (_hasAny(s, const ['aplikasi terbaru', 'aplikasi yang baru', 'recent apps', 'app switcher', 'layar terbaru', 'aplikasi berjalan'])) {
      return _Draft(ActionDraft(
        tool: 'open_recents',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryRecents,
      ));
    }
    if (_hasAny(s, const ['panel notifikasi', 'tarik notifikasi', 'notification shade', 'pull down', 'tarik ke bawah', 'tray notifikasi'])) {
      return _Draft(ActionDraft(
        tool: 'open_notification_shade',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryNotificationShade,
      ));
    }
    if (_hasAny(s, const ['pengaturan cepat', 'quick settings', 'panel cepat'])) {
      return _Draft(ActionDraft(
        tool: 'open_quick_settings',
        args: const <String, Object?>{},
        summaryKey: ResponseKey.summaryQuickSettings,
      ));
    }

    // Volume — never intercept "pengaturan suara" (the settings matcher owns it).
    final isSettingsWord = _hasAny(s, const ['pengaturan', 'setting']);
    if (!isSettingsWord && _hasAny(s, const ['volume', 'suara'])) {
      if (_hasAny(s, const ['naik', 'besar', 'keras', 'tinggi', 'up'])) {
        return _volumeDraft('up', ResponseKey.summaryVolumeUp);
      }
      if (_hasAny(s, const ['turun', 'kecil', 'pelan', 'rendah', 'down'])) {
        return _volumeDraft('down', ResponseKey.summaryVolumeDown);
      }
      if (_hasAny(s, const ['bisukan', 'mute', 'senyap', 'nyalakan suara', 'unmute', 'bunyikan'])) {
        return _volumeDraft('mute', ResponseKey.summaryMute);
      }
    }

    // Flashlight.
    if (_hasAny(s, const ['senter', 'flashlight', 'lampu kilat', 'torch'])) {
      final off = _hasAny(s, const ['matikan', 'dimatikan', 'off', 'padam']);
      return _Draft(ActionDraft(
        tool: 'toggle_flashlight',
        args: <String, Object?>{'on': !off},
        summaryKey: off ? ResponseKey.summaryFlashlightOff : ResponseKey.summaryFlashlightOn,
      ));
    }

    // Brightness — "cerahkan/gelapkan layar" counts too; "pengaturan
    // kecerahan" stays with the settings matcher.
    if ((_hasAny(s, const ['kecerahan', 'brightness']) ||
            (_hasAny(s, const ['layar', 'screen']) &&
                _hasAny(s, const ['cerah', 'gelap', 'redup']))) &&
        !isSettingsWord) {
      final number = RegExp(r'(\d{1,3})\s*%?').firstMatch(s);
      if (number != null) {
        final value = int.tryParse(number.group(1)!) ?? 50;
        return _Draft(ActionDraft(
          tool: 'set_brightness',
          args: <String, Object?>{'level': value.clamp(1, 100)},
          summaryKey: ResponseKey.summaryBrightness,
          summaryArgs: {'level': '${value.clamp(1, 100)}'},
        ));
      }
      if (_hasAny(s, const ['penuh', 'maksimal', 'maksimum', 'full', 'max'])) {
        return _brightnessDraft(100);
      }
      if (_hasAny(s, const ['minimum', 'redup', 'dim', 'low'])) {
        return _brightnessDraft(20);
      }
      if (_hasAny(s, const ['naik', 'cerahkan', 'brighter', 'up'])) {
        return _Draft(ActionDraft(
          tool: 'set_brightness',
          args: const <String, Object?>{'delta': 30},
          summaryKey: ResponseKey.summaryBrightness,
          summaryArgs: const {'level': '+30'},
        ));
      }
      if (_hasAny(s, const ['turun', 'gelapkan', 'darker', 'down', 'kurang'])) {
        return _Draft(ActionDraft(
          tool: 'set_brightness',
          args: const <String, Object?>{'delta': -30},
          summaryKey: ResponseKey.summaryBrightness,
          summaryArgs: const {'level': '-30'},
        ));
      }
    }

    // Scheduled routines — "jadwal" + a recurrence word keeps calendar
    // requests ("jadwalkan rapat") out of this branch.
    if (_hasAny(s, const ['rutin', 'setiap hari', 'tiap hari', 'otomatis']) &&
        _hasAny(s, const ['jadwal', 'jadwalkan', 'pasang', 'buat', 'atur', 'routine', 'schedule'])) {
      final time = _parseAlarmClockTime(s);
      final command = _extractRoutineCommand(s);
      if (time != null && command != null) {
        return _routineDraft(time.$1, time.$2, command);
      }
      if (command != null) {
        return _Clarify(
          ResponseKey.clarifyRoutineTime,
          PendingSlot(
            intent: 'create_routine',
            questionKey: ResponseKey.clarifyRoutineTime,
            args: <String, Object?>{'command': command},
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
          ),
        );
      }
      return _Clarify(
        ResponseKey.clarifyRoutineCommand,
        PendingSlot(
          intent: 'create_routine',
          questionKey: ResponseKey.clarifyRoutineCommand,
          args: <String, Object?>{
            if (time != null) 'hour': time.$1,
            if (time != null) 'minute': time.$2,
          },
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    // Dialer — prepare-only: needs the number, never guesses contacts.
    if (_hasAny(s, const ['telepon', 'panggil', 'hubungi', 'call ', 'dial '])) {
      final phone = _phoneRegex
          .firstMatch(s)
          ?.group(0)
          ?.replaceAll(RegExp(r'[\s\-]'), '');
      if (phone != null && phone.length >= 6) {
        return _Draft(ActionDraft(
          tool: 'dial_number',
          args: <String, Object?>{'number': phone},
          risk: RiskLevel.medium,
          summaryKey: ResponseKey.summaryDial,
          summaryArgs: {'number': phone},
        ));
      }
      return _Clarify(
        ResponseKey.clarifyPhoneNumber,
        PendingSlot(
          intent: 'dial_number',
          questionKey: ResponseKey.clarifyPhoneNumber,
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    // Alarm — ask for the time when missing (slot filling completes it).
    if (_hasAny(s, const ['alarm'])) {
      final time = _parseAlarmClockTime(s);
      if (time != null) {
        return _alarmDraft(time.$1, time.$2, _afterAny(s, const ['untuk ', 'berlabel ', 'labeled ', 'buat ']));
      }
      return _Clarify(
        ResponseKey.clarifyAlarmTime,
        PendingSlot(
          intent: 'set_alarm',
          questionKey: ResponseKey.clarifyAlarmTime,
          args: <String, Object?>{
            'label': ?_afterAny(s, const ['untuk ', 'berlabel ', 'labeled ', 'buat ']),
          },
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    // Timer — same contract as alarm.
    if (_hasAny(s, const ['timer'])) {
      final seconds = _parseDurationSeconds(s);
      if (seconds != null) {
        return _timerDraft(seconds);
      }
      return _Clarify(
        ResponseKey.clarifyTimerDuration,
        PendingSlot(
          intent: 'set_timer',
          questionKey: ResponseKey.clarifyTimerDuration,
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    return null;
  }

  _SegmentResult _volumeDraft(String action, ResponseKey key) => _Draft(ActionDraft(
        tool: 'volume_control',
        args: <String, Object?>{'action': action},
        summaryKey: key,
      ));

  _SegmentResult _brightnessDraft(int level) => _Draft(ActionDraft(
        tool: 'set_brightness',
        args: <String, Object?>{'level': level},
        summaryKey: ResponseKey.summaryBrightness,
        summaryArgs: {'level': '$level'},
      ));

  static final _timePattern = RegExp(r'(?:jam|pukul|at)\s*(\d{1,2})(?:[.:](\d{2}))?');

  /// Pulls the runnable command out of a routine request: removes the time
  /// phrase and the scheduling markers, leaving "buka youtube" etc.
  String? _extractRoutineCommand(String s) {
    var text = s.replaceFirst(_timePattern, ' ');
    const stopWords = [
      'setiap hari', 'tiap hari', 'setiap', 'daily', 'lalu', 'untuk',
      'pasang', 'buat', 'atur', 'jadwalkan', 'jadwal', 'rutin', 'otomatis',
      'routine', 'schedule', 'sebuah', 'buatkan',
    ];
    for (final stop in stopWords) {
      text = text.replaceAll(' $stop ', ' ');
      if (text.startsWith('$stop ')) text = text.substring(stop.length + 1);
      if (text.endsWith(' $stop')) text = text.substring(0, text.length - stop.length - 1);
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    return text;
  }

  _SegmentResult _routineDraft(int hour, int minute, String command) => _Draft(ActionDraft(
        tool: 'create_routine',
        args: <String, Object?>{'hour': hour, 'minute': minute, 'command': command},
        risk: RiskLevel.medium,
        summaryKey: ResponseKey.summaryRoutine,
        summaryArgs: {'time': '${_two(hour)}:${_two(minute)}', 'command': command},
      ));

  _SegmentResult _alarmDraft(int hour, int minute, String? label) => _Draft(ActionDraft(
        tool: 'set_alarm',
        args: <String, Object?>{
          'hour': hour,
          'minute': minute,
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        },
        risk: RiskLevel.medium,
        summaryKey: ResponseKey.summaryAlarm,
        summaryArgs: {'time': '${_two(hour)}:${_two(minute)}'},
      ));

  _SegmentResult _timerDraft(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final shown = mins > 0 ? '$mins menit${secs > 0 ? ' $secs detik' : ''}' : '$secs detik';
    return _Draft(ActionDraft(
      tool: 'set_timer',
      args: <String, Object?>{'seconds': seconds},
      risk: RiskLevel.medium,
      summaryKey: ResponseKey.summaryTimer,
      summaryArgs: {'duration': shown},
    ));
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  List<String> _tokens(String s) => s.split(' ').where((t) => t.isNotEmpty).toList();

  bool _equalsAny(String s, List<String> phrases) => phrases.any((p) => s == p);

  /// Alarm time parsing. Unlike calendar timing, a bare "jam 5" defaults to
  /// the morning: wake-up alarms are the dominant use.
  (int, int)? _parseAlarmClockTime(String s) {
    final match = RegExp(r'(?:jam|pukul|at)\s*(\d{1,2})(?:[.:](\d{2}))?').firstMatch(s);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final hasPm = RegExp(r'\b(?:pm|p\.m)\b').hasMatch(s);
    final evening = _hasAny(s, const [' malam', ' sore', ' night']) || hasPm;
    if (evening && hour < 12) hour += 12;
    if (hour > 23 || minute > 59) return null;
    return (hour, minute);
  }

  int? _parseDurationSeconds(String s) {
    final match = RegExp(r'(\d+)\s*(jam|hour|menit|minute|min\b|detik|second|sec\b)').firstMatch(s);
    if (match == null) return null;
    final n = int.tryParse(match.group(1)!) ?? 0;
    final unit = match.group(2)!;
    if (unit.startsWith('jam') || unit.startsWith('hour')) return n * 3600;
    if (unit.startsWith('menit') || unit.startsWith('minute') || unit.startsWith('min')) return n * 60;
    return n;
  }

  // ===== helpers =====

  String? _afterAny(String text, List<String> markers) {
    for (final marker in markers) {
      final index = text.indexOf(marker);
      if (index >= 0) {
        final rest = text.substring(index + marker.length).trim();
        if (rest.isNotEmpty) return rest;
      }
    }
    return null;
  }

  String _trimAt(String text, List<String> stops) {
    var cut = text;
    for (final stop in stops) {
      final index = cut.indexOf(stop);
      if (index > 0) cut = cut.substring(0, index);
    }
    return cut.trim();
  }
}
