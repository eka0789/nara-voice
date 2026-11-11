// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'NARA Voice';

  @override
  String get tagline => 'Bicara Santai. NARA yang Urus.';

  @override
  String get navHome => 'Suara';

  @override
  String get navApps => 'Aplikasi';

  @override
  String get navAutomations => 'Otomatisasi';

  @override
  String get navPermissions => 'Izin';

  @override
  String get navSettings => 'Pengaturan';

  @override
  String get tapToSpeak => 'Ketuk untuk berbicara';

  @override
  String get listening => 'Mendengarkan…';

  @override
  String get thinking => 'Berpikir…';

  @override
  String get executing => 'Menjalankan…';

  @override
  String get speaking => 'Berbicara…';

  @override
  String get awaitingConfirmation => 'Menunggu konfirmasi Anda';

  @override
  String get stateIdle => 'Siap';

  @override
  String get stateError => 'Terjadi kesalahan';

  @override
  String get typeInstead => 'Atau ketik perintah…';

  @override
  String get quickCommands => 'Perintah cepat';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String get cancel => 'Batal';

  @override
  String get retry => 'Ulangi';

  @override
  String get searchApps => 'Cari aplikasi terpasang';

  @override
  String get installedApps => 'Aplikasi terpasang';

  @override
  String get supportedCaps => 'Kapabilitas';

  @override
  String get noAppsFound => 'Tidak ada aplikasi yang cocok';

  @override
  String get launchable => 'Dapat dibuka';

  @override
  String get system => 'Aplikasi sistem';

  @override
  String get openApp => 'Buka';

  @override
  String get appDetails => 'Detail';

  @override
  String get workflowHistory => 'Riwayat otomatisasi';

  @override
  String get noWorkflows =>
      'Belum ada otomatisasi. Coba: \"Buka YouTube dan cari tutorial Flutter\".';

  @override
  String get workflowRunning => 'Berjalan…';

  @override
  String get workflowCompleted => 'Selesai';

  @override
  String get workflowPartial => 'Sebagian selesai';

  @override
  String get workflowFailed => 'Gagal';

  @override
  String get workflowCancelled => 'Dibatalkan';

  @override
  String get workflowAwaiting => 'Menunggu persetujuan';

  @override
  String get permissionCenter => 'Pusat izin';

  @override
  String get permissionExplanation =>
      'NARA hanya memakai yang Anda izinkan. Cabut kapan saja.';

  @override
  String get permMicrophone => 'Mikrofon';

  @override
  String get permMicrophoneDesc => 'Pengenalan suara untuk perintah suara';

  @override
  String get permNotifications => 'Notifikasi';

  @override
  String get permNotificationsDesc => 'Menampilkan notifikasi status NARA';

  @override
  String get permAccessibility => 'Asisten layar (Aksesibilitas)';

  @override
  String get permAccessibilityDesc =>
      'Membaca layar hanya saat Anda minta. Tidak pernah membaca sandi.';

  @override
  String get permListener => 'Pembaca notifikasi';

  @override
  String get permListenerDesc =>
      'Menampilkan judul notifikasi terbaru saat diminta';

  @override
  String get granted => 'Aktif';

  @override
  String get notGranted => 'Nonaktif';

  @override
  String get enable => 'Aktifkan';

  @override
  String get openSystemSettings => 'Buka pengaturan sistem';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get language => 'Bahasa';

  @override
  String get voiceResponses => 'Respons suara (TTS)';

  @override
  String get speechRate => 'Kecepatan bicara';

  @override
  String get speechPitch => 'Nada bicara';

  @override
  String get cloudAi => 'AI Cloud (opsional)';

  @override
  String get cloudAiDesc =>
      'Gunakan endpoint OpenAI-compatible milik Anda. Key disimpan di secure storage dan tidak pernah keluar dari perangkat selain ke endpoint Anda.';

  @override
  String get cloudEndpoint => 'URL endpoint';

  @override
  String get cloudModel => 'Nama model';

  @override
  String get cloudApiKey => 'API key';

  @override
  String get cloudOff => 'Nonaktif';

  @override
  String get cloudMissingKey => 'Aktif — tambahkan API key untuk menjalankan';

  @override
  String get cloudReady => 'Aktif';

  @override
  String get cloudSync => 'Sinkronisasi cloud Firebase';

  @override
  String get cloudSyncOff =>
      'Nonaktif — tambahkan google-services.json untuk mengaktifkan';

  @override
  String get cloudSyncOn => 'Aktif';

  @override
  String get memory => 'Memori percakapan';

  @override
  String get memoryDesc =>
      'Menyimpan konteks terbaru untuk perintah lanjutan. Isi layar tidak pernah disimpan.';

  @override
  String get clearMemory => 'Hapus memori percakapan';

  @override
  String get memoryCleared => 'Memori dihapus';

  @override
  String get about => 'Tentang';

  @override
  String get version => 'Versi';

  @override
  String get securityNote =>
      'NARA tidak pernah membaca sandi, tidak melewati autentikasi, dan selalu melaporkan hasil sebenarnya.';

  @override
  String get micPermissionNeeded =>
      'Izin mikrofon diperlukan untuk input suara';

  @override
  String get sttUnavailable =>
      'Pengenalan suara tidak tersedia di perangkat ini';

  @override
  String get activePlan => 'Progres eksekusi';

  @override
  String get planStepDone => 'Selesai';

  @override
  String get planStepFailed => 'Gagal';

  @override
  String get planStepRunning => 'Berjalan';

  @override
  String get planStepPending => 'Menunggu';

  @override
  String get resultCard => 'Hasil';
}
