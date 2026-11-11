import '../models/execution.dart';
import 'nlu/nlu_engine.dart';
import 'response_keys.dart';

/// Builds natural, honest, localized (id/en) assistant sentences from
/// response keys and execution results. This is the ONLY place that turns
/// structured outcomes into user-facing words.
class ResponseLocalizer {
  const ResponseLocalizer._();

  static String question(ResponseKey key, String locale, {Map<String, String> args = const {}}) {
    final id = locale.startsWith('id');
    switch (key) {
      case ResponseKey.clarifyUnknown:
        return id ? 'Maaf, saya belum paham. Bisa diulang dengan perintah lain?' : "Sorry, I didn't catch that. Could you rephrase?";
      case ResponseKey.clarifyAppNotFound:
        return id
            ? 'Aplikasi "${args['app'] ?? ''}" tidak ditemukan. Maksud Anda aplikasi apa?'
            : 'I could not find the app "${args['app'] ?? ''}". Which app do you mean?';
      case ResponseKey.clarifyMessageContent:
        return id ? 'Isi pesannya apa?' : 'What should the message say?';
      case ResponseKey.clarifyEmailBody:
        return id ? 'Isi emailnya apa?' : 'What should the email say?';
      default:
        return id ? 'Bisa dijelaskan lebih detail?' : 'Could you give me more detail?';
    }
  }

  static String answer(ResponseKey key, String locale, {Map<String, String> args = const {}}) {
    final id = locale.startsWith('id');
    switch (key) {
      case ResponseKey.answerHelp:
        return id
            ? 'Saya bisa membuka aplikasi, mencari di web, YouTube, Spotify, Maps, menyiapkan pesan WhatsApp dan email, membuat draf acara kalender, membuka pengaturan, membaca notifikasi, serta menjelaskan isi layar. Katakan saja perintahnya.'
            : 'I can open apps, search the web, YouTube, Spotify and Maps, prepare WhatsApp messages and emails, draft calendar events, open settings, read notifications, and describe your screen. Just say the command.';
      case ResponseKey.answerGreeting:
        return id ? 'Halo! Saya NARA. Ada yang bisa saya bantu?' : "Hi! I'm NARA. How can I help?";
      default:
        return id ? 'Siap.' : "I'm ready.";
    }
  }

  static String summary(ActionDraft draft, String locale) {
    final id = locale.startsWith('id');
    switch (draft.summaryKey) {
      case ResponseKey.summaryOpenApp:
        return id ? 'Buka ${_a(draft, 'app')}' : 'Open ${_a(draft, 'app')}';
      case ResponseKey.summaryOpenSettings:
        return id ? 'Buka pengaturan ${_a(draft, 'screen')}' : 'Open ${_a(draft, 'screen')} settings';
      case ResponseKey.summaryOpenMaps:
        return id ? 'Buka Maps' : 'Open Maps';
      case ResponseKey.summaryMapsSearch:
        return id ? 'Cari lokasi ${_a(draft, 'destination')}' : "Search location ${_a(draft, 'destination')}";
      case ResponseKey.summaryDirections:
        return id ? 'Navigasi ke ${_a(draft, 'destination')}' : "Navigate to ${_a(draft, 'destination')}";
      case ResponseKey.summaryYouTubeSearch:
        return id ? 'Cari di YouTube: ${_a(draft, 'query')}' : 'Search YouTube for ${_a(draft, 'query')}';
      case ResponseKey.summarySpotifySearch:
        return id ? 'Cari di Spotify: ${_a(draft, 'query')}' : 'Search Spotify for ${_a(draft, 'query')}';
      case ResponseKey.summaryComposeEmail:
        return id ? 'Siapkan email${_to(draft)}' : 'Prepare email${_to(draft)}';
      case ResponseKey.summaryComposeMessage:
        return id ? 'Siapkan pesan ${_a(draft, 'app')}${_phone(draft)}' : 'Prepare ${_a(draft, 'app')} message${_phone(draft)}';
      case ResponseKey.summaryShare:
        return id ? 'Bagikan teks' : 'Share text';
      case ResponseKey.summaryCalendar:
        return id ? 'Draf acara: ${_a(draft, 'title')}' : "Event draft: ${_a(draft, 'title')}";
      case ResponseKey.summaryInspectScreen:
        return id ? 'Baca isi layar' : 'Read the screen';
      case ResponseKey.summaryNotifications:
        return id ? 'Baca notifikasi terbaru' : 'Read recent notifications';
      case ResponseKey.summaryDeviceInfo:
        return id ? 'Info perangkat' : 'Device info';
      case ResponseKey.summaryWebSearch:
        return id ? 'Cari di web: ${_a(draft, 'query')}' : 'Search the web for ${_a(draft, 'query')}';
      default:
        return draft.tool;
    }
  }

  static String _a(ActionDraft draft, String key) => draft.summaryArgs[key] ?? '';
  static String _to(ActionDraft draft) {
    final to = draft.summaryArgs['to'];
    return to == null ? '' : ' ke $to';
  }

  static String _phone(ActionDraft draft) {
    final phone = draft.summaryArgs['phone'];
    return phone == null ? '' : ' ke $phone';
  }

