import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/nara_app.dart';
import '../../../app/theme.dart';
import '../../../core/voice/voice_state.dart';
import '../../../l10n/app_localizations.dart';
import '../voice_assistant_controller.dart';
import 'widgets/confirmation_card.dart';
import 'widgets/execution_progress.dart';
import 'widgets/quick_commands.dart';
import 'widgets/voice_orb.dart';

/// Main voice screen: orb, live transcript, response, confirmation card,
/// execution progress, quick commands and a text fallback.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    HapticFeedback.selectionClick();
    ref.read(voiceAssistantProvider.notifier).handleSubmit(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voiceAssistantProvider);
    final controller = ref.read(voiceAssistantProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName), actions: [
        IconButton(
          tooltip: l10n.settingsTitle,
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => context.push('/settings'),
        ),
      ]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: VoiceOrb(
                      state: state.voiceState,
                      onTap: () {
                        if (state.voiceState == VoiceState.listening) {
                          controller.stopListening();
                        } else {
                          controller.startListening();
                        }
                      },
                      enabled: state.listeningAvailable || state.voiceState != VoiceState.listening,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statusChip(l10n, state),
                  const SizedBox(height: 16),
                  if (state.partialTranscript.isNotEmpty)
                    _bubble(
                      text: state.partialTranscript,
                      isUser: true,
                      isPartial: true,
                    ),
                  if (state.transcript.isNotEmpty && state.partialTranscript.isEmpty)
                    _bubble(text: state.transcript, isUser: true),
                  if (state.responseText.isNotEmpty)
                    _bubble(text: state.responseText, isUser: false),
                  if (state.statusHint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.statusHint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NaraTheme.warning, fontSize: 13),
                    ),
                  ],
                  if (state.pendingPlan != null)
                    ConfirmationCard(
                      body: state.responseText,
                      onConfirm: controller.confirmPendingPlan,
                      onCancel: controller.cancelPendingPlan,
                    ),
                  if (state.activePlan != null &&
                      (state.voiceState.isBusy || state.activePlan!.anyFailed))
                    ExecutionProgress(plan: state.activePlan!),
                  if (state.resultCard != null) _resultCard(state.resultCard!),
                  if (state.voiceState == VoiceState.idle &&
                      state.responseText.isEmpty &&
                      state.transcript.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: NaraTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    QuickCommands(onSelected: _submit),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            _inputBar(l10n, state),
          ],
        ),
      ),
      bottomNavigationBar: const NaraNavigationBar(current: '/'),
    );
  }

  Widget _statusChip(AppLocalizations l10n, AssistantUiState state) {
    final (label, color) = _statusMeta(l10n, state.voiceState);
    return Chip(
      avatar: Icon(_statusIcon(state.voiceState), size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
    );
  }

  (String, Color) _statusMeta(AppLocalizations l10n, VoiceState s) {
    switch (s) {
      case VoiceState.idle:
        return (l10n.stateIdle, NaraTheme.accentPurple);
      case VoiceState.listening:
        return (l10n.listening, NaraTheme.accentBlue);
      case VoiceState.processing || VoiceState.thinking:
        return (l10n.thinking, NaraTheme.accentPurple);
      case VoiceState.executing:
        return (l10n.executing, NaraTheme.accentPurple);
      case VoiceState.speaking:
        return (l10n.speaking, NaraTheme.success);
      case VoiceState.awaitingConfirmation:
        return (l10n.awaitingConfirmation, NaraTheme.warning);
      case VoiceState.error:
        return (l10n.stateError, NaraTheme.danger);
    }
  }

  IconData _statusIcon(VoiceState s) {
    switch (s) {
      case VoiceState.idle:
        return Icons.check_circle_outline_rounded;
      case VoiceState.listening:
        return Icons.mic_rounded;
      case VoiceState.processing || VoiceState.thinking || VoiceState.executing:
        return Icons.autorenew_rounded;
      case VoiceState.speaking:
        return Icons.volume_up_rounded;
      case VoiceState.awaitingConfirmation:
        return Icons.help_outline_rounded;
      case VoiceState.error:
        return Icons.error_outline_rounded;
    }
  }

  Widget _bubble({required String text, required bool isUser, bool isPartial = false}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: isUser ? NaraTheme.accentBlue.withValues(alpha: 0.18) : NaraTheme.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isPartial
              ? Border.all(color: NaraTheme.accentBlue.withValues(alpha: 0.4))
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isPartial ? NaraTheme.textSecondary : Colors.white,
            fontStyle: isPartial ? FontStyle.italic : FontStyle.normal,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _resultCard(ResultCard card) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_rounded, size: 18, color: NaraTheme.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in card.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: const TextStyle(fontSize: 13, height: 1.3)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(AppLocalizations l10n, AssistantUiState state) {
    final listening = state.voiceState == VoiceState.listening;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: l10n.typeInstead,
                prefixIcon: const Icon(Icons.keyboard_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              if (listening) {
                ref.read(voiceAssistantProvider.notifier).stopListening();
              } else {
                ref.read(voiceAssistantProvider.notifier).startListening();
              }
            },
            icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(listening ? l10n.cancel : l10n.tapToSpeak),
          ),
        ],
      ),
    );
  }
}
