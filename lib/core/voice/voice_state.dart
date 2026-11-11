/// Voice interaction state machine — one visual + spoken state at a time.
enum VoiceState {
  idle,
  listening,
  processing,
  thinking,
  executing,
  speaking,
  awaitingConfirmation,
  error,
}

/// Extension mapping states to localized UI labels happens in the widget layer;
/// this keeps the state machine pure.
extension VoiceStateX on VoiceState {
  bool get isBusy =>
      this == VoiceState.processing ||
      this == VoiceState.thinking ||
      this == VoiceState.executing;

  bool get canStartListening =>
      this == VoiceState.idle || this == VoiceState.error || this == VoiceState.speaking;
}