  /// Final spoken response built from an executed plan. Every sentence is
  /// grounded in the actual step results — never an assumed success.
  static String outcome({
    required String outcomeLabel,
    required List<ExecutionStep> steps,
    required String locale,
  }) {
    final id = locale.startsWith('id');
    final done = steps.where((s) => s.status == StepStatus.done).toList();
    final failed = steps.where((s) => s.status == StepStatus.failed).toList();

    if (steps.isEmpty) {
      return id ? 'Tidak ada yang dijalankan.' : 'Nothing was executed.';
    }

    final parts = <String>[];
    for (final step in done) {
      parts.add(_stepSuccess(step, id));
    }
    for (final step in failed) {
      parts.add(_stepFailure(step, id));
    }

    final prefix = switch (outcomeLabel) {
      'completed' => id ? 'Selesai.' : 'Done.',
      'partially_completed' => id ? 'Sebagian berhasil.' : 'Partially done.',
      'failed' => id ? 'Tidak berhasil.' : "It didn't work.",
      _ => '',
    };
    return prefix.isEmpty ? parts.join(' ') : '$prefix ${parts.join(' ')}';
  }

  static String _stepSuccess(ExecutionStep step, bool id) {
    final data = step.result?.data ?? const <String, Object?>{};
    final mode = data['mode'] as String?;
    switch (step.action.toolName) {
      case 'open_application':
        return id ? 'Aplikasi dibuka.' : 'The app is open.';
      case 'open_device_settings':
        return id ? 'Pengaturan terbuka.' : 'Settings opened.';
      case 'open_maps':
      case 'youtube_search':
      case 'open_spotify':
      case 'search_web':
        return id ? 'Sudah dibuka di aplikasinya.' : 'Opened in the app.';
      case 'compose_message':
        if (mode == 'direct_chat') {
          return id
              ? 'Draf pesan siap di WhatsApp — silakan periksa lalu tekan kirim.'
              : 'The WhatsApp draft is ready — review it and press send.';
        }
        return id
            ? 'Aplikasinya terbuka; pilih kontak tujuan lalu kirim.'
            : 'The app is open; pick the contact and send.';
      case 'compose_email':
        return id
            ? 'Draf email siap — silakan periksa lalu kirim.'
            : 'The email draft is ready — review and send.';
      case 'share_text':
        return id
            ? 'Lembar bagikan terbuka — pilih tujuannya.'
            : 'The share sheet is open — pick a destination.';
      case 'create_calendar_event':
        return id
            ? 'Draf acara terbuka — simpan jika sudah sesuai.'
            : 'The event draft is open — save it if it looks right.';
      case 'inspect_screen':
        return (data['summary'] as String?) ??
            (id ? 'Isi layar sudah tampil di aplikasi.' : 'The screen content is shown in the app.');
      case 'get_notification_context':
        return id
            ? 'Notifikasi terbaru sudah tampil.'
            : 'Recent notifications are shown.';
      case 'get_device_information':
        return (data['spoken'] as String?) ??
            (id ? 'Informasi perangkat sudah tampil.' : 'Device information is shown.');
      default:
        return id ? 'Langkah selesai.' : 'Step completed.';
    }
  }

  static String _stepFailure(ExecutionStep step, bool id) {
    final code = step.result?.errorCode;
    if (code == 'NOT_RESOLVED' || code == 'APP_NOT_LAUNCHABLE') {
      return id
          ? 'Ada langkah yang gagal: aplikasinya tidak tersedia di perangkat ini.'
          : 'One step failed: the application is not available on this device.';
    }
    if (code == 'SERVICE_NOT_ENABLED') {
      return id
          ? 'Langkah ini butuh izin yang belum Anda aktifkan.'
          : 'That step needs a permission you have not enabled yet.';
    }
    if (code == 'TIMEOUT') {
      return id ? 'Ada langkah yang melebihi batas waktu.' : 'One step timed out.';
    }
    return id
        ? 'Ada langkah yang gagal: ${_short(step.result?.message)}'
        : 'One step failed: ${_short(step.result?.message)}';
  }

  static String _short(String? message) {
    if (message == null) return 'unknown error';
    final oneLine = message.replaceAll('\n', ' ');
    return oneLine.length > 90 ? '${oneLine.substring(0, 90)}…' : oneLine;
  }

  /// Confirmation card text for HIGH-risk steps.
  static String confirmationBody(ExecutionStep step, String locale) {
    final id = locale.startsWith('id');
    final args = step.action.args;
    final app = (args['app'] as String?) ?? 'WhatsApp';
    final phone = args['phone'] as String?;
    final text = args['text'] as String? ?? '';
    if (id) {
      return 'NARA akan menyiapkan pesan $app${phone != null ? ' ke $phone' : ''}:\n\n"$text"\n\nLanjutkan?';
    }
    return 'NARA will prepare a $app message${phone != null ? ' to $phone' : ''}:\n\n"$text"\n\nContinue?';
  }
}

/// Public re-export used by the orchestrator.
typedef NluPending = PendingSlot;
