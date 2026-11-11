import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conversation.dart';
import 'nlu/nlu_engine.dart';

/// Session context store (spec §12): recent conversation, current task
/// context (pending slot), and the active application. Sensitive content is
/// never persisted by default — history lives in memory only and expires.
class ConversationMemory {
  ConversationMemory({this.maxMessages = 60, this.slotTtl = const Duration(minutes: 3)});

  final int maxMessages;
  final Duration slotTtl;

  final List<ConversationMessage> _messages = <ConversationMessage>[];
  PendingSlot? _pending;
  String? _activeApp;
  DateTime _lastActivity = DateTime.now();

  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  PendingSlot? get pending {
    final slot = _pending;
    if (slot != null && slot.isExpired) {
      _pending = null;
      return null;
    }
    return slot;
  }

  String? get activeApp => _activeApp;

  /// Session expires after 10 idle minutes.
  bool get isStale =>
      DateTime.now().difference(_lastActivity) > const Duration(minutes: 10);

  void addUserMessage(String text, {String? language}) {
    _touch();
    _messages.add(ConversationMessage(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      text: text,
      createdAt: DateTime.now(),
      language: language,
    ));
    _trim();
  }

  void addAssistantMessage(String text, {Map<String, Object?> meta = const {}}) {
    _touch();
    _messages.add(ConversationMessage(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.assistant,
      text: text,
      createdAt: DateTime.now(),
      meta: meta,
    ));
    _trim();
  }

  void setPending(PendingSlot? slot) {
    _touch();
    _pending = slot;
  }

  void setActiveApp(String? packageName) {
    _touch();
    _activeApp = packageName;
  }

  /// Explicit memory control (spec §12: context expiration + explicit clears).
  void clear() {
    _messages.clear();
    _pending = null;
    _activeApp = null;
  }

  void _touch() => _lastActivity = DateTime.now();

  void _trim() {
    while (_messages.length > maxMessages) {
      _messages.removeAt(0);
    }
  }
}

final conversationMemoryProvider = Provider<ConversationMemory>((ref) {
  return ConversationMemory();
});
