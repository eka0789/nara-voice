/// Stable response keys produced by the NLU/orchestrator and localized by the
/// response localizer. Keys — never raw sentences — cross the logic/UI border.
enum ResponseKey {
  // Clarification questions
  clarifyUnknown,
  clarifyAppNotFound,
  clarifyMessageContent,
  clarifyEmailBody,

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
