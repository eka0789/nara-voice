import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NARA Voice'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Speak Naturally. NARA Gets It Done.'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get navHome;

  /// No description provided for @navApps.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get navApps;

  /// No description provided for @navAutomations.
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get navAutomations;

  /// No description provided for @navPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get navPermissions;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @tapToSpeak.
  ///
  /// In en, this message translates to:
  /// **'Tap to speak'**
  String get tapToSpeak;

  /// No description provided for @listening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get listening;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @executing.
  ///
  /// In en, this message translates to:
  /// **'Executing…'**
  String get executing;

  /// No description provided for @speaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking…'**
  String get speaking;

  /// No description provided for @awaitingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting your confirmation'**
  String get awaitingConfirmation;

  /// No description provided for @stateIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get stateIdle;

  /// No description provided for @stateError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get stateError;

  /// No description provided for @typeInstead.
  ///
  /// In en, this message translates to:
  /// **'Or type a command…'**
  String get typeInstead;

  /// No description provided for @quickCommands.
  ///
  /// In en, this message translates to:
  /// **'Quick commands'**
  String get quickCommands;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @searchApps.
  ///
  /// In en, this message translates to:
  /// **'Search installed apps'**
  String get searchApps;

  /// No description provided for @installedApps.
  ///
  /// In en, this message translates to:
  /// **'Installed apps'**
  String get installedApps;

  /// No description provided for @supportedCaps.
  ///
  /// In en, this message translates to:
  /// **'Capabilities'**
  String get supportedCaps;

  /// No description provided for @noAppsFound.
  ///
  /// In en, this message translates to:
  /// **'No apps match your search'**
  String get noAppsFound;

  /// No description provided for @launchable.
  ///
  /// In en, this message translates to:
  /// **'Launchable'**
  String get launchable;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System app'**
  String get system;

  /// No description provided for @openApp.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openApp;

  /// No description provided for @appDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get appDetails;

  /// No description provided for @workflowHistory.
  ///
  /// In en, this message translates to:
  /// **'Workflow history'**
  String get workflowHistory;

  /// No description provided for @noWorkflows.
  ///
  /// In en, this message translates to:
  /// **'No multi-step runs yet. Try: \"Open YouTube and search Flutter tutorial\".'**
  String get noWorkflows;

  /// No description provided for @workflowRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get workflowRunning;

  /// No description provided for @workflowCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get workflowCompleted;

  /// No description provided for @workflowPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially completed'**
  String get workflowPartial;

  /// No description provided for @workflowFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get workflowFailed;

  /// No description provided for @workflowCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get workflowCancelled;

  /// No description provided for @workflowAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting approval'**
  String get workflowAwaiting;

  /// No description provided for @permissionCenter.
  ///
  /// In en, this message translates to:
  /// **'Permission center'**
  String get permissionCenter;

  /// No description provided for @permissionExplanation.
  ///
  /// In en, this message translates to:
  /// **'NARA only uses what you allow. Revoke anything at any time.'**
  String get permissionExplanation;

  /// No description provided for @permMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get permMicrophone;

  /// No description provided for @permMicrophoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition for voice commands'**
  String get permMicrophoneDesc;

  /// No description provided for @permNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotifications;

  /// No description provided for @permNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Post NARA\'s own status notifications'**
  String get permNotificationsDesc;

  /// No description provided for @permAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Screen assistant (Accessibility)'**
  String get permAccessibility;

  /// No description provided for @permAccessibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Read the visible screen only when you ask. Never reads passwords.'**
  String get permAccessibilityDesc;

  /// No description provided for @permListener.
  ///
  /// In en, this message translates to:
  /// **'Notification reader'**
  String get permListener;

  /// No description provided for @permListenerDesc.
  ///
  /// In en, this message translates to:
  /// **'List recent notification titles on request'**
  String get permListenerDesc;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get granted;

  /// No description provided for @notGranted.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get notGranted;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get openSystemSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @voiceResponses.
  ///
  /// In en, this message translates to:
  /// **'Voice responses (TTS)'**
  String get voiceResponses;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @speechPitch.
  ///
  /// In en, this message translates to:
  /// **'Speech pitch'**
  String get speechPitch;

  /// No description provided for @cloudAi.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI (optional)'**
  String get cloudAi;

  /// No description provided for @cloudAiDesc.
  ///
  /// In en, this message translates to:
  /// **'Bring your own OpenAI-compatible endpoint. The key is stored in secure storage and never leaves this device except to call your endpoint.'**
  String get cloudAiDesc;

  /// No description provided for @cloudEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint URL'**
  String get cloudEndpoint;

  /// No description provided for @cloudModel.
  ///
  /// In en, this message translates to:
  /// **'Model name'**
  String get cloudModel;

  /// No description provided for @cloudApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get cloudApiKey;

  /// No description provided for @cloudOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get cloudOff;

  /// No description provided for @cloudMissingKey.
  ///
  /// In en, this message translates to:
  /// **'Enabled — add an API key to activate'**
  String get cloudMissingKey;

  /// No description provided for @cloudReady.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get cloudReady;

  /// No description provided for @cloudSync.
  ///
  /// In en, this message translates to:
  /// **'Firebase cloud sync'**
  String get cloudSync;

  /// No description provided for @cloudSyncOff.
  ///
  /// In en, this message translates to:
  /// **'Inactive — add google-services.json to enable'**
  String get cloudSyncOff;

  /// No description provided for @cloudSyncOn.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get cloudSyncOn;

  /// No description provided for @memory.
  ///
  /// In en, this message translates to:
  /// **'Conversation memory'**
  String get memory;

  /// No description provided for @memoryDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep recent context for follow-up commands. Screen content is never stored.'**
  String get memoryDesc;

  /// No description provided for @clearMemory.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation memory'**
  String get clearMemory;

  /// No description provided for @memoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Memory cleared'**
  String get memoryCleared;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @securityNote.
  ///
  /// In en, this message translates to:
  /// **'NARA never reads passwords, never bypasses authentication, and always reports real success or failure.'**
  String get securityNote;

  /// No description provided for @micPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice input'**
  String get micPermissionNeeded;

  /// No description provided for @sttUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is not available on this device'**
  String get sttUnavailable;

  /// No description provided for @activePlan.
  ///
  /// In en, this message translates to:
  /// **'Execution progress'**
  String get activePlan;

  /// No description provided for @planStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planStepDone;

  /// No description provided for @planStepFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get planStepFailed;

  /// No description provided for @planStepRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get planStepRunning;

  /// No description provided for @planStepPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get planStepPending;

  /// No description provided for @resultCard.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultCard;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
