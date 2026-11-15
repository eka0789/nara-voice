/// Stable response keys produced by the NLU/orchestrator and localized by the
/// response localizer. Keys — never raw sentences — cross the logic/UI border.
enum ResponseKey {
  // Clarification questions
  clarifyUnknown,
  clarifyAppNotFound,
  clarifyMessageContent,
  clarifyEmailBody,
  clarifyPhoneNumber,
  clarifyAlarmTime,
  clarifyTimerDuration,

  // Direct answers
  answerHelp,
  answerGreeting,

  // Plan step summaries
  summaryOpenApp,
  summaryOpenSettings,
  summaryOpenMaps,
  summaryMapsSearch,
  summaryDirections,
  summaryYouTubeSearch,
  summarySpotifySearch,
  summaryComposeEmail,
  summaryComposeMessage,
  summaryShare,
  summaryCalendar,
  summaryInspectScreen,
  summaryNotifications,
  summaryDeviceInfo,
  summaryWebSearch,

  // Universal control summaries
  summaryTapElement,
  summaryTypeText,
  summaryGoBack,
  summaryGoHome,
  summaryRecents,
  summaryNotificationShade,
  summaryQuickSettings,
  summaryScreenshot,
  summaryVolumeUp,
  summaryVolumeDown,
  summaryMute,
  summaryFlashlightOn,
  summaryFlashlightOff,
  summaryDial,
  summaryAlarm,
  summaryTimer,

  // Execution outcomes
  outcomeCompleted,
  outcomePartial,
  outcomeFailed,
  outcomeCancelled,
  outcomeNothingHeard,

  // Per-step honest results
  stepPreparedUserSends,
  stepHandoffDone,
  stepOpened,
  stepScreenRead,
  stepNotFound,
  stepFailed,

  // Confirmation
  confirmationTitle,
  confirmationMessage,
}
