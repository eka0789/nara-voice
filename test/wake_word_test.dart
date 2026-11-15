import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/voice/wake_word.dart';

void main() {
  group('wake word detection', () {
    test('hey nara + command', () {
      expect(WakeWord.strip('Hey NARA buka youtube'), 'buka youtube');
    });

    test('hai nara + command (Indonesian greeting)', () {
      expect(WakeWord.strip('Hai NARA, pasang alarm jam 6'), 'pasang alarm jam 6');
    });

    test('ok nara + command', () {
      expect(WakeWord.strip('ok nara naikkan volume'), 'naikkan volume');
    });

    test('bare wake word returns empty (stop standby)', () {
      expect(WakeWord.strip('NARA'), '');
      expect(WakeWord.strip('hey nara'), '');
    });

    test('no wake word returns null', () {
      expect(WakeWord.strip('buka youtube'), isNull);
      expect(WakeWord.strip('narasi hari ini'), isNull);
      expect(WakeWord.strip('kanara test'), isNull);
    });

    test('case and punctuation tolerant', () {
      expect(WakeWord.strip('HEY NARA! kembali'), 'kembali');
    });
  });
}
