// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NARA Voice';

  @override
  String get tagline => 'Speak Naturally. NARA Gets It Done.';

  @override
  String get navHome => 'Voice';

  @override
  String get navApps => 'Apps';

  @override
  String get navAutomations => 'Automations';

  @override
  String get navPermissions => 'Permissions';

  @override
  String get navSettings => 'Settings';

  @override
  String get tapToSpeak => 'Tap to speak';

  @override
  String get listening => 'Listening…';

  @override
  String get thinking => 'Thinking…';

  @override
  String get executing => 'Executing…';

  @override
  String get speaking => 'Speaking…';

  @override
  String get awaitingConfirmation => 'Awaiting your confirmation';

  @override
  String get stateIdle => 'Ready';

  @override
  String get stateError => 'Something went wrong';

  @override
  String get typeInstead => 'Or type a command…';

  @override
  String get quickCommands => 'Quick commands';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get searchApps => 'Search installed apps';

  @override
  String get installedApps => 'Installed apps';

  @override
  String get supportedCaps => 'Capabilities';

  @override
  String get noAppsFound => 'No apps match your search';

  @override
  String get launchable => 'Launchable';

  @override
  String get system => 'System app';

  @override
  String get openApp => 'Open';

  @override
  String get appDetails => 'Details';

  @override
  String get workflowHistory => 'Workflow history';

  @override
  String get noWorkflows =>
      'No multi-step runs yet. Try: \"Open YouTube and search Flutter tutorial\".';

  @override
  String get workflowRunning => 'Running…';

  @override
  String get workflowCompleted => 'Completed';

  @override
  String get workflowPartial => 'Partially completed';

  @override
  String get workflowFailed => 'Failed';

  @override
  String get workflowCancelled => 'Cancelled';

  @override
  String get workflowAwaiting => 'Awaiting approval';

  @override
  String get permissionCenter => 'Permission center';

  @override
  String get permissionExplanation =>
      'NARA only uses what you allow. Revoke anything at any time.';

  @override
  String get permMicrophone => 'Microphone';

  @override
  String get permMicrophoneDesc => 'Speech recognition for voice commands';

  @override
  String get permNotifications => 'Notifications';

  @override
  String get permNotificationsDesc => 'Post NARA\'s own status notifications';

  @override
  String get permAccessibility => 'Screen assistant (Accessibility)';

  @override
  String get permAccessibilityDesc =>
      'Read the visible screen only when you ask. Never reads passwords.';

  @override
  String get permListener => 'Notification reader';

  @override
  String get permListenerDesc => 'List recent notification titles on request';

  @override
  String get granted => 'Granted';

  @override
  String get notGranted => 'Off';

  @override
  String get enable => 'Enable';

  @override
  String get openSystemSettings => 'Open system settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get voiceResponses => 'Voice responses (TTS)';

  @override
  String get speechRate => 'Speech rate';

  @override
  String get speechPitch => 'Speech pitch';

  @override
  String get cloudAi => 'Cloud AI (optional)';

  @override
  String get cloudAiDesc =>
      'Bring your own OpenAI-compatible endpoint. The key is stored in secure storage and never leaves this device except to call your endpoint.';

  @override
  String get cloudEndpoint => 'Endpoint URL';

  @override
  String get cloudModel => 'Model name';

  @override
  String get cloudApiKey => 'API key';

  @override
  String get cloudOff => 'Off';

  @override
  String get cloudMissingKey => 'Enabled — add an API key to activate';

  @override
  String get cloudReady => 'Active';

  @override
  String get cloudSync => 'Firebase cloud sync';

  @override
  String get cloudSyncOff => 'Inactive — add google-services.json to enable';

  @override
  String get cloudSyncOn => 'Active';

  @override
  String get memory => 'Conversation memory';

  @override
  String get memoryDesc =>
      'Keep recent context for follow-up commands. Screen content is never stored.';

  @override
  String get clearMemory => 'Clear conversation memory';

  @override
  String get memoryCleared => 'Memory cleared';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get securityNote =>
      'NARA never reads passwords, never bypasses authentication, and always reports real success or failure.';

  @override
  String get micPermissionNeeded =>
      'Microphone permission is required for voice input';

  @override
  String get sttUnavailable =>
      'Speech recognition is not available on this device';

  @override
  String get activePlan => 'Execution progress';

  @override
  String get planStepDone => 'Done';

  @override
  String get planStepFailed => 'Failed';

  @override
  String get planStepRunning => 'Running';

  @override
  String get planStepPending => 'Pending';

  @override
  String get resultCard => 'Result';
}
