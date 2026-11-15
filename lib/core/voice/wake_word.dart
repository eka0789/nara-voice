/// Wake-word detection for the in-app standby listener.
///
/// While NARA is open and standby is enabled, STT runs continuously: utterances
/// containing the wake phrase are executed, everything else is ignored. This
/// is the honest in-app alternative to a background wake-word service (which
/// would need a licensed model like Picovoice Porcupine and its AccessKey).
class WakeWord {
  const WakeWord._();

  /// Matches "Hey NARA", "Hai NARA", "OK NARA" or a bare "NARA" at the start
  /// of an utterance. Case-insensitive, punctuation tolerant.
  static final RegExp _pattern = RegExp(
    r'^(?:hey|hai|ok|okay|halo)?\s*nara\b\s*[,.!?:;]?\s*(.*)$',
    caseSensitive: false,
  );

  /// Returns the text after the wake phrase:
  /// - null → no wake word present (caller keeps listening)
  /// - ''   → bare wake word (caller stops standby)
  /// - other → the command to execute
  static String? strip(String utterance) {
    final match = _pattern.firstMatch(utterance.trim());
    if (match == null) return null;
    final rest = match.group(1)?.trim() ?? '';
    return rest;
  }
}
