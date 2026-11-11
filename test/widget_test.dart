import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/voice/voice_state.dart';
import 'package:nara_voice/features/voice_assistant/presentation/widgets/confirmation_card.dart';
import 'package:nara_voice/features/voice_assistant/presentation/widgets/quick_commands.dart';
import 'package:nara_voice/features/voice_assistant/presentation/widgets/voice_orb.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: child),
    );

void main() {
  group('VoiceOrb', () {
    testWidgets('renders in idle state', (tester) async {
      await tester.pumpWidget(wrap(VoiceOrb(state: VoiceState.idle, onTap: () {})));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(VoiceOrb), findsOneWidget);
    });

    testWidgets('listening state shows mic icon and tap triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrap(VoiceOrb(state: VoiceState.listening, onTap: () => tapped = true)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      await tester.tap(find.byType(VoiceOrb));
      expect(tapped, isTrue);
    });
  });

  group('ConfirmationCard', () {
    testWidgets('confirm and cancel callbacks fire', (tester) async {
      var confirmed = false;
      var cancelled = false;
      await tester.pumpWidget(wrap(ConfirmationCard(
        body: 'NARA akan menyiapkan pesan:\n"halo"\n\nLanjutkan?',
        onConfirm: () => confirmed = true,
        onCancel: () => cancelled = true,
      )));

      expect(find.textContaining('halo'), findsOneWidget);
      await tester.tap(find.text('Lanjutkan'));
      await tester.tap(find.text('Batal'));
      expect(confirmed, isTrue);
      expect(cancelled, isTrue);
    });
  });

  group('QuickCommands', () {
    testWidgets('tapping a chip emits its command', (tester) async {
      String? selected;
      await tester.pumpWidget(wrap(QuickCommands(onSelected: (c) => selected = c)));
      await tester.tap(find.text('Buka WhatsApp'));
      expect(selected, 'Buka WhatsApp');
    });
  });
}
